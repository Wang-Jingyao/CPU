module ALU(
    input clk,
    input rst_n,
    input [1:0] alu_op,
    input [3:0] alu_ctrl_op,
    input alu_src,
    input read_data1,
    input read_data2,
    input [31:0] imm,
    output zero,
    output [31:0] alu_result
);

endmodule