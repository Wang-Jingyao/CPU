`timescale 1ns / 1ps

module tb_Mem();
    reg clk = 0;
    always #5 clk = ~clk;

    reg [3:0] wea = 4'b0000;
    reg [3:0] addra = 4'b0000;
    reg [31:0] wdataa = 32'b0;
    wire [31:0] rdataa;

    Mem #(.ADDR_WIDTH(4)) uut (
        .clk(clk),
        .wea(wea),
        .addra(addra),
        .wdataa(wdataa),
        .rdataa(rdataa),
        .web(4'b0000),
        .addrb(4'b0),
        .wdatab(32'b0),
        .rdatab()
    );

    initial begin
        $display("[tb_Mem] start");
        #12;

        // Write a full word to address 0
        addra = 4'd0; wdataa = 32'h11223344; wea = 4'b1111;
        #10; // wait for negedge in Mem
        wea = 4'b0000; #10;
        $display("[tb_Mem] after word write rdataa=%08h", rdataa);

        // Write a single byte (byte1) at address 0 (modify bits 15:8)
        addra = 4'd0; wdataa = 32'h0000AA00; wea = 4'b0010;
        #10; wea = 4'b0000; #10;
        $display("[tb_Mem] after byte write rdataa=%08h", rdataa);

        $display("[tb_Mem] done");
        $finish;
    end

endmodule
