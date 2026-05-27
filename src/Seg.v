module Seg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] seg_data,

    output reg  [7:0]  seg_data_left,
    output reg  [3:0]  seg_sel_left,
    output reg  [7:0]  seg_data_right,
    output reg  [3:0]  seg_sel_right
);

reg        clk_1khz;
reg [15:0]  div_cnt_1khz;
reg [1:0] scan_cnt;

function [7:0] seg_decode;
    input [3:0] value;
    begin
        case (value)
            4'h0: seg_decode = 8'b1111_1100;
            4'h1: seg_decode = 8'b0110_0000;
            4'h2: seg_decode = 8'b1101_1010;
            4'h3: seg_decode = 8'b1111_0010;
            4'h4: seg_decode = 8'b0110_0110;
            4'h5: seg_decode = 8'b1011_0110;
            4'h6: seg_decode = 8'b1011_1110;
            4'h7: seg_decode = 8'b1110_0000;
            4'h8: seg_decode = 8'b1111_1110;
            4'h9: seg_decode = 8'b1110_0110;
            4'ha: seg_decode = 8'b1110_1110;
            4'hb: seg_decode = 8'b0011_1110;
            4'hc: seg_decode = 8'b1001_1100;
            4'hd: seg_decode = 8'b0111_1010;
            4'he: seg_decode = 8'b1001_1110;
            4'hf: seg_decode = 8'b1000_1110;
            default: seg_decode = 8'b0000_0001;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_1khz      <= 1'b0;
        div_cnt_1khz  <= 16'd0;
    end else begin
        if (div_cnt_1khz == 16'd49_999) begin
            div_cnt_1khz <= 16'd0;
            clk_1khz     <= ~clk_1khz;
        end else begin
            div_cnt_1khz <= div_cnt_1khz + 16'd1;
        end
    end
end

always @(posedge clk_1khz or negedge rst_n) begin
    if (!rst_n) begin
        scan_cnt       <= 2'b00;
        seg_sel_left   <= 4'b1111;
        seg_sel_right  <= 4'b1111;
        seg_data_left  <= 8'h00;
        seg_data_right <= 8'h00;
    end else begin
        scan_cnt <= scan_cnt + 2'b01;

        case (scan_cnt)
            2'b00: begin
                seg_sel_left   <= 4'b0001;
                seg_data_left  <= seg_decode(seg_data[19:16]);
                seg_sel_right  <= 4'b0001;
                seg_data_right <= seg_decode(seg_data[3:0]);
            end
            2'b01: begin
                seg_sel_left   <= 4'b0010;
                seg_data_left  <= seg_decode(seg_data[23:20]);
                seg_sel_right  <= 4'b0010;
                seg_data_right <= seg_decode(seg_data[7:4]);
            end
            2'b10: begin
                seg_sel_left   <= 4'b0100;
                seg_data_left  <= seg_decode(seg_data[27:24]);
                seg_sel_right  <= 4'b0100;
                seg_data_right <= seg_decode(seg_data[11:8]);
            end
            2'b11: begin
                seg_sel_left   <= 4'b1000;
                seg_data_left  <= seg_decode(seg_data[31:28]);
                seg_sel_right  <= 4'b1000;
                seg_data_right <= seg_decode(seg_data[15:12]);
            end
        endcase
    end
end

endmodule