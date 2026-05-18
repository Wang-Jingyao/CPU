`timescale 1ns / 1ps

module tb_Timer();

    reg clk;
    reg rst_n;
    wire clk_50m;
    wire clk_25m;
    wire clk_1m;
    wire [63:0] time_value;
    
    // 定义仿真模式
    `define SIMULATION
    
    // 实例化
    ClockTimer uut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_50m(clk_50m),
        .clk_25m(clk_25m),
        .clk_1m(clk_1m),
        .time_value(time_value)
    );
    
    // 100MHz 时钟 (周期 10ns)
    always #5 clk = ~clk;
    
    // 监视器
    initial begin
        $display("\n==========================================");
        $display("    Clock Timer Simulation Started");
        $display("    Input: 100MHz clock");
        $display("==========================================\n");
        
        // 初始化
        clk = 0;
        rst_n = 0;
        
        // 复位
        #20 rst_n = 1;
        $display("[Time %0t] Reset released", $time);
        
        // 观察时钟输出
        #1000;
        
        // 显示测量结果
        $display("\n==========================================");
        $display("    Frequency Measurements (Approx):");
        $display("==========================================");
        
        $finish;
    end
    
    // 实时显示 time_value
    always @(posedge clk_1m) begin
        if (time_value % 10 == 0 && time_value != 0) begin
            $display("[Time %0t] time_value = %d (seconds: %0.2f)", 
                     $time, time_value, time_value / 1000000.0);
        end
    end
    
    // 测量时钟频率
    integer clk_50m_count = 0;
    integer clk_25m_count = 0;
    integer clk_1m_count = 0;
    real start_time;
    
    initial begin
        start_time = $time;
        #100000;  // 测量 100us
        
        $display("\nClock Cycle Counts over 100us:");
        $display("  clk_50m cycles: %0d (expected ~5000)", clk_50m_count);
        $display("  clk_25m cycles: %0d (expected ~2500)", clk_25m_count);
        $display("  clk_1m cycles:  %0d (expected ~100)", clk_1m_count);
        
        $display("\nFinal time_value = %d (should be ~100)", time_value);
        
        #1000;
        $finish;
    end
    
    always @(posedge clk_50m) clk_50m_count = clk_50m_count + 1;
    always @(posedge clk_25m) clk_25m_count = clk_25m_count + 1;
    always @(posedge clk_1m) clk_1m_count = clk_1m_count + 1;
    
    // 波形输出
    initial begin
        $dumpfile("tb_Timer.vcd");
        $dumpvars(0, tb_Timer);
    end

endmodule