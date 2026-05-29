// alu_ctrl_op 编码
// 00000: add, addi
// 00001: sub, subi
// 00010: and, andi
// 00011: or, ori
// 00100: xor, xori
// 00101: lui
// 00110: sll, slli
// 00111: srl, srli
// 01000: slt, slti
// 01001: sra, srai
// 01010: sltu, sltui
// 01011: beq
// 01100: bne
// 01101: blt
// 10000: mul
// 10001: mulh
// 10010: mulhsu
// 10011: mulhu
// 10100: div
// 10101: divu
// 10110: rem
// 10111: remu

// zero
// 1: 条件满足，跳转
// 0: 不跳转

module ALU(
    input [1:0] alu_op,
    input [4:0] alu_ctrl_op,
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

    // 无符号移位加法乘法器，用组合逻辑实现 32x32 -> 64 位整数乘法，避免直接使用 * 运算符。
    function [63:0] mul_unsigned;
        input [31:0] multiplicand;
        input [31:0] multiplier;
        integer i;
        reg [63:0] product;
        begin
            product = 64'b0;
            for (i = 0; i < 32; i = i + 1) begin
                if (multiplier[i]) begin
                    product = product + ({32'b0, multiplicand} << i);
                end
            end
            mul_unsigned = product;
        end
    endfunction

    function [31:0] abs32;
        input [31:0] value;
        begin
            abs32 = value[31] ? (~value + 32'b1) : value;
        end
    endfunction

    function [63:0] mul_signed;
        input [31:0] multiplicand;
        input [31:0] multiplier;
        reg sign;
        reg [63:0] unsigned_product;
        begin
            sign = multiplicand[31] ^ multiplier[31];
            unsigned_product = mul_unsigned(abs32(multiplicand), abs32(multiplier));
            mul_signed = sign ? (~unsigned_product + 64'b1) : unsigned_product;
        end
    endfunction

    function [63:0] mul_signed_unsigned;
        input [31:0] multiplicand;
        input [31:0] multiplier;
        reg [63:0] unsigned_product;
        begin
            unsigned_product = mul_unsigned(abs32(multiplicand), multiplier);
            mul_signed_unsigned = multiplicand[31] ? (~unsigned_product + 64'b1) : unsigned_product;
        end
    endfunction

    // 恢复除法器，用组合逻辑实现 32 位无符号除法，避免直接使用 / 与 % 运算符。
    function [31:0] div_unsigned;
        input [31:0] dividend;
        input [31:0] divisor;
        integer i;
        reg [32:0] remainder;
        reg [31:0] quotient;
        begin
            remainder = 33'b0;
            quotient = 32'b0;
            if (divisor == 32'b0) begin
                div_unsigned = 32'hffff_ffff;
            end else begin
                for (i = 31; i >= 0; i = i - 1) begin
                    remainder = {remainder[31:0], dividend[i]};
                    if (remainder >= {1'b0, divisor}) begin
                        remainder = remainder - {1'b0, divisor};
                        quotient[i] = 1'b1;
                    end
                end
                div_unsigned = quotient;
            end
        end
    endfunction

    function [31:0] rem_unsigned;
        input [31:0] dividend;
        input [31:0] divisor;
        integer i;
        reg [32:0] remainder;
        begin
            remainder = 33'b0;
            if (divisor == 32'b0) begin
                rem_unsigned = dividend;
            end else begin
                for (i = 31; i >= 0; i = i - 1) begin
                    remainder = {remainder[31:0], dividend[i]};
                    if (remainder >= {1'b0, divisor}) begin
                        remainder = remainder - {1'b0, divisor};
                    end
                end
                rem_unsigned = remainder[31:0];
            end
        end
    endfunction

    function [31:0] div_signed;
        input [31:0] dividend;
        input [31:0] divisor;
        reg sign;
        reg [31:0] quotient_abs;
        begin
            if (divisor == 32'b0) begin
                div_signed = 32'hffff_ffff;
            end else if ((dividend == 32'h8000_0000) && (divisor == 32'hffff_ffff)) begin
                div_signed = 32'h8000_0000;
            end else begin
                sign = dividend[31] ^ divisor[31];
                quotient_abs = div_unsigned(abs32(dividend), abs32(divisor));
                div_signed = sign ? (~quotient_abs + 32'b1) : quotient_abs;
            end
        end
    endfunction

    function [31:0] rem_signed;
        input [31:0] dividend;
        input [31:0] divisor;
        reg [31:0] remainder_abs;
        begin
            if (divisor == 32'b0) begin
                rem_signed = dividend;
            end else if ((dividend == 32'h8000_0000) && (divisor == 32'hffff_ffff)) begin
                rem_signed = 32'b0;
            end else begin
                remainder_abs = rem_unsigned(abs32(dividend), abs32(divisor));
                rem_signed = dividend[31] ? (~remainder_abs + 32'b1) : remainder_abs;
            end
        end
    endfunction


    wire [63:0] mul_unsigned_result = mul_unsigned(operand1, operand2);
    wire [63:0] mul_signed_result = mul_signed(operand1, operand2);
    wire [63:0] mul_signed_unsigned_result = mul_signed_unsigned(operand1, operand2);
    wire [31:0] div_signed_result = div_signed(operand1, operand2);
    wire [31:0] div_unsigned_result = div_unsigned(operand1, operand2);
    wire [31:0] rem_signed_result = rem_signed(operand1, operand2);
    wire [31:0] rem_unsigned_result = rem_unsigned(operand1, operand2);

    // ALU 运算结果生成（组合逻辑）
    assign alu_result_comb =     (alu_ctrl_op == 5'b00000) ? (operand1 + operand2) :  // add, addi
                                 (alu_ctrl_op == 5'b00001) ? (operand1 - operand2) :  // sub, subi
                                 (alu_ctrl_op == 5'b00010) ? (operand1 & operand2) :  // and, andi
                                 (alu_ctrl_op == 5'b00011) ? (operand1 | operand2) :  // or, ori
                                 (alu_ctrl_op == 5'b00100) ? (operand1 ^ operand2) :  // xor, xori
                                 (alu_ctrl_op == 5'b00101) ? (operand2) :        // lui
                                 (alu_ctrl_op == 5'b00110) ? (operand1 << operand2[4:0]) :  // sll, slli
                                 (alu_ctrl_op == 5'b00111) ? (operand1 >> operand2[4:0]) :  // srl, srli
                                 (alu_ctrl_op == 5'b01000) ? (($signed(operand1) < $signed(operand2)) ? 32'b1 : 32'b0) :  // slt, slti
                                 (alu_ctrl_op == 5'b01001) ? ($signed(operand1) >>> operand2[4:0]) :  // sra, srai
                                 (alu_ctrl_op == 5'b01010) ? ((operand1 < operand2) ? 32'b1 : 32'b0) :  // sltu, sltui
                                 (alu_ctrl_op == 5'b01011) ? ((operand1 == operand2) ? 32'b1 : 32'b0) :  // beq
                                 (alu_ctrl_op == 5'b01100) ? ((operand1 != operand2) ? 32'b1 : 32'b0) :  // bne
                                 (alu_ctrl_op == 5'b01101) ? (($signed(operand1) < $signed(operand2)) ? 32'b1 : 32'b0) :  // blt
                                 (alu_ctrl_op == 5'b10000) ? mul_unsigned_result[31:0] :  // mul
                                 (alu_ctrl_op == 5'b10001) ? mul_signed_result[63:32] :  // mulh
                                 (alu_ctrl_op == 5'b10010) ? mul_signed_unsigned_result[63:32] :  // mulhsu
                                 (alu_ctrl_op == 5'b10011) ? mul_unsigned_result[63:32] :  // mulhu
                                 (alu_ctrl_op == 5'b10100) ? div_signed_result :  // div
                                 (alu_ctrl_op == 5'b10101) ? div_unsigned_result :  // divu
                                 (alu_ctrl_op == 5'b10110) ? rem_signed_result :  // rem
                                 (alu_ctrl_op == 5'b10111) ? rem_unsigned_result :  // remu
                                 32'b0;

    // Zero 标志生成（组合逻辑）
    assign zero_comb = (alu_ctrl_op == 5'b01011) ? ((operand1 == operand2) ? 1'b1 : 1'b0) :
                       (alu_ctrl_op == 5'b01100) ? ((operand1 != operand2) ? 1'b1 : 1'b0) :
                       (alu_ctrl_op == 5'b01101) ? (($signed(operand1) < $signed(operand2)) ? 1'b1 : 1'b0) :
                       1'b0;    // 其他: 结果为0表示zero成立

endmodule
