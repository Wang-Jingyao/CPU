module PC(
    input clk,
    input rst_n,
    input en,
    input jal_en,
    input jalr_en,
    input [31:0] rs1,
    input branch,
    input zero,
    input [31:0] imm,
    output reg [31:0] rd_add,
    output reg [31:0] address
);
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address <= 32'd0;
        end
        else if (en) begin
            if (branch && zero) begin
                address <= address + imm;
            end
            else begin
                if (jal_en) begin
                    rd_add <= address + 32'd4;
                    address <= address + imm;
                end
                else if (jalr_en) begin
                    rd_add <= address + 32'd4;
                    address <= (rs1 + imm) & 32'hfffffffe;
                end
                else begin
                    address <= address + 32'd4;
                end
            end
        end
    end
endmodule
