/*******************************************************************************
 * 名称：DMem
 * 描述：数据存取与内存映射 I/O 封装模块。该模块内部实例化一个 Mem，只使用 A 口
 *       处理 BRAM 数据区访问，并对 MMIO 地址空间进行译码处理。
 *
 * 内存模型约定：
 *   1. BRAM 数据区：0x0000_0000 ~ 0x0000_FFFF，交由内部 Mem 处理。
 *   2. MMIO 地址空间：0x0010_0000 起，不占用 BRAM，由本模块直接实现。
 *   3. MMIO 寄存器映射如下：
 *      - 0x0010_0000 SW_DATA    [7:0]  ：8 位拨码开关输入，只读
 *      - 0x0010_0004 LED_DATA   [7:0]  ：8 个 LED 输出，1 亮 0 灭
 *      - 0x0010_0008 SEG_DATA   [31:0] ：32 位数码管寄存器
 *      - 0x0010_000C TIME_LOW   [31:0] ：64 位计时器低 32 位
 *      - 0x0010_0010 TIME_HIGH  [31:0] ：64 位计时器高 32 位
 *      - 0x0010_0014 KBD_DATA   [7:0]  ：键盘扫描码/ASCII，只读
 *      - 0x0010_0018 RAND_NUM   [31:0] ：随机数，只读
 *
 * 读写时序：
 *   1. BRAM 读：由内部 Mem 完成，读数据在时钟沿后有效。
 *   2. MMIO 读：组合逻辑直接输出。
 *   3. BRAM 写：写控制信号在组合逻辑中计算，在内部 Mem 的时钟沿执行实际写操作。
 *   4. MMIO 写：同步。led_data 与 32 位 seg_data 在时钟上升沿更新；seg 的具体显示绑定由外部显示模块负责。
 *   5. 调试读写使能、地址和写数据在本模块内部同步到 clk 域。
 *
 *   本模块仅对 0x0010_0000 地址段做 MMIO 译码，其余非数据区、非 MMIO 地址读出为 0。
 *
 * 端口说明：
 *   clk         - 时钟
 *   rst_n       - 低有效复位
 *   mem_write   - 数据区写使能
 *   type        - 访存类型编码：
 *                 3'b000 = lb   （字节读，符号扩展）
 *                 3'b001 = lh   （半字读，符号扩展）
 *                 3'b010 = lw   （字读）
 *                 3'b011 = sb   （字节写）
 *                 3'b100 = sh   （半字写）
 *                 3'b101 = sw   （字写）
 *                 3'b110 = lbu  （字节读，零扩展）
 *                 3'b111 = lhu  （半字读，零扩展）
 *   address     - 32 位字节地址
 *   write_data  - 写入数据
 *   read_data   - 本模块对外输出的最终读数据
 *   dbg_en      - 调试访问使能
 *   dbg_we      - 调试写使能（全字写）
 *   dbg_addr    - 调试访问字节地址
 *   dbg_wdata   - 调试写数据
 *   sw_data     - 拨码开关输入
 *   time_value  - 64 位计时器值
 *   kbd_data    - 键盘输入
 *   rand_num    - 随机数输入
 *   led_data    - LED 输出寄存器
 *   seg_data    - 合并的 32 位数码管控制寄存器（字节映射用于左右段/位选）
 ******************************************************************************/
