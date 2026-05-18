`timescale 1ns / 1ps

module tb_IMem();
    reg clk = 0; always #5 clk = ~clk;
    reg rst_n = 0;
    reg [31:0] address = 32'b0;
    wire [31:0] instruction;

    // debug signals
    reg inst_dbg_en = 0;
    reg inst_wr_en = 0;
    reg [31:0] inst_dbg_addr = 32'b0;
    reg [31:0] inst_wr_data = 32'b0;
    wire [31:0] inst_rd_data;

    IMem uut (
        .clk(clk),
        .rst_n(rst_n),
        .address(address),
        .instruction(instruction),
        .inst_dbg_en(inst_dbg_en),
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data)
    );

    initial begin
        $display("[tb_IMem] start");
        #12; rst_n = 1;

        // Write via debug to word at byte address 4
        inst_dbg_en = 1; inst_wr_en = 1; inst_dbg_addr = 32'h0000_0004; inst_wr_data = 32'hDEAD_BEEF;
        #10; inst_wr_en = 0; inst_dbg_en = 0; #20;
        $display("[tb_IMem] inst_rd_data=%08h instruction=%08h", inst_rd_data, instruction);

        // Read via normal address
        address = 32'h0000_0004; #10;
        $display("[tb_IMem] read via addr instruction=%08h", instruction);

        $display("[tb_IMem] done"); $finish;
    end
endmodule
