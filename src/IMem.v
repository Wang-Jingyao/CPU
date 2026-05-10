/*******************************************************************************
 * 名称：IMem
 * 描述：指令取值封装模块。该模块本身不直接存储 BRAM，只负责把取指地址
 *       按字对齐后送入 Mem，并把 Mem 的读数据作为当前指令输出（异步读，无延迟）。
 *
 * 内存模型约定：
 *   1. 指令空间使用字节地址 0x0001_0000 ~ 0x0001_FFFF 对应的 BRAM 区域。
 *   2. 其中 0x0001_F000 ~ 0x0001_FFFF 为 ecall 固定指令区，初始化内容由
 *      Mem 的 ECALL_FILE 参数提供。（ECALL文件大小尚不确定，此约定可能发生变化）
 *   3. 取指地址必须按字对齐输入，本模块使用 address[16:2] 作为字地址。
 *   4. 当地址不在指令空间时，instruction 输出 0。
 *   5. 指令读取为异步读，地址变化时指令立即有效，无时钟延迟。
 *
 * 端口说明：
 *   rst_n       - 低有效复位，复位时 instruction 清零
 *   address     - 32 位字节地址
 *   instruction - 输出指令字（异步读，当周期有效）
 *   mem_rdata   - 来自 Mem 的读数据
 *   mem_addr    - 送往 Mem 的字地址
 *   mem_we      - 读指令时固定为 0
 *   mem_wdata   - 送往 Mem 的写数据，指令口不写，因此固定为 0
 *******************************************************************************/
module IMem(
    input rst_n,
    input [31:0] address,
    output [31:0] instruction,

    input [31:0] mem_rdata,
    output [14:0] mem_addr,
    output [3:0] mem_we,
    output [31:0] mem_wdata
);

    assign mem_addr = address[16:2];
    assign mem_we = 4'b0000;
    assign mem_wdata = 32'b0;
    assign instruction = (rst_n && (address[31:16] == 16'h0001)) ? mem_rdata : 32'b0;

endmodule
