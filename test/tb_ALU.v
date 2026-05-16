`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/16 19:49:46
// Design Name: 
// Module Name: tb_ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module tb_ALU;

    // 输入
    reg [1:0] alu_op;
    reg [3:0] alu_ctrl_op;
    reg alu_src;
    reg [31:0] read_data1;
    reg [31:0] read_data2;
    reg [31:0] imm;

    // 输出
    wire zero;
    wire [31:0] alu_result;

    // 实例化被测模块
    ALU dut (
        .alu_op(alu_op),
        .alu_ctrl_op(alu_ctrl_op),
        .alu_src(alu_src),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .imm(imm),
        .zero(zero),
        .alu_result(alu_result)
    );

    // 用于错误计数
    integer error_count = 0;

    // 测试辅助任务：一次比较
    task check_output;
        input [31:0] expected_result;
        input expected_zero;
        input [256*8:1] test_desc;  // 描述字符串
        begin
            #1; // 等待组合逻辑稳定
            if (alu_result !== expected_result || zero !== expected_zero) begin
                $display("FAIL: %s", test_desc);
                $display("  Expected result=%h, zero=%b", expected_result, expected_zero);
                $display("  Got      result=%h, zero=%b", alu_result, zero);
                error_count = error_count + 1;
            end else begin
                $display("PASS: %s", test_desc);
            end
        end
    endtask

    // 主测试序列
    initial begin
        // 初始化
        alu_op = 2'b00; alu_ctrl_op = 4'b0000; alu_src = 0;
        read_data1 = 0; read_data2 = 0; imm = 0;
        #10;

        // ========================
        // 1. 测试 alu_op = 00 (加法)
        // ========================
        alu_op = 2'b00;
        read_data1 = 32'd10;
        read_data2 = 32'd20;
        imm = 32'd30;       // 当前 alu_src=0 时选用 read_data2
        check_output(32'd30, 1'b0, "ADD: 10+20=30, zero=0");

        // 测试 alu_src=1，第二操作数变为 imm
        alu_src = 1'b1;
        check_output(32'd40, 1'b0, "ADD with imm: 10+30=40");

        // 测试加法结果为0
        read_data1 = 32'hFFFF_FFF0;
        imm = 32'h0000_0010; // 相加 = 0
        check_output(32'h0000_0000, 1'b0, "ADD overflow to zero, zero=0");

        // ========================
        // 2. 测试 alu_op = 01 (减法)
        // ========================
        alu_op = 2'b01; alu_src = 0;
        read_data1 = 32'd50;
        read_data2 = 32'd20;
        check_output(32'd30, 1'b0, "SUB: 50-20=30");
        // 结果为0
        read_data1 = 32'd15; read_data2 = 32'd15;
        check_output(32'd0, 1'b0, "SUB result 0, zero=0");

        // ========================
        // 3. alu_op = 10, 测试各种 alu_ctrl_op
        // ========================
        alu_op = 2'b10;
        alu_src = 0;  // 先用 read_data2

        // 3.1 ADD (0000)
        alu_ctrl_op = 4'b0000;
        read_data1 = 32'd3; read_data2 = 32'd5;
        check_output(32'd8, 1'b0, "ALU_ADD: 3+5=8");

        // 3.2 SUB (0001)
        alu_ctrl_op = 4'b0001;
        read_data1 = 32'd10; read_data2 = 32'd3;
        check_output(32'd7, 1'b0, "ALU_SUB: 10-3=7");
        // sub 得 0
        read_data1 = 32'd99; read_data2 = 32'd99;
        check_output(32'd0, 1'b0, "ALU_SUB result 0");

        // 3.3 AND (0010)
        alu_ctrl_op = 4'b0010;
        read_data1 = 32'h0000_FF0F; read_data2 = 32'h0000_F0F0;
        check_output(32'h0000_F000, 1'b0, "ALU_AND");

        // 3.4 OR (0011)
        alu_ctrl_op = 4'b0011;
        check_output(32'h0000_FFFF, 1'b0, "ALU_OR");

        // 3.5 XOR (0100)
        alu_ctrl_op = 4'b0100;
        check_output(32'h0000_0FFF, 1'b0, "ALU_XOR");

        // 3.6 LUI (0101) – 此时 operand2 应为 imm，无关 alu_src?
        //    注意你的代码 lui 直接 operand2 << 12，operand2 由 alu_src 选择。
        //    所以如果想做 lui 应将 alu_src 设为1 使用 imm。
        alu_ctrl_op = 4'b0101;
        alu_src = 1'b1;
        imm = 32'h0000_1234;
        check_output(32'h0123_4000, 1'b0, "LUI: imm<<12");

        // 3.7 SLL (0110)
        alu_ctrl_op = 4'b0110;
        alu_src = 0;
        read_data1 = 32'h0000_000F;
        read_data2 = 32'd4;   // 低5位决定移位数
        check_output(32'h0000_00F0, 1'b0, "SLL: 0xF << 4 = 0xF0");

        // 移位数 >=32，看是否取低5位
        read_data2 = 32'd36;  // 低5位=4
        check_output(32'h0000_00F0, 1'b0, "SLL shift>=32 (36&31=4)");

        // 3.8 SRL (0111)
        alu_ctrl_op = 4'b0111;
        read_data1 = 32'hF000_0000;
        read_data2 = 32'd4;
        check_output(32'h0F00_0000, 1'b0, "SRL: 0xF0000000 >>4 = 0x0F000000");

        // 3.9 SLT (1000) 有符号比较
        alu_ctrl_op = 4'b1000;
        read_data1 = 32'd5; read_data2 = 32'd3; // 5 < 3? false -> 0
        check_output(32'd0, 1'b0, "SLT: 5<3 is false");
        read_data1 = 32'hFFFF_FFFE; // -2
        read_data2 = 32'd3;         //  3
        check_output(32'd1, 1'b0, "SLT: -2<3 is true");
        read_data1 = 32'd5; read_data2 = 32'd5; // equal
        check_output(32'd0, 1'b0, "SLT: 5<5 is false");

        // 3.10 SRA (1001) 算术右移
        alu_ctrl_op = 4'b1001;
        read_data1 = 32'h8000_0000; // 负数
        read_data2 = 32'd4;
        check_output(32'hF800_0000, 1'b0, "SRA: negative >>4");
        read_data1 = 32'h0000_000F; read_data2 = 32'd1;
        check_output(32'h0000_0007, 1'b0, "SRA: positive >>1");

        // 3.11 SLTU (1010) 无符号比较
        alu_ctrl_op = 4'b1010;
        read_data1 = 32'hFFFF_FFFE; // 很大的无符号数
        read_data2 = 32'd3;
        check_output(32'd0, 1'b0, "SLTU: large_unsigned < 3 is false");
        read_data1 = 32'd1; read_data2 = 32'd2;
        check_output(32'd1, 1'b0, "SLTU: 1<2 is true");

        // 3.12 BEQ (1011) 相等比较
        alu_ctrl_op = 4'b1011;
        read_data1 = 32'd5; read_data2 = 32'd5;
        check_output(32'd1, 1'b1, "BEQ: 5==5, result=1, zero=1");
        read_data1 = 32'd5; read_data2 = 32'd3;
        check_output(32'd0, 1'b0, "BEQ: 5!=3, result=0, zero=0");

        // 3.13 BNE (1100) 不等比较
        alu_ctrl_op = 4'b1100;
        read_data1 = 32'd5; read_data2 = 32'd3;
        check_output(32'd1, 1'b1, "BNE: 5!=3, result=1, zero=1");
        read_data1 = 32'd5; read_data2 = 32'd5;
        check_output(32'd0, 1'b0, "BNE: 5==5, result=0, zero=0");

        // 3.14 BLT (1101) 有符号小于
        alu_ctrl_op = 4'b1101;
        read_data1 = 32'd3; read_data2 = 32'd5;
        check_output(32'd1, 1'b1, "BLT: 3<5, result=1, zero=1");
        read_data1 = 32'd5; read_data2 = 32'd3;
        check_output(32'd0, 1'b0, "BLT: 5<3, result=0, zero=0");


        // 汇总结果
        if (error_count == 0) begin
            $display("=== ALL TESTS PASSED ===");
        end else begin
            $display("=== %0d TEST(S) FAILED ===", error_count);
        end
        $finish;
    end

    // 波形导出
    initial begin
        $dumpfile("tb_ALU.vcd");
        $dumpvars(0, tb_ALU);
    end

endmodule
