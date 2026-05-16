module ClockTimer(
    input        clk,      // 100MHz
    input        rst_n,
    output       clk_50m,
    output       clk_25m,
    output       clk_1m,
    output reg [63:0] time_value
);

    reg clk_50m_logic, clk_25m_logic, clk_1m_logic;
    reg [1:0] cnt_25m;   // 25MHz: 100MHz/4
    reg [6:0] cnt_1m;    // 1MHz: 100MHz/100

    // 所有分频都基于原始 clk，避免级联
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_50m_logic <= 1'b0;
            clk_25m_logic <= 1'b0;
            clk_1m_logic <= 1'b0;
            cnt_25m <= 2'd0;
            cnt_1m <= 7'd0;
        end else begin
            // 50MHz: 每1个clk翻转一次
            clk_50m_logic <= ~clk_50m_logic;
            
            // 25MHz: 每2个clk翻转一次 (100MHz/4)
            if (cnt_25m == 2'd1) begin
                cnt_25m <= 2'd0;
                clk_25m_logic <= ~clk_25m_logic;
            end else begin
                cnt_25m <= cnt_25m + 2'd1;
            end
            
            // 1MHz: 每49个clk翻转一次 (100MHz/100)
            if (cnt_1m == 7'd49) begin
                cnt_1m <= 7'd0;
                clk_1m_logic <= ~clk_1m_logic;
            end else begin
                cnt_1m <= cnt_1m + 7'd1;
            end
        end
    end

    // 三个 BUFG 分别输出
    BUFG bufg_50m (.O(clk_50m), .I(clk_50m_logic));
    BUFG bufg_25m (.O(clk_25m), .I(clk_25m_logic));
    BUFG bufg_1m  (.O(clk_1m),  .I(clk_1m_logic));

    // 定时器使用稳定的 clk_1m
    always @(posedge clk_1m or negedge rst_n) begin
        if (!rst_n) begin
            time_value <= 64'b0;
        end else begin
            time_value <= time_value + 64'b1;
        end
    end

endmodule