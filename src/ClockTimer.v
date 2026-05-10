`timescale 1ns / 1ps

module ClockTimer(
    input        clk,
    input        rst_n,
    output reg   clk_50m,
    output reg   clk_25m,
    output reg   clk_1m,
    output reg [63:0] time_value
);

    reg [6:0] div_1m_cnt;

    // 50MHz clock from 100MHz input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_50m <= 1'b0;
            div_1m_cnt <= 7'd0;
            clk_1m <= 1'b0;
        end else begin
            clk_50m <= ~clk_50m;
            if (div_1m_cnt == 7'd49) begin
                div_1m_cnt <= 7'd0;
                clk_1m <= ~clk_1m;
            end else begin
                div_1m_cnt <= div_1m_cnt + 7'd1;
            end
        end
    end

    // 25MHz clock from 50MHz clock
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            clk_25m <= 1'b0;
        end else begin
            clk_25m <= ~clk_25m;
        end
    end

    // 64-bit timer driven by 1MHz clock
    always @(posedge clk_1m or negedge rst_n) begin
        if (!rst_n) begin
            time_value <= 64'b0;
        end else begin
            time_value <= time_value + 64'b1;
        end
    end

endmodule