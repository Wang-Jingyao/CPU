module ClockTimer(
    input             clk,         // 100MHz
    input             rst_n,
    output            clk_25m,
    output reg [63:0] time_value
);

    reg       clk_25m_logic;
    reg [1:0] cnt_25m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_25m_logic <= 1'b0;
            cnt_25m       <= 2'd0;
        end else begin
            if (cnt_25m >= 2'd1) begin
                cnt_25m       <= 2'd0;
                clk_25m_logic <= ~clk_25m_logic;
            end else begin
                cnt_25m       <= cnt_25m + 2'd1;
            end
        end
    end

    BUFG bufg_25m (
        .O(clk_25m), 
        .I(clk_25m_logic)
    );

    reg [6:0] cnt_1us;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1us    <= 7'd0;
            time_value <= 64'b0;
        end else begin
            if (cnt_1us >= 7'd99) begin
                cnt_1us    <= 7'd0;
                time_value <= time_value + 64'b1;
            end else begin
                cnt_1us    <= cnt_1us + 7'd1;
            end
        end
    end

endmodule