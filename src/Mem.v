/*******************************************************************************
 * 名称：Mem
 * 描述：支持字节级写使能的同步读优先 BRAM 封装。
 *
 * 使用方法：
 *   1. 本模块接收【字对齐地址】。使用时将字节地址截断最低两位后接入，
 *      例如传入 address[16:2]。
 *   2. 字节写使能：we[3:0] 对应 wdata[31:0] 的四个字节。
 *      例如 sb：若写第 2 字节，we=4'b0100，wdata 需预先左移 16 位。
 *      例如 sw：we=4'b1111，wdata 无需移位。
 *   3. 可通过 INIT_FILE 传入初始化文件，文件内存储 16 进制字数据。
 *
 * 注意事项：
 *   1. 在 Vivado 仿真中，若 INIT_FILE 非绝对路径，初始化文件应置于
 *      工程目录\工程名.sim\sim_1\behav\xsim。
 *
 * 参数：
 *   ADDR_WIDTH  - 字地址位宽 (默认 14，对应 16K 字 = 64KB)
 *   INIT_FILE   - 可选初始化文件路径
 ******************************************************************************/
module Mem #(
    parameter ADDR_WIDTH = 14,
    parameter INIT_FILE  = ""
)(
    input  wire                  clk,
    
    input  wire [3:0]            wea,
    input  wire [ADDR_WIDTH-1:0] addra,  
    input  wire [31:0]           wdataa, 
    output reg  [31:0]           rdataa, 

    input  wire [3:0]            web,    
    input  wire [ADDR_WIDTH-1:0] addrb,  
    input  wire [31:0]           wdatab, 
    output reg  [31:0]           rdatab  
);

    (* ram_style = "block" *) reg [31:0] mem [0:(1<<ADDR_WIDTH)-1];
    
    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = 32'b0;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(negedge clk) begin
        rdataa <= mem[addra];
        if (wea[3]) mem[addra][31:24] <= wdataa[31:24];
        if (wea[2]) mem[addra][23:16] <= wdataa[23:16];
        if (wea[1]) mem[addra][15:8]  <= wdataa[15:8];
        if (wea[0]) mem[addra][7:0]   <= wdataa[7:0];
    end

    always @(negedge clk) begin
        rdatab <= mem[addrb];
        if (web[3]) mem[addrb][31:24] <= wdatab[31:24];
        if (web[2]) mem[addrb][23:16] <= wdatab[23:16];
        if (web[1]) mem[addrb][15:8]  <= wdatab[15:8];
        if (web[0]) mem[addrb][7:0]   <= wdatab[7:0];
    end

endmodule