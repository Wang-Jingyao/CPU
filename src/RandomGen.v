module RandomGen(
    input clk,
    input rst_n,
    output [31:0] rand_num
);

    // 32位LFSR随机数生成器
    // 使用多项式 x^32 + x^22 + x^2 + x^1 + 1
    reg [31:0] lfsr;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 32'h12345678;  // 非零初始值
        end else begin
            // LFSR反馈：位31 XOR 位21 XOR 位1 XOR 位0
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
        end
    end
    
    assign rand_num = lfsr;

endmodule