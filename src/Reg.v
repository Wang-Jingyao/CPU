module Reg(
    input clk,
    input rst_n,
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,
    input reg_write,
    input mem_to_reg,
    input [31:0] read_data,
    input [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    
    // Debug port: 调试读接口
    input [4:0] dbg_reg_addr,
    output [31:0] dbg_reg_data
);
    wire [31:0] data = mem_to_reg ? read_data : write_data;

    reg [31:0] registers [1:31];
    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1) begin
            registers[i] = 32'b0;
        end
        registers[2] = 32'h0000_EFFC; // sp 初始值
        registers[3] = 32'h0000_4000; // gp 初始值
    end

    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // 调试读：支持读任意寄存器，x0 始终返回 0
    assign dbg_reg_data = (dbg_reg_addr == 5'b0) ? 32'b0 : registers[dbg_reg_addr];

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 1; j < 32; j = j + 1) begin
                registers[j] <= 32'b0;
            end
            registers[2] <= 32'h0000_EFFC;
            registers[3] <= 32'h0000_4000;
        end else if (reg_write) begin
            if (rd != 5'b0) begin
                registers[rd] <= data;
            end
        end
    end
endmodule
