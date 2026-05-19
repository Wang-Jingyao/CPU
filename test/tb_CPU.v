`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/19 
// Design Name: 
// Module Name: tb_CPU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: CPU top-level 仿真测试平台
// 
// 该仿真文件通过调试写接口向 IMem 装载简单程序，并观察寄存器结果。
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_CPU;

    // 时钟与复位
    reg         clk;
    reg         rst_n;

    // CPU 控制信号
    reg         cpu_halt;
    reg         cpu_step;
    reg         cpu_reset;

    // 调试寄存器读
    reg  [4:0]  dbg_reg_addr;
    wire [31:0] dbg_reg_data;

    // 指令存储调试访问
    reg         inst_dbg_en;
    reg         inst_wr_en;
    reg  [31:0] inst_dbg_addr;
    reg  [31:0] inst_wr_data;
    wire [31:0] inst_rd_data;

    // 数据存储调试访问
    reg         dmem_dbg_en;
    reg         dmem_wr_en;
    reg  [31:0] dmem_dbg_addr;
    reg  [31:0] dmem_wr_data;
    wire [31:0] dmem_rd_data;

    // 外设/IO
    reg  [7:0]  sw;
    wire [7:0]  led;
    wire [3:0]  seg_sel_left;
    wire [7:0]  seg_data_left;
    wire [3:0]  seg_sel_right;
    wire [7:0]  seg_data_right;
    reg  [63:0] time_value;

    // 实例化 DUT
    CPU uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_halt(cpu_halt),
        .cpu_step(cpu_step),
        .cpu_reset(cpu_reset),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data),
        .inst_dbg_en(inst_dbg_en),
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data),
        .dmem_dbg_en(dmem_dbg_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data),
        .dbg_pc(),
        .sw(sw),
        .led(led),
        .seg_sel_left(seg_sel_left),
        .seg_data_left(seg_data_left),
        .seg_sel_right(seg_sel_right),
        .seg_data_right(seg_data_right),
        .time_value(time_value)
    );

    // 100MHz 时钟生成
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 指令存储写任务
    task write_inst(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            #1;
            inst_dbg_en   = 1'b1;
            inst_wr_en    = 1'b1;
            inst_dbg_addr = addr;
            inst_wr_data = data;
            @(posedge clk);
            #1;
            inst_dbg_en   = 1'b0;
            inst_wr_en    = 1'b0;
            inst_dbg_addr = 32'b0;
            inst_wr_data = 32'b0;
        end
    endtask

    // 调试寄存器读取任务
    task check_reg(input [4:0] reg_addr, input [31:0] expected_value, input [256*8:1] desc);
        begin
            dbg_reg_addr = reg_addr;
            #1;
            if (dbg_reg_data === expected_value) begin
                $display("[PASS] %s: x%0d = 0x%08h", desc, reg_addr, dbg_reg_data);
            end else begin
                $display("[FAIL] %s: x%0d expected=0x%08h got=0x%08h", desc, reg_addr, expected_value, dbg_reg_data);
            end
        end
    endtask

    initial begin
        // 初始化输入信号
        rst_n         = 1'b1;
        cpu_halt      = 1'b0;
        cpu_step      = 1'b0;
        cpu_reset     = 1'b0;
        dbg_reg_addr  = 5'b0;
        inst_dbg_en   = 1'b0;
        inst_wr_en    = 1'b0;
        inst_dbg_addr = 32'b0;
        inst_wr_data  = 32'b0;
        dmem_dbg_en   = 1'b0;
        dmem_wr_en    = 1'b0;
        dmem_dbg_addr = 32'b0;
        dmem_wr_data  = 32'b0;
        sw            = 8'b0;
        time_value    = 64'b0;

        // 复位
        #20;
        rst_n = 1'b0;
        #40;
        rst_n = 1'b1;
        #20;

        $display("===== CPU 仿真开始 =====");

        // 向 IMem 写入简单程序：
        //   addi x1, x0, 5
        //   addi x2, x0, 10
        //   add  x5, x1, x2
        //   sw   x5, 0(x0)
        //   lw   x4, 0(x0)
        //   nop
        write_inst(32'h0000_0000, 32'h0050_0093);
        write_inst(32'h0000_0004, 32'h00A0_0113);
        write_inst(32'h0000_0008, 32'h0020_82B3);
        write_inst(32'h0000_000C, 32'h0050_2023);
        write_inst(32'h0000_0010, 32'h0000_2283);
        write_inst(32'h0000_0014, 32'h0000_0013);

        // 等待程序启动并完成执行
        repeat (40) @(posedge clk);
        #1;

        // 读取寄存器 x4 结果，期望为 15
        check_reg(5'd4, 32'd15, "检查 x4 是否等于 15");

        $display("===== CPU 仿真结束 =====");
        $finish;
    end

endmodule
