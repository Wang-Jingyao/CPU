`timescale 1ns / 1ps

module tb_DMem();
    reg clk = 0; always #5 clk = ~clk;
    reg rst_n = 0;

    reg mem_write = 0;
    reg [2:0] type = 3'b010; // lw default
    reg [31:0] address = 32'b0;
    reg [31:0] write_data = 32'b0;
    wire [31:0] read_data;

    reg [7:0] sw_data = 8'h5A;
    reg [63:0] time_value = 64'h0123_4567_89AB_CDEF;
    reg [7:0] kbd_data = 8'b0;
    reg [31:0] rand_num = 32'hCAF_EBABE;
    wire [7:0] led_data;
    wire [31:0] seg_data;

    // debug
    reg dmem_dbg_en = 0;
    reg dmem_wr_en = 0;
    reg [31:0] dmem_dbg_addr = 32'b0;
    reg [31:0] dmem_wr_data = 32'b0;
    wire [31:0] dmem_rd_data;

    DMem uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_write(mem_write),
        .type(type),
        .address(address),
        .write_data(write_data),
        .read_data(read_data),
        .sw_data(sw_data),
        .time_value(time_value),
        .kbd_data(kbd_data),
        .rand_num(rand_num),
        .led_data(led_data),
        .seg_data(seg_data),
        .dmem_dbg_en(dmem_dbg_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data)
    );

    initial begin
        $display("[tb_DMem] start");
        #12; rst_n = 1;

        // Write SEG (word)
        address = 32'h0010_0008; write_data = 32'hA1B2_C3D4; type = 3'b101; mem_write = 1;
        #10; mem_write = 0; #5;
        $display("[tb_DMem] seg_data=%08h", seg_data);

        // Write LED (byte)
        address = 32'h0010_0004; write_data = 32'h000000AA; type = 3'b011; mem_write = 1;
        #10; mem_write = 0; #5;
        $display("[tb_DMem] led_data=%02h", led_data);

        // Read SW via load byte
        address = 32'h0010_0000; type = 3'b000; mem_write = 0; #1;
        $display("[tb_DMem] read_data (SW)=%08h", read_data);

        $display("[tb_DMem] done"); $finish;
    end
endmodule
