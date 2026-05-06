/*******************************************************************************
 * 名称：Mem
 * 描述：支持字节级写使能的同步双端口 Write-First BRAM。
 *
 * 使用方法：
 *   1. 本模块接收【字对齐地址】。使用时将字节地址截断最低两位后接入，
 *      例如传入 address[16:2]。
 *   2. 字节写使能：we[3:0] 对应 wdata[31:0] 的四个字节。
 *      例如 sb：若写第 2 字节，we=4'b0100，wdata 需预先左移 16 位。
 *      例如 sw：we=4'b1111，wdata 无需移位。
 *   3. 可通过 INIT_FILE 传入初始化文件，文件内存储 16 进制字数据。
 *   4. 可通过 ECALL_FILE 传入 ecall 固定指令初始化文件，请注意重叠问题。
 *
 * 内存模型（字节地址）：
 *   1. BRAM空间（本模块实际存储，128KB）：0x0000_0000 ~ 0x0001_FFFF。
 *   2. A口( addra / wea / wdataa / rdataa )：仅用于指令与 ecall 固定指令。
 *      - 指令区：0x0000_0000 ~ 0x0000_EFFF。
 *      - ecall 固定指令区：0x0000_F000 ~ 0x0000_FFFF。
 *      （ECALL文件大小尚不确定，此约定可能发生变化）
 *   3. B口( addrb / web / wdatab / rdatab )：仅用于 BRAM 内的数据区。
 *      - 数据区：0x0001_0000 ~ 0x0001_FFFF。
 *   4. 内存IO不占用 BRAM，放在独立 MMIO 地址空间：
 *      - MMIO 基地址：0x0010_0000。
 *   5. 说明：本模块不做端口访问权限与地址合法性检查，默认由上层地址译码保证；
 *      命中 MMIO 区域时，不应将该访问送入本模块。
 *
 * 注意事项：
 *   1. 读数据在时钟上升沿更新，存在 1 个时钟周期时序延迟。
 *   2. 同一端口在同一时钟沿对同一地址读写时，rdata 返回写入后的新值。
 *   3. 若 A/B 口同一时钟同时写同一地址，结果依赖底层器件行为，应在上层设计避免。
 *   4. 在 Vivado 仿真中，若 INIT_FILE/ECALL_FILE 非绝对路径，初始化文件应置于
 *      工程目录\工程名.sim\sim_1\behav\xsim。
 *
 * 参数：
 *   ADDR_WIDTH  - 字地址位宽 (默认 15，对应 32K 字 = 128KB)
 *   INIT_FILE   - 可选初始化文件路径
 *   ECALL_FILE  - 可选 ecall 初始化文件路径
 ******************************************************************************/
module Mem #(
    parameter ADDR_WIDTH = 15,
    parameter INIT_FILE  = "",
    parameter ECALL_FILE = ""
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
    reg [31:0] mergea;
    reg [31:0] mergeb;

    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) mem[i] = 32'b0;
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else if (ECALL_FILE != "") begin
            $readmemh(ECALL_FILE, mem, 15'h3C00);
        end
    end

    always @(posedge clk) begin
        mergea = mem[addra];
        if (wea[3]) mergea[31:24] = wdataa[31:24];
        if (wea[2]) mergea[23:16] = wdataa[23:16];
        if (wea[1]) mergea[15:8]  = wdataa[15:8];
        if (wea[0]) mergea[7:0]   = wdataa[7:0];

        if (|wea) mem[addra] <= mergea;
        rdataa <= mergea;
    end

    always @(posedge clk) begin
        mergeb = mem[addrb];
        if (web[3]) mergeb[31:24] = wdatab[31:24];
        if (web[2]) mergeb[23:16] = wdatab[23:16];
        if (web[1]) mergeb[15:8]  = wdatab[15:8];
        if (web[0]) mergeb[7:0]   = wdatab[7:0];

        if (|web) mem[addrb] <= mergeb;
        rdatab <= mergeb;
    end

endmodule