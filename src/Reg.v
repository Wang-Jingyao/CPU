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

    reg [31:0] registers [0:31];
    wire [31:0] data = mem_to_reg ? read_data : write_data;

    assign read_data1 = (rs1 != 5'b0) ? registers[rs1] : 32'b0;
    assign read_data2 = (rs2 != 5'b0) ? registers[rs2] : 32'b0;
    
    // 调试读：支持读任意寄存器，x0始终返回0
    assign dbg_reg_data = (dbg_reg_addr == 5'b0) ? 32'b0 : registers[dbg_reg_addr];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (reg_write) begin
            if (rd != 5'b0) begin
                registers[rd] <= data;
            end
        end
    end
endmodule
