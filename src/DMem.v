/*******************************************************************************
 * 名称：DMem
 * 描述：数据存取与内存映射 I/O 封装模块。该模块本身不直接存储 BRAM，
 *       只负责把数据区访问送入 Mem，并对 MMIO 地址空间进行译码与寄存器化处理。
 *
 * 内存模型约定：
 *   1. BRAM 数据区：0x0001_0000 ~ 0x0001_FFFF，交由 Mem 的 B 口处理。
 *   2. MMIO 地址空间：0x0010_0000 起，不占用 BRAM，由本模块直接实现。
 *   3. MMIO 寄存器映射如下：
 *      - 0x0010_0000 LED_DATA   [7:0]  ：8 个 LED 输出，1 亮 0 灭
 *      - 0x0010_0004 SW_DATA    [7:0]  ：8 位拨码开关输入，只读
 *      - 0x0010_0008 SEG_DATA   [7:0]  ：数码管段选输出
 *      - 0x0010_000C SEG_AN     [7:0]  ：数码管位选输出
 *      - 0x0010_0010 TIME_LOW   [31:0] ：64 位计时器低 32 位
 *      - 0x0010_0014 TIME_HIGH  [31:0] ：64 位计时器高 32 位
 *      - 0x0010_0018 KBD_DATA   [7:0]  ：键盘扫描码/ASCII，只读
 *      - 0x0010_001C RAND_NUM   [31:0] ：随机数，只读
 *
 * 读写时序：
 *   1. BRAM 读：读优先。时序逻辑，mem_rdata 延迟 1 个时钟周期返回；
 *              同一周期同址读写时返回写入前旧值，read_data 与 mem_rdata 同周期输出。
 *   2. MMIO 读：时序逻辑。mmio_rdata 在组合逻辑中生成，在下一个 clk 上升沿锁存；
 *              实现与 BRAM 相同的 1 周期延迟。同一周期同址读写时读路径通过旁路返回 write_data。
 *   3. BRAM 写：时序逻辑。写控制信号（mem_we、mem_wdata）在组合逻辑中计算，
 *              在下一个 clk 上升沿由 Mem 执行实际写操作，延迟 1 个周期。
 *   4. MMIO 写：写优先。led_data / seg_data / seg_an 在时钟上升沿更新；
 *              同一周期同址读写时，读路径通过旁路直接返回本拍 write_data。
 *
 *   本模块仅对 0x0010_0000 地址段做 MMIO 译码，其余非数据区、非 MMIO 地址读出为 0。
 *
 * 端口说明：
 *   [时钟与复位]
 *   clk         - 时钟
 *   rst_n       - 低有效复位
 *
 *   [CPU 访存主接口]
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
 *
 *   [Mem(BRAM) 接口]
 *   mem_rdata   - 来自 Mem 的 BRAM 读数据
 *   mem_addr    - 送往 Mem 的字地址
 *   mem_we      - 送往 Mem 的字节写使能
 *   mem_wdata   - 送往 Mem 的写数据
 *
 *   [MMIO 外设]
 *   sw_data     - 拨码开关输入
 *   time_value  - 64 位计时器值
 *   kbd_data    - 键盘输入
 *   rand_num    - 随机数输入
 *   led_data    - LED 输出寄存器
 *   seg_data    - 数码管段选寄存器
 *   seg_an      - 数码管位选寄存器
 ******************************************************************************/