module DMem(
    input clk,
    input rst_n,
    input mem_write,
    input [2:0] type,
    input [31:0] address,
    input [31:0] write_data,
    output wire [31:0] read_data,

    input [7:0] sw_data,
    input [63:0] time_value,
    input [7:0] kbd_data,
    input [31:0] rand_num,
    output reg [7:0] led_data,
    output reg [31:0] seg_data,

    // --- Debug: Data memory access (uart) ---
    input  wire        dmem_dbg_en,     // 1 = debug for data memory
    input  wire        dmem_wr_en,      // 1 = debug write enable
    input  wire [31:0] dmem_dbg_addr,  // debug byte address
    input  wire [31:0] dmem_wr_data,   // debug write data
    output wire [31:0] dmem_rd_data    // debug read data
);
    localparam [31:0] SW_DATA_ADDR   = 32'h0010_0000;
    localparam [31:0] LED_DATA_ADDR  = 32'h0010_0004;
    localparam [31:0] SEG_DATA       = 32'h0010_0008;
    localparam [31:0] TIME_LOW_ADDR   = 32'h0010_000C;
    localparam [31:0] TIME_HIGH_ADDR  = 32'h0010_0010;
    localparam [31:0] KBD_DATA_ADDR   = 32'h0010_0014;
    localparam [31:0] RAND_NUM_ADDR   = 32'h0010_0018;

    localparam [2:0] TYPE_LB  = 3'b000;
    localparam [2:0] TYPE_LH  = 3'b001;
    localparam [2:0] TYPE_LW  = 3'b010;
    localparam [2:0] TYPE_SB  = 3'b011;
    localparam [2:0] TYPE_SH  = 3'b100;
    localparam [2:0] TYPE_SW  = 3'b101;
    localparam [2:0] TYPE_LBU = 3'b110;
    localparam [2:0] TYPE_LHU = 3'b111;

    // Debug signals synchronized to clk (25MHz) domain
    // DebugController runs at 100MHz, direct access to 25MHz BRAM may cause setup violation
    reg        dmem_dbg_en_sync;
    reg        dmem_wr_en_sync;
    reg [31:0] dmem_dbg_addr_sync;
    reg [31:0] dmem_wr_data_sync;

    always @(negedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dmem_dbg_en_sync  <= 1'b0;
            dmem_wr_en_sync   <= 1'b0;
            dmem_dbg_addr_sync <= 32'b0;
            dmem_wr_data_sync  <= 32'b0;
        end else begin
            dmem_dbg_en_sync  <= dmem_dbg_en;
            dmem_wr_en_sync   <= dmem_wr_en;
            dmem_dbg_addr_sync <= dmem_dbg_addr;
            dmem_wr_data_sync  <= dmem_wr_data;
        end
    end

    wire [31:0] access_address    = dmem_dbg_en_sync ? dmem_dbg_addr_sync : address;
    wire [31:0] access_write_data = dmem_dbg_en_sync ? dmem_wr_data_sync : write_data;
    wire        access_write      = dmem_dbg_en_sync ? dmem_wr_en_sync : mem_write;
    wire [2:0]  access_type       = dmem_dbg_en_sync ? TYPE_SW : type;

    wire bram_access = (access_address[31:16] == 16'h0000);
    wire mmio_access  = (access_address[31:16] == 16'h0010);
    wire seg_access   = mmio_access && (access_address[31:2] == SEG_DATA[31:2]);
    wire [13:0] bram_addr = access_address[15:2];

    reg [3:0]  bram_we_r;
    reg [31:0] bram_wdata_r;
    wire [31:0] bram_rdata;
    wire [31:0] mmio_rdata;
    // BRAM 写
    always @(*) begin
        bram_we_r = 4'b0000;
        bram_wdata_r = access_write_data;

        if (bram_access && access_write) begin
            case (access_type)
                TYPE_SB: begin
                    case (access_address[1:0])
                        2'b00: begin
                            bram_we_r = 4'b0001;
                            bram_wdata_r = {24'b0, access_write_data[7:0]};
                        end
                        2'b01: begin
                            bram_we_r = 4'b0010;
                            bram_wdata_r = {16'b0, access_write_data[7:0], 8'b0};
                        end
                        2'b10: begin
                            bram_we_r = 4'b0100;
                            bram_wdata_r = {8'b0, access_write_data[7:0], 16'b0};
                        end
                        2'b11: begin
                            bram_we_r = 4'b1000;
                            bram_wdata_r = {access_write_data[7:0], 24'b0};
                        end
                    endcase
                end
                TYPE_SH: begin
                    case (access_address[1])
                        1'b0: begin // 低半字对齐 (尾数 2'b00)
                            bram_we_r = 4'b0011;
                            bram_wdata_r = {16'b0, access_write_data[15:0]};
                        end
                        1'b1: begin // 高半字对齐 (尾数 2'b10)
                            bram_we_r = 4'b1100;
                            bram_wdata_r = {access_write_data[15:0], 16'b0};
                        end
                    endcase
                end
                TYPE_SW: begin
                    if (access_address[1:0] == 2'b00) begin
                        bram_we_r = 4'b1111;
                        bram_wdata_r = access_write_data;
                    end
                end
                default: begin
                end
            endcase
        end
    end

    Mem #(
        .ADDR_WIDTH(14)
    ) mem_inst (
        .clk   (clk),
        .wea   (bram_we_r),
        .addra (bram_addr),
        .wdataa(bram_wdata_r),
        .rdataa(bram_rdata),
        .web   (4'b0000),
        .addrb (14'b0),
        .wdatab(32'b0),
        .rdatab()
    );

    // MMIO 写和 LED/SEG 输出更新
    always @(negedge clk) begin
        if (!rst_n) begin
            led_data <= 8'b0;
            seg_data <= 32'b0;
        end else begin
            if (mmio_access) begin
                case (access_address)
                    SW_DATA_ADDR: begin
                    end
                    LED_DATA_ADDR: begin
                        if (access_write) led_data <= access_write_data[7:0];
                    end
                    default: begin
                    end
                endcase

                if (seg_access && access_write) begin
                    case (access_type)
                        TYPE_SB: begin
                            case (access_address[1:0])
                                2'b00: seg_data[7:0]    <= access_write_data[7:0];
                                2'b01: seg_data[15:8]   <= access_write_data[7:0];
                                2'b10: seg_data[23:16]  <= access_write_data[7:0];
                                2'b11: seg_data[31:24]  <= access_write_data[7:0];
                            endcase
                        end
                        TYPE_SH: begin
                            if (access_address[1] == 1'b0) begin
                                if (access_address[1:0] == 2'b00) seg_data[15:0] <= access_write_data[15:0];
                                else seg_data[31:16] <= access_write_data[15:0];
                            end
                        end
                        TYPE_SW: begin
                            if (access_address[1:0] == 2'b00) seg_data <= access_write_data;
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end

    // 生成 MMIO 读数据
    assign mmio_rdata = (mmio_access) ? (
        (access_address == SW_DATA_ADDR)   ? {24'b0, sw_data} :
        (access_address == LED_DATA_ADDR)   ? ((access_write) ? {24'b0, access_write_data[7:0]} : {24'b0, led_data}) :
        seg_access ? (
            access_write ? (
                (access_type == TYPE_SB) ? (
                    (access_address[1:0] == 2'b00) ? {seg_data[31:8],  access_write_data[7:0]} :
                    (access_address[1:0] == 2'b01) ? {seg_data[31:16], access_write_data[7:0], seg_data[7:0]} :
                    (access_address[1:0] == 2'b10) ? {seg_data[31:24], access_write_data[7:0], seg_data[15:0]} :
                                                    {access_write_data[7:0], seg_data[23:0]}
                ) : (access_type == TYPE_SH) ? (
                    (access_address[1] == 1'b0) ? (
                        (access_address[1:0] == 2'b00) ? {seg_data[31:16], access_write_data[15:0]} :
                                                          {access_write_data[15:0], seg_data[15:0]}
                    ) : seg_data
                ) : (access_type == TYPE_SW) ? (
                    (access_address[1:0] == 2'b00) ? access_write_data : seg_data
                ) : seg_data
            ) : seg_data
        ) :
        (access_address == TIME_LOW_ADDR)   ? time_value[31:0] :
        (access_address == TIME_HIGH_ADDR)  ? time_value[63:32] :
        (access_address == KBD_DATA_ADDR)   ? {24'b0, kbd_data} :
        (access_address == RAND_NUM_ADDR)   ? rand_num :
        32'b0
    ) : 32'b0;


    function [31:0] extract_value;
        input [31:0] data_in;
        input [2:0]  type_in;
        input [1:0]  byte_offset;
        begin
            case (type_in)
                TYPE_LB: begin
                    case (byte_offset)
                        2'b00: extract_value = {{24{data_in[7]}},  data_in[7:0]};
                        2'b01: extract_value = {{24{data_in[15]}}, data_in[15:8]};
                        2'b10: extract_value = {{24{data_in[23]}}, data_in[23:16]};
                        2'b11: extract_value = {{24{data_in[31]}}, data_in[31:24]};
                    endcase
                end
                TYPE_LH: begin
                    if (byte_offset[0] == 1'b0) begin
                        if (byte_offset[1] == 1'b0) begin
                            extract_value = {{16{data_in[15]}}, data_in[15:0]};
                        end else begin
                            extract_value = {{16{data_in[31]}}, data_in[31:16]};
                        end
                    end else begin
                        extract_value = 32'b0;
                    end
                end
                TYPE_LW,
                TYPE_SW: begin
                    extract_value = data_in;
                end
                TYPE_LBU: begin
                    case (byte_offset)
                        2'b00: extract_value = {24'b0, data_in[7:0]};
                        2'b01: extract_value = {24'b0, data_in[15:8]};
                        2'b10: extract_value = {24'b0, data_in[23:16]};
                        2'b11: extract_value = {24'b0, data_in[31:24]};
                    endcase
                end
                TYPE_LHU: begin
                    if (byte_offset[0] == 1'b0) begin
                        if (byte_offset[1] == 1'b0) begin
                            extract_value = {16'b0, data_in[15:0]};
                        end else begin
                            extract_value = {16'b0, data_in[31:16]};
                        end
                    end else begin
                        extract_value = 32'b0;
                    end
                end
                default: begin
                    extract_value = data_in;
                end
            endcase
        end
    endfunction
    assign read_data = (mmio_access) ? extract_value(mmio_rdata, access_type, access_address[1:0]) :
                       (bram_access) ? extract_value(bram_rdata, access_type, access_address[1:0]) :
                       32'b0;

    assign dmem_rd_data = read_data;

endmodule