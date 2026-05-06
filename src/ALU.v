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

module ALU(
    input clk,
    input rst_n,
    input [1:0] alu_op,
    input [3:0] alu_ctrl_op,
    input alu_src,
    input [31:0] read_data1,
    input [31:0] read_data2,
    input [31:0] imm,
    output reg zero,
    output reg [31:0] alu_result
);

    wire [31:0] operand1 = read_data1;
    wire [31:0] operand2 = alu_src ? imm : read_data2;

    always @(*) begin
        case (alu_op)
            2'b00: alu_result = operand1 + operand2; // 加法类（load/store, auipc, jalr, addi）
            2'b01: alu_result = operand1 - operand2; // 减法类（分支比较）
            2'b10: begin
                case (alu_ctrl_op)
                    4'b0000:
                    begin
                        alu_result = operand1 + operand2; // add, addi
                    end
                    4'b0001: 
                    begin
                        alu_result = operand1 - operand2; // sub, subi
                    end
                    4'b0010: 
                    begin
                        alu_result = operand1 & operand2; // and, andi
                    end
                    4'b0011: 
                    begin
                        alu_result = operand1 | operand2; // or, ori
                    end
                    4'b0100: 
                    begin
                        alu_result = operand1 ^ operand2; // xor, xori
                    end
                    4'b0101: 
                    begin
                        alu_result = operand2 << 12; // lui
                    end
                    4'b0110: 
                    begin
                        alu_result = operand1 << operand2; // sll, slli
                    end
                    4'b0111: 
                    begin
                        alu_result = operand1 >> operand2; // srl, srli
                    end
                    4'b1000: 
                    begin
                        alu_result = ($signed(operand1) < $signed(operand2)) ? 32'b1 : 32'b0; // slt, slti
                    end
                    4'b1001: 
                    begin
                        alu_result = $signed(operand1) >>> operand2; // sra, srai
                    end
                    4'b1010: 
                    begin
                        alu_result = (operand1 < operand2) ? 32'b1 : 32'b0; // sltu, sltui
                    end
                    4'b1011: 
                    begin
                        alu_result = (operand1 == operand2) ? 32'b1 : 32'b0; // beq
                    end
                    4'b1100: 
                    begin
                        alu_result = (operand1 != operand2) ? 32'b1 : 32'b0; // bne
                    end
                    4'b1101:
                    begin
                        alu_result = (operand1 < operand2) ? 32'b1 : 32'b0; // blt
                    end
                    default: alu_result = 32'b0;
                endcase
            end
        endcase
    end

    always @(*) begin
    if (alu_ctrl_op == 4'b1100 || alu_ctrl_op == 4'b1101) begin
        zero = (alu_result == 32'b0) ? 1'b0 : 1'b1;
    end else begin
        zero = (alu_result == 32'b0) ? 1'b1 : 1'b0;
    end
    end
endmodule