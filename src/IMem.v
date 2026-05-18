/*******************************************************************************
 * 名称：IMem
 * 描述：指令取值封装模块。该模块内部实例化一个 Mem，只使用 A 口完成取指
 *       与调试读写，CPU 取指地址按字对齐后送入内部 BRAM。
 *
 * 内存模型约定：
 *   1. CPU 的指令地址空间为 0x0000_0000 ~ 0x0000_FFFF。
 *   2. 取指地址必须按字对齐输入，本模块使用 address[15:2] 作为字地址。
 *   3. 指令读取由内部 Mem 完成，读数据在时钟沿后有效。
 *   4. 调试读写使能与地址/数据在本模块内部同步到 clk 域。
 *
 * 端口说明：
 *   clk         - 时钟
 *   rst_n       - 低有效复位，复位时 instruction 清零
 *   address     - 32 位字节地址
 *   instruction - 输出指令字
 *   inst_dbg_en - 调试访问使能
 *   inst_wr_en  - 调试写使能（全字写）
 *   inst_dbg_addr - 调试访问字节地址
 *   inst_wr_data - 调试写数据
 *   inst_rd_data - 调试读数据
 ******************************************************************************/
module IMem(
    input clk,
    input rst_n,
    input [31:0] address,
    output [31:0] instruction,

    // Debug: Instruction memory read/write
    input inst_dbg_en, // 1 = Use debug address (read or write)
    input inst_wr_en, // 1 = Write enable (only valid when inst_dbg_en=1)
    input [31:0] inst_dbg_addr, // byte address
    input [31:0] inst_wr_data, // Data to write
    output [31:0] inst_rd_data // Data read
);

    // Debug signals are synchronized to Clk (25MHz)
    // DebugController runs at 100MHz, direct access to 25MHz BRAM may cause setup violation
    reg      inst_dbg_en_sync;
    reg      inst_wr_en_sync;
    reg [31:0] inst_dbg_addr_sync;
    reg [31:0] inst_wr_data_sync;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_dbg_en_sync  <= 1'b0;
            inst_wr_en_sync   <= 1'b0;
            inst_dbg_addr_sync <= 32'b0;
            inst_wr_data_sync  <= 32'b0;
        end else begin
            inst_dbg_en_sync  <= inst_dbg_en;
            inst_wr_en_sync   <= inst_wr_en;
            inst_dbg_addr_sync <= inst_dbg_addr;
            inst_wr_data_sync  <= inst_wr_data;
        end
    end

    // debug: use debug address (read or write) or normal PC address

    wire [13:0] rom_addr = inst_dbg_en_sync ? inst_dbg_addr_sync[15:2] : address[15:2];
    wire        rom_wea = inst_dbg_en_sync & inst_wr_en_sync;

    wire [31:0] inst_dout;
    assign inst_rd_data = inst_dout; // debug: read data from uram output
    assign inst = inst_dout; // normal instruction also from uram output
    Mem #(
        .ADDR_WIDTH(14)
    ) mem_inst (
        .clk   (clk),
        .wea   (rom_wea),
        .addra (rom_addr),
        .wdataa(inst_wr_data_sync),
        .rdataa(inst_dout),
        .web   (4'b0000),
        .addrb (14'b0),
        .wdatab(32'b0),
        .rdatab()
    );

    assign instruction = rst_n ? inst_dout : 32'b0;

endmodule