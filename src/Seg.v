module Seg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] seg_data,

    output reg  [7:0]  seg_data_left,
    output reg  [3:0]  seg_sel_left,
    output reg  [7:0]  seg_data_right,
    output reg  [3:0]  seg_sel_right
);

reg [1:0] scan_cnt;

function [7:0] seg_decode;
    input [3:0] value;
    begin
        case (value)
            4'h0: seg_decode = 8'hc0;
            4'h1: seg_decode = 8'hf9;
            4'h2: seg_decode = 8'ha4;
            4'h3: seg_decode = 8'hb0;
            4'h4: seg_decode = 8'h99;
            4'h5: seg_decode = 8'h92;
            4'h6: seg_decode = 8'h82;
            4'h7: seg_decode = 8'hf8;
            4'h8: seg_decode = 8'h80;
            4'h9: seg_decode = 8'h90;
            4'ha: seg_decode = 8'h88;
            4'hb: seg_decode = 8'h83;
            4'hc: seg_decode = 8'hc6;
            4'hd: seg_decode = 8'ha1;
            4'he: seg_decode = 8'h86;
            4'hf: seg_decode = 8'h8e;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scan_cnt       <= 2'b00;
        seg_sel_left   <= 4'b1110;
        seg_sel_right  <= 4'b1110;
        seg_data_left  <= 8'hff;
        seg_data_right <= 8'hff;
    end else begin
        scan_cnt <= scan_cnt + 2'b01;

        case (scan_cnt)
            2'b00: begin
                seg_sel_left   <= 4'b1110;
                seg_data_left  <= seg_decode(seg_data[31:28]);
                seg_sel_right  <= 4'b1110;
                seg_data_right <= seg_decode(seg_data[3:0]);
            end
            2'b01: begin
                seg_sel_left   <= 4'b1101;
                seg_data_left  <= seg_decode(seg_data[27:24]);
                seg_sel_right  <= 4'b1101;
                seg_data_right <= seg_decode(seg_data[7:4]);
            end
            2'b10: begin
                seg_sel_left   <= 4'b1011;
                seg_data_left  <= seg_decode(seg_data[23:20]);
                seg_sel_right  <= 4'b1011;
                seg_data_right <= seg_decode(seg_data[11:8]);
            end
            2'b11: begin
                seg_sel_left   <= 4'b0111;
                seg_data_left  <= seg_decode(seg_data[19:16]);
                seg_sel_right  <= 4'b0111;
                seg_data_right <= seg_decode(seg_data[15:12]);
            end
        endcase
    end
end

endmodule