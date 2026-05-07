module PC(
    input clk,
    input rst_n,
    input branch,
    input zero,
    input [31:0] imm,
    output reg [31:0] address
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address <= 32'd0;
        end
        else begin
            if (branch && zero) begin
                address <= address + imm;
            end
            else begin
                address <= address + 32'd4;
            end
        end
    end
endmodule
