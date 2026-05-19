`timescale 1ns / 1ps

module tb_DMem;

    // --- 时钟与复位信号 ---
    reg         clk;
    reg         rst_n;

    // --- CPU 核心接口信号 ---
    reg         mem_write;
    reg  [2:0]  type;
    reg  [31:0] address;
    reg  [31:0] write_data;
    wire [31:0] read_data;

    // --- 外部硬件/外设输入信号 ---
    reg  [7:0]  sw_data;
    reg  [63:0] time_value;
    reg  [7:0]  kbd_data;
    reg  [31:0] rand_num;

    // --- 外设输出监控信号 ---
    wire [7:0]  led_data;
    wire [31:0] seg_data;

    // --- UART 调试接口信号 ---
    reg         dmem_dbg_en;
    reg         dmem_wr_en;
    reg  [31:0] dmem_dbg_addr;
    reg  [31:0] dmem_wr_data;
    wire [31:0] dmem_rd_data;

    // --- 访存类型常数定义 ---
    localparam [2:0] TYPE_LB  = 3'b000,
                     TYPE_LH  = 3'b001,
                     TYPE_LW  = 3'b010,
                     TYPE_SB  = 3'b000,
                     TYPE_SH  = 3'b001,
                     TYPE_SW  = 3'b010,
                     TYPE_LBU = 3'b100,
                     TYPE_LHU = 3'b101;

    // --- MMIO 地址常数定义 ---
    localparam [31:0] SW_DATA_ADDR   = 32'h0010_0000,
                     LED_DATA_ADDR  = 32'h0010_0004,
                     SEG_DATA_ADDR  = 32'h0010_0008,
                     TIME_LOW_ADDR  = 32'h0010_000C,
                     TIME_HIGH_ADDR = 32'h0010_0010,
                     KBD_DATA_ADDR  = 32'h0010_0014,
                     RAND_NUM_ADDR  = 32'h0010_0018;

    // --- 实例化实例化被测模块 (UUT) ---
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

    // --- 25MHz 时钟生成 (周期 40ns) ---
    initial begin
        clk = 0;
        forever #20 clk = ~clk;
    end

    // --- 辅助自动化任务：CPU 写操作 ---
    task cpu_write(input [2:0] t_type, input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            #1; // 在上升沿后稍微延时施加激励，模拟组合逻辑延迟
            mem_write  = 1'b1;
            type       = t_type;
            address    = addr;
            write_data = data;
            @(posedge clk); // 等待写入沿采样
            #1;
            mem_write  = 1'b0;
        end
    endtask

    // --- 辅助自动化任务：CPU 读操作与比对 ---
    task cpu_check_read(input [2:0] t_type, input [31:0] addr, input [31:0] expected_data);
        begin
            @(posedge clk);
            #1;
            mem_write  = 1'b0;
            type       = t_type;
            address    = addr;
            // 如果是 BRAM，读数据在下一个 posedge 锁存输出；如果是 MMIO，读数据当时周期组合逻辑直接吐出
            if (addr[31:16] == 16'h0000) begin
                @(posedge clk); 
                #2; // 留出少量仿真延迟供数据稳定
            end else begin
                #5; // MMIO 组合逻辑直接读取延迟
            end
            
            if (read_data === expected_data) begin
                $display("[PASS] CPU Read Addr: 0x%h, Type: %b | Expected: 0x%h, Got: 0x%h", addr, t_type, expected_data, read_data);
            end else begin
                $display("[FAIL] CPU Read Addr: 0x%h, Type: %b | Expected: 0x%h, Got: 0x%h", addr, t_type, expected_data, read_data);
            end
        end
    endtask

    // --- 辅助自动化任务：UART 调试写操作 ---
    // 调试寄存器在 negedge 采样，所以在 negedge 之后施加激励最安全
    task dbg_write(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            #1;
            dmem_dbg_en   = 1'b1;
            dmem_wr_en    = 1'b1;
            dmem_dbg_addr = addr;
            dmem_wr_data  = data;
            @(negedge clk); // 等待第一个 negedge 让 sync 锁存
            @(negedge clk); // 等待第二个 negedge 让内存或 MMIO 真正执行写入
            #1;
            dmem_wr_en    = 1'b0;
        end
    endtask

    // --- 辅助自动化任务：UART 调试读操作与比对 ---
    task dbg_check_read(input [31:0] addr, input [31:0] expected_data);
        begin
            @(negedge clk);
            #1;
            dmem_dbg_en   = 1'b1;
            dmem_wr_en    = 1'b0;
            dmem_dbg_addr = addr;
            @(negedge clk); // 等待 sync 采样
            if (addr[31:16] == 16'h0000) begin
                @(posedge clk); // BRAM 读出需要经历一个 posedge
                #2;
            end else begin
                #2; // MMIO 组合逻辑直接输出
            end

            if (dmem_rd_data === expected_data) begin
                $display("[PASS] DBG Read Addr: 0x%h | Expected: 0x%h, Got: 0x%h", addr, expected_data, dmem_rd_data);
            end else begin
                $display("[FAIL] DBG Read Addr: 0x%h | Expected: 0x%h, Got: 0x%h", addr, expected_data, dmem_rd_data);
            end
        end
    endtask

    // --- 主测试流程 ---
    initial begin
        // 1. 初始化所有输入信号
        rst_n         = 1'b1;
        mem_write     = 1'b0;
        type          = 3'b0;
        address       = 32'b0;
        write_data    = 32'b0;
        sw_data       = 8'b0;
        time_value    = 64'b0;
        kbd_data      = 8'b0;
        rand_num      = 32'b0;
        dmem_dbg_en   = 1'b0;
        dmem_wr_en    = 1'b0;
        dmem_dbg_addr = 32'b0;
        dmem_wr_data  = 32'b0;

        // 2. 系统复位
        #40;
        rst_n = 1'b0;
        #80;
        rst_n = 1'b1;
        #40;

        $display("======= 开始 DMem 模块自动化测试 =======");

        // ==========================================
        // 测试阶段一：BRAM 基本数据区访存测试 (0x0000_xxxx)
        // ==========================================
        $display("\n--- 1. BRAM 字/半字/字节 读写测试 ---");
        
        // 用例 1.1: 完整字写入与读取 (SW / LW)
        cpu_write(TYPE_SW, 32'h0000_0100, 32'hA5A5_5A5A);
        cpu_check_read(TYPE_LW, 32'h0000_0100, 32'hA5A5_5A5A);

        // 用例 1.2: 按字节写入与按字/字节读取 (SB / LB / LBU)
        // 写入 4 个不同字节到同一字地址的不同偏移处
        cpu_write(TYPE_SB, 32'h0000_0200, 32'h0000_0011); // 偏移 0
        cpu_write(TYPE_SB, 32'h0000_0201, 32'h0000_0088); // 偏移 1 (最高位为1)
        cpu_write(TYPE_SB, 32'h0000_0202, 32'h0000_00CC); // 偏移 2
        cpu_write(TYPE_SB, 32'h0000_0203, 32'h0000_007F); // 偏移 3
        
        // 组合成整字读取验证
        cpu_check_read(TYPE_LW, 32'h0000_0200, 32'h7FCC_8811);
        // 测试 LB (符号扩展) 针对 0x88 应该变成 0xFFFF_FF88
        cpu_check_read(TYPE_LB, 32'h0000_0201, 32'hFFFF_FF88);
        // 测试 LBU (零扩展) 针对 0x88 应该变成 0x0000_0088
        cpu_check_read(TYPE_LBU, 32'h0000_0201, 32'h0000_0088);

        // 用例 1.3: 按半字写入与按半字读取 (SH / LH / LHU)
        cpu_write(TYPE_SH, 32'h0000_0300, 32'h0000_1234); // 低半字
        cpu_write(TYPE_SH, 32'h0000_0302, 32'h0000_89AB); // 高半字
        cpu_check_read(TYPE_LW, 32'h0000_0300, 32'h89AB_1234);
        // 测试 LH (符号扩展) 针对 0x89AB
        cpu_check_read(TYPE_LH, 32'h0000_0302, 32'hFFFF_89AB);
        // 测试 LHU (零扩展) 针对 0x89AB
        cpu_check_read(TYPE_LHU, 32'h0000_0302, 32'h0000_89AB);


        // ==========================================
        // 测试阶段二：MMIO 只读外设测试
        // ==========================================
        $display("\n--- 2. MMIO 只读外设寄存器测试 ---");
        
        // 模拟外部硬件向模块输入状态
        sw_data    = 8'h3C;
        time_value = 64'h11223344_55667788;
        kbd_data   = 8'hFE;
        rand_num   = 32'h9876_5432;
        #10;

        cpu_check_read(TYPE_LW, SW_DATA_ADDR,   32'h0000_003C);
        cpu_check_read(TYPE_LW, TIME_LOW_ADDR,  32'h55667788);
        cpu_check_read(TYPE_LW, TIME_HIGH_ADDR, 32'h11223344);
        cpu_check_read(TYPE_LW, KBD_DATA_ADDR,  32'h0000_00FE);
        cpu_check_read(TYPE_LW, RAND_NUM_ADDR,  32'h9876_5432);


        // ==========================================
        // 测试阶段三：MMIO 可写外设测试 (LED / SEG)
        // ==========================================
        $display("\n--- 3. MMIO 可写外设寄存器测试 ---");

        // 用例 3.1: 写 LED 寄存器
        cpu_write(TYPE_SW, LED_DATA_ADDR, 32'h0000_00A9);
        #10; // 等待负沿触发更新
        if (led_data === 8'hA9) 
            $display("[PASS] LED_DATA Output hardware register match: 0x%h", led_data);
        else 
            $display("[FAIL] LED_DATA Output hardware register mismatch: 0x%h", led_data);

        // 用例 3.2: 字写 SEG 数码管寄存器 (SW)
        cpu_write(TYPE_SW, SEG_DATA_ADDR, 32'h1234_5678);
        #10;
        if (seg_data === 32'h1234_5678) 
            $display("[PASS] SEG_DATA Word Write match: 0x%h", seg_data);
        else 
            $display("[FAIL] SEG_DATA Word Write mismatch: 0x%h", seg_data);

        // 用例 3.3: 字节写 SEG 数码管寄存器指定字节 (SB)
        cpu_write(TYPE_SB, SEG_DATA_ADDR + 32'd2, 32'h0000_00AA); // 修改分段 [23:16]
        #10;
        if (seg_data === 32'h12AA_5678) 
            $display("[PASS] SEG_DATA Byte 2 Write match: 0x%h", seg_data);
        else 
            $display("[FAIL] SEG_DATA Byte 2 Write mismatch: 0x%h", seg_data);

        // 用例 3.4: 半字写 SEG 寄存器 
        // 提示：根据你现有的代码实现，高半字写入依靠的是把地址故意偏移到末尾 2'b01 触发 else
        cpu_write(TYPE_SH, SEG_DATA_ADDR + 32'd1, 32'h0000_BBBB); 
        #10;
        if (seg_data === 32'hBBBB_5678) 
            $display("[PASS] SEG_DATA Halfword High Write match: 0x%h", seg_data);
        else 
            $display("[FAIL] SEG_DATA Halfword High Write mismatch: 0x%h", seg_data);


        // ==========================================
        // 测试阶段四：UART 调试接口（Debug Mode）测试
        // ==========================================
        $display("\n--- 4. UART 调试总线覆盖测试 ---");

        // 用例 4.1: 通过调试总线向 BRAM 写入数据并读回
        dbg_write(32'h0000_0100, 32'hDEAD_BEEF);
        dbg_check_read(32'h0000_0100, 32'hDEAD_BEEF);

        // 用例 4.2: 通过调试总线改写 MMIO 寄存器（例如 LED）
        dbg_write(LED_DATA_ADDR, 32'h0000_0055);
        #10;
        if (led_data === 8'h55) begin
            $stop; // 所有的用例执行完毕且成功，仿真挂起或正常结束
            $display("[PASS] DBG Write to MMIO LED success. Output: 0x%h", led_data);
        end
        else begin
            $display("[FAIL] DBG Write to MMIO LED failed. Output: 0x%h", led_data);
        end

        // 退出调试模式，恢复正常 CPU 状态
        @(negedge clk);
        dmem_dbg_en = 1'b0;
        
        $display("\n======= DMem 模块所有用例测试运行完毕 =======");
        $finish;
    end

endmodule