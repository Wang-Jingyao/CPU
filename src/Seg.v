module Seg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] seg_data,

    output reg  [7:0]  seg_data_left,
    output reg  [3:0]  seg_sel_left,
    output reg  [7:0]  seg_data_right,
    output reg  [3:0]  seg_sel_right
);

endmodule