`timescale 1ns / 1ps

module tb_Reg;

    // 信号声明
    reg clk;
    reg rst_n;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;
    reg reg_write;
    reg mem_to_reg;
    reg [31:0] read_data;
    reg [31:0] write_data;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    
    // 调试端口
    reg [4:0] dbg_reg_addr;
    wire [31:0] dbg_reg_data;
    
    // 实例化被测试模块
    Reg uut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(reg_write),
        .mem_to_reg(mem_to_reg),
        .read_data(read_data),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data)
    );
    
    // 时钟生成：周期 10ns
    always #5 clk = ~clk;
    
    // 测试序列
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        reg_write = 0;
        mem_to_reg = 0;
        read_data = 0;
        write_data = 0;
        dbg_reg_addr = 0;
        
        // 复位释放
        #20 rst_n = 1;
        #10;
        
        // 测试1：写寄存器 x1 = 0x12345678
        rd = 5'd1;
        write_data = 32'h12345678;
        reg_write = 1;
        mem_to_reg = 0;
        #10;
        
        // 测试2：写寄存器 x2 = 0xAABBCCDD
        rd = 5'd2;
        write_data = 32'hAABBCCDD;
        reg_write = 1;
        #10;
        
        // 测试3：读寄存器 x1 和 x2
        reg_write = 0;
        rs1 = 5'd1;
        rs2 = 5'd2;
        #10;
        
        // 测试4：写 x0（应被忽略）
        rd = 5'd0;
        write_data = 32'hFFFFFFFF;
        reg_write = 1;
        #10;
        
        // 测试5：从内存读取数据写入 x4（mem_to_reg = 1）
        rd = 5'd4;
        read_data = 32'hDEADBEEF;
        mem_to_reg = 1;
        reg_write = 1;
        #10;
        
        // 测试6：读 x4 验证内存写入
        reg_write = 0;
        rs1 = 5'd4;
        #10;
        
        // 测试7：测试 x3 硬连线值
        rs1 = 5'd3;
        #10;
        
        // 测试8：测试调试端口读 x1
        dbg_reg_addr = 5'd1;
        #10;
        
        // 测试9：测试调试端口读 x3（应返回 0x00004000）
        dbg_reg_addr = 5'd3;
        #10;
        
        // 测试10：测试调试端口读 x0（应返回 0）
        dbg_reg_addr = 5'd0;
        #10;
        
        // 测试11：写寄存器 x5，然后覆盖
        rd = 5'd5;
        write_data = 32'h11111111;
        reg_write = 1;
        mem_to_reg = 0;
        #10;
        
        rd = 5'd5;
        write_data = 32'h22222222;
        reg_write = 1;
        #10;
        
        // 读 x5 验证覆盖
        reg_write = 0;
        rs1 = 5'd5;
        #10;
        
        // 测试12：复位测试
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        
        // 验证复位后寄存器应为 0
        rs1 = 5'd5;
        #10;
        
        $finish;
    end
    
    // 打印结果
    initial begin
        $monitor("Time=%0t | rst=%b | wr=%b | rd=%d | wdata=%h | rs1=%d | rs2=%d | rdata1=%h | rdata2=%h | dbg_addr=%d | dbg_data=%h",
                 $time, rst_n, reg_write, rd, reg_write ? (mem_to_reg ? read_data : write_data) : 32'hZ,
                 rs1, rs2, read_data1, read_data2, dbg_reg_addr, dbg_reg_data);
    end
    
    // 波形保存
    initial begin
        $dumpfile("tb_Reg.vcd");
        $dumpvars(0, Reg_tb);
    end

endmodule