module DMem(
    input clk,
    input rst_n,
    input mem_write,
    input [2:0] type,
    input [31:0] address,
    input [31:0] write_data,
    output reg [31:0] read_data,
    
    input [31:0] mem_rdata,
    output [14:0] mem_addr,
    output [3:0] mem_we,
    output [31:0] mem_wdata,

    input [7:0] sw_data,
    input [63:0] time_value,
    input [7:0] kbd_data,
    input [31:0] rand_num,
    output reg [7:0] led_data,
    output reg [7:0] seg_data,
    output reg [7:0] seg_an
);
    localparam [31:0] LED_DATA_ADDR  = 32'h0010_0000;
    localparam [31:0] SW_DATA_ADDR   = 32'h0010_0004;
    localparam [31:0] SEG_DATA_ADDR  = 32'h0010_0008;
    localparam [31:0] SEG_AN_ADDR    = 32'h0010_000C;
    localparam [31:0] TIME_LOW_ADDR  = 32'h0010_0010;
    localparam [31:0] TIME_HIGH_ADDR = 32'h0010_0014;
    localparam [31:0] KBD_DATA_ADDR  = 32'h0010_0018;
    localparam [31:0] RAND_NUM_ADDR  = 32'h0010_001C;

    localparam [2:0] TYPE_LB  = 3'b000;
    localparam [2:0] TYPE_LH  = 3'b001;
    localparam [2:0] TYPE_LW  = 3'b010;
    localparam [2:0] TYPE_SB  = 3'b011;
    localparam [2:0] TYPE_SH  = 3'b100;
    localparam [2:0] TYPE_SW  = 3'b101;
    localparam [2:0] TYPE_LBU = 3'b110;
    localparam [2:0] TYPE_LHU = 3'b111;

    wire bram_access;
    wire mmio_access;
    reg [3:0] bram_we_r;
    reg [31:0] bram_wdata_r;
    reg [31:0] mmio_rdata;
    reg [31:0] mmio_rdata_r;
    reg [1:0] address_r;
    reg [2:0] type_r;
    reg mmio_access_r;
    reg bram_access_r;
    reg mem_write_r;
    reg [31:0] write_data_r;
    assign bram_access = (address[31:16] == 16'h0001);
    assign mmio_access = (address[31:16] == 16'h0010);
    
    assign mem_addr = address[16:2];
    assign mem_we = bram_we_r;
    assign mem_wdata = bram_wdata_r;

    // BRAM 写
    always @(*) begin
        bram_we_r = 4'b0000;
        bram_wdata_r = write_data;

        if (bram_access && mem_write) begin
            case (type)
                TYPE_SB: begin
                    case (address[1:0])
                        2'b00: begin
                            bram_we_r = 4'b0001;
                            bram_wdata_r = {24'b0, write_data[7:0]};
                        end
                        2'b01: begin
                            bram_we_r = 4'b0010;
                            bram_wdata_r = {16'b0, write_data[7:0], 8'b0};
                        end
                        2'b10: begin
                            bram_we_r = 4'b0100;
                            bram_wdata_r = {8'b0, write_data[7:0], 16'b0};
                        end
                        2'b11: begin
                            bram_we_r = 4'b1000;
                            bram_wdata_r = {write_data[7:0], 24'b0};
                        end
                    endcase
                end
                TYPE_SH: begin
                    if (address[1] == 1'b0) begin
                        if (address[1:0] == 2'b00) begin
                            bram_we_r = 4'b0011;
                            bram_wdata_r = {16'b0, write_data[15:0]};
                        end else begin
                            bram_we_r = 4'b1100;
                            bram_wdata_r = {write_data[15:0], 16'b0};
                        end
                    end
                end
                TYPE_SW: begin
                    if (address[1:0] == 2'b00) begin
                        bram_we_r = 4'b1111;
                        bram_wdata_r = write_data;
                    end
                end
                default: begin
                end
            endcase
        end
    end

    // 生成 MMIO 读数据
    always @(*) begin
        mmio_rdata = 32'b0;

        if (mmio_access) begin
            case (address)
                LED_DATA_ADDR:  mmio_rdata = (mem_write) ? {24'b0, write_data[7:0]} : {24'b0, led_data};
                SW_DATA_ADDR:   mmio_rdata = {24'b0, sw_data};
                SEG_DATA_ADDR:  mmio_rdata = (mem_write) ? {24'b0, write_data[7:0]} : {24'b0, seg_data};
                SEG_AN_ADDR:    mmio_rdata = (mem_write) ? {24'b0, write_data[7:0]} : {24'b0, seg_an};
                TIME_LOW_ADDR:  mmio_rdata = time_value[31:0];
                TIME_HIGH_ADDR: mmio_rdata = time_value[63:32];
                KBD_DATA_ADDR:  mmio_rdata = {24'b0, kbd_data};
                RAND_NUM_ADDR:  mmio_rdata = rand_num;
                default:        mmio_rdata = 32'b0;
            endcase
        end
    end

    // BRAM 读和 MMIO 读
    function [31:0] extract_value;
        input [31:0] value;
        input [2:0] access_type;
        input [1:0] offset;
        reg [7:0] byte_value;
        reg [15:0] half_value;
        begin
            byte_value = 8'b0;
            half_value = 16'b0;
            case (access_type)
                TYPE_LB, TYPE_LBU: begin
                    case (offset)
                        2'b00: byte_value = value[7:0];
                        2'b01: byte_value = value[15:8];
                        2'b10: byte_value = value[23:16];
                        2'b11: byte_value = value[31:24];
                    endcase
                    extract_value = (access_type == TYPE_LB) 
                        ? {{24{byte_value[7]}}, byte_value}
                        : {24'b0, byte_value};
                end
                TYPE_LH, TYPE_LHU: begin
                    if (offset[0] == 1'b0) begin
                        if (offset[1] == 1'b0) begin
                            half_value = value[15:0];
                        end else begin
                            half_value = value[31:16];
                        end
                        if (access_type == TYPE_LH) begin
                            extract_value = {{16{half_value[15]}}, half_value};
                        end else begin
                            extract_value = {16'b0, half_value};
                        end
                    end else begin
                        extract_value = 32'b0;
                    end
                end
                TYPE_LW: begin
                    if (offset == 2'b00) begin
                        extract_value = value;
                    end else begin
                        extract_value = 32'b0;
                    end
                end
                default: begin
                    extract_value = value;
                end
            endcase
        end
    endfunction
    always @(*) begin
        read_data = 32'b0;
        if (mmio_access_r && mem_write_r) begin
            read_data = extract_value(write_data_r, type_r, address_r);
        end else if (mmio_access_r) begin
            read_data = extract_value(mmio_rdata_r, type_r, address_r);
        end else if (bram_access_r) begin
            read_data = extract_value(mem_rdata, type_r, address_r);
        end
    end

    // 读数据路径锁存与 MMIO 写
    always @(posedge clk) begin
        if (!rst_n) begin
            led_data <= 8'b0;
            seg_data <= 8'b0;
            seg_an <= 8'b0;
            mmio_rdata_r <= 32'b0;
            address_r <= 2'b0;
            type_r <= 3'b0;
            mmio_access_r <= 1'b0;
            bram_access_r <= 1'b0;
            mem_write_r <= 1'b0;
            write_data_r <= 32'b0;
        end else begin
            // 锁存读数据路径控制信息
            mmio_rdata_r <= mmio_rdata;
            address_r <= address[1:0];
            type_r <= type;
            mmio_access_r <= mmio_access;
            bram_access_r <= bram_access;
            mem_write_r <= mem_write;
            write_data_r <= write_data;
            
            // MMIO 写
            if (mmio_access) begin
                case (address)
                    LED_DATA_ADDR: begin
                        if (mem_write) led_data <= write_data[7:0];
                    end
                    SEG_DATA_ADDR: begin
                        if (mem_write) seg_data <= write_data[7:0];
                    end
                    SEG_AN_ADDR: begin
                        if (mem_write) seg_an <= write_data[7:0];
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule