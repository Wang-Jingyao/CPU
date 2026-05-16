// alu_ctrl_op 编码
// 0000: add, addi
// 0001: sub, subi
// 0010: and, andi
// 0011: or, ori
// 0100: xor, xori
// 0101: lui
// 0110: sll, slli
// 0111: srl, srli
// 1000: slt, slti
// 1001: sra, srai
// 1010: sltu, sltui
// 1011: beq
// 1100: bne
// 1101: blt
// 暂定，后续根据实际需求调整

// zero
// 1: 条件满足，跳转
// 0: 不跳转

module ALU(
    input [1:0] alu_op,
    input [3:0] alu_ctrl_op,
    input alu_src,
    input [31:0] read_data1,
    input [31:0] read_data2,
    input [31:0] imm,
    output wire zero,
    output wire [31:0] alu_result
);

    wire [31:0] operand1 = read_data1;
    wire [31:0] operand2 = alu_src ? imm : read_data2;
    wire [31:0] alu_result_comb;
    wire zero_comb;

    assign alu_result = alu_result_comb;
    assign zero = zero_comb;

    // ALU 运算结果生成（组合逻辑）
    assign alu_result_comb = (alu_op == 2'b00) ? (operand1 + operand2) :  // 加法类
                             (alu_op == 2'b01) ? (operand1 - operand2) :  // 减法类
                             (alu_op == 2'b10) ? (
                                 (alu_ctrl_op == 4'b0000) ? (operand1 + operand2) :  // add, addi
                                 (alu_ctrl_op == 4'b0001) ? (operand1 - operand2) :  // sub, subi
                                 (alu_ctrl_op == 4'b0010) ? (operand1 & operand2) :  // and, andi
                                 (alu_ctrl_op == 4'b0011) ? (operand1 | operand2) :  // or, ori
                                 (alu_ctrl_op == 4'b0100) ? (operand1 ^ operand2) :  // xor, xori
                                 (alu_ctrl_op == 4'b0101) ? (operand2 << 12) :        // lui
                                 (alu_ctrl_op == 4'b0110) ? (operand1 << operand2[4:0]) :  // sll, slli
                                 (alu_ctrl_op == 4'b0111) ? (operand1 >> operand2[4:0]) :  // srl, srli
                                 (alu_ctrl_op == 4'b1000) ? (($signed(operand1) < $signed(operand2)) ? 32'b1 : 32'b0) :  // slt, slti
                                 (alu_ctrl_op == 4'b1001) ? ( (operand1[31] == 1'b1) ? 
                                      ((operand1 >> operand2[4:0]) | (~(32'hffffffff >> operand2[4:0]))) :
                                      (operand1 >> operand2[4:0]) 
                                    ) :  // sra, srai
                                 (alu_ctrl_op == 4'b1010) ? ((operand1 < operand2) ? 32'b1 : 32'b0) :  // sltu, sltui
                                 (alu_ctrl_op == 4'b1011) ? ((operand1 == operand2) ? 32'b1 : 32'b0) :  // beq
                                 (alu_ctrl_op == 4'b1100) ? ((operand1 != operand2) ? 32'b1 : 32'b0) :  // bne
                                 (alu_ctrl_op == 4'b1101) ? ((operand1 < operand2) ? 32'b1 : 32'b0) :  // blt
                                 32'b0
                             ) : 32'b0;

    // Zero 标志生成（组合逻辑）
    assign zero_comb = (alu_ctrl_op == 4'b1011) ? ((operand1 == operand2) ? 1'b1 : 1'b0) :
                       (alu_ctrl_op == 4'b1100) ? ((operand1 != operand2) ? 1'b1 : 1'b0) : 
                       (alu_ctrl_op == 4'b1101) ? ((operand1 < operand2) ? 1'b1 : 1'b0) :
                       1'b0;    // 其他: 结果为0表示zero成立

endmodule