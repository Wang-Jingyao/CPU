`timescale 1ns / 1ps

module CPU (
    input        clk,
    input        clk_bram,
    input        rst_n,

    // CPU control
    input         cpu_halt,
    input         cpu_step,      // Single-step pulse signal
    input         cpu_reset,

    // Debug: register read
    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data,

    // Debug: instruction memory
    input         inst_dbg_en,    // 1=debug access
    input         inst_wr_en,     // 1=write enable
    input  [31:0] inst_dbg_addr,  // byte address
    input  [31:0] inst_wr_data,   // write data
    output [31:0] inst_rd_data,   // read data (instruction)

    // Debug: data memory
    input         dmem_dbg_en,    // 1=debug access
    input         dmem_wr_en,     // 1=write enable
    input  [31:0] dmem_dbg_addr,  // byte address
    input  [31:0] dmem_wr_data,   // write data
    output [31:0] dmem_rd_data,   // read data

    // Debug: PC
    output [31:0] dbg_pc,

    input [7:0] sw,
    output [7:0] led,
    input [3:0] seg_sel_left,
    output [7:0] seg_data_left,
    input [3:0] seg_sel_right,
    output [7:0] seg_data_right,
    input [63:0] time_value
);

    // ==================== CPU控制状态机 ====================
    
    localparam CPU_RUNNING = 2'b00;
    localparam CPU_HALTED  = 2'b01;
    localparam CPU_STEP    = 2'b10;
    
    reg [1:0] cpu_state;
    reg step_done;  // 单步执行完成标志
    
    // CPU状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || cpu_reset) begin
            cpu_state <= CPU_RUNNING;
            step_done <= 1'b0;
        end else begin
            case (cpu_state)
                CPU_RUNNING: begin
                    if (cpu_halt) begin
                        cpu_state <= CPU_HALTED;
                    end
                end
                
                CPU_HALTED: begin
                    if (!cpu_halt) begin
                        cpu_state <= CPU_RUNNING;
                    end else if (cpu_step && !step_done) begin
                        cpu_state <= CPU_STEP;
                        step_done <= 1'b1;
                    end
                end
                
                CPU_STEP: begin
                    // 单步执行完成后返回暂停状态
                    cpu_state <= CPU_HALTED;
                    step_done <= 1'b0;
                end
                
                default: cpu_state <= CPU_RUNNING;
            endcase
        end
    end
    
    // CPU使能信号：只有在运行或单步状态时才执行
    wire cpu_enable = (cpu_state == CPU_RUNNING) || (cpu_state == CPU_STEP);
    
    // 指令相关
    wire [31:0] instruction;
    wire [6:0] opcode = instruction[6:0];
    
    // 控制信号
    wire ctrl_mem_read, ctrl_mem_write, ctrl_mem_to_reg, ctrl_alu_src, ctrl_reg_write;
    wire [1:0] ctrl_alu_op;
    
    // 解码相关
    wire [4:0] rs1, rs2, rd;
    wire [31:0] imm;
    wire [3:0] alu_ctrl_op;
    
    // 寄存器相关
    wire [31:0] reg_read_data1, reg_read_data2;
    wire [31:0] reg_write_data;
    
    // ALU 相关
    wire [31:0] alu_result;
    
    // 数据内存相关
    wire [31:0] mem_read_data;
    
    // BRAM 相关
    wire [31:0] mem_rdata_a, mem_rdata_b;
    wire [14:0] mem_addr_a, mem_addr_b;
    wire [3:0] mem_we_a, mem_we_b;
    wire [31:0] mem_wdata_a, mem_wdata_b;
    
    // 调试相关
    wire [14:0] dbg_mem_a_addr, dbg_mem_b_addr;
    wire [3:0] dbg_mem_a_we, dbg_mem_b_we;
    wire [31:0] dbg_mem_a_wdata, dbg_mem_b_wdata;
    wire mem_a_access, mem_b_access;
    
    // ==================== Mem 模块（双端口 BRAM）====================
    
    // A口地址多选（指令取指 vs 调试）
    // 可能使用握手会更好
    reg         inst_dbg_en_r;
    reg [3:0]   inst_dbg_we_r;
    reg [14:0]  inst_dbg_addr_r;
    reg [31:0]  inst_dbg_wdata_r;

    always @(posedge clk_bram) begin
        inst_dbg_en_r   <= inst_dbg_en;
        inst_dbg_we_r   <= inst_wr_en ? 4'b1111 : 4'b0000;
        inst_dbg_addr_r <= {1'b1, inst_dbg_addr[15:2]};
        inst_dbg_wdata_r<= inst_wr_data;
    end

    assign mem_a_access = inst_dbg_en_r;
    assign dbg_mem_a_addr = inst_dbg_addr_r;
    assign dbg_mem_a_we = inst_dbg_we_r;
    assign dbg_mem_a_wdata = inst_dbg_wdata_r;
    
    // B口地址多选（数据访问 vs 调试）
    // 可能使用握手会更好
    reg         dmem_dbg_en_r;
    reg [3:0]   dmem_dbg_we_r;
    reg [14:0]  dmem_dbg_addr_r;
    reg [31:0]  dmem_dbg_wdata_r;

    always @(posedge clk_bram) begin
        dmem_dbg_en_r    <= dmem_dbg_en;
        dmem_dbg_we_r    <= dmem_wr_en ? 4'b1111 : 4'b0000;
        dmem_dbg_addr_r  <= dmem_dbg_addr[16:2];
        dmem_dbg_wdata_r <= dmem_wr_data;
    end

    assign mem_b_access = dmem_dbg_en_r;
    assign dbg_mem_b_addr = dmem_dbg_addr_r;
    assign dbg_mem_b_we = dmem_dbg_we_r;
    assign dbg_mem_b_wdata = dmem_dbg_wdata_r;
    
    Mem #(
        .ADDR_WIDTH(15)
    ) mem_inst (
        .clk(clk_bram),
        .wea(mem_a_access ? dbg_mem_a_we : mem_we_a),
        .addra(mem_a_access ? dbg_mem_a_addr : mem_addr_a),
        .wdataa(mem_a_access ? dbg_mem_a_wdata : mem_wdata_a),
        .rdataa(mem_rdata_a),
        .web(mem_b_access ? dbg_mem_b_we : mem_we_b),
        .addrb(mem_b_access ? dbg_mem_b_addr : mem_addr_b),
        .wdatab(mem_b_access ? dbg_mem_b_wdata : mem_wdata_b),
        .rdatab(mem_rdata_b)
    );
    
    // 调试接口输出
    assign inst_rd_data = mem_rdata_a;
    assign dmem_rd_data = mem_rdata_b;

    // ==================== PC 模块 ====================
    
    PC pc_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .branch(branch && cpu_enable),
        .zero(alu_zero),
        .imm(branch_imm),
        .address(pc_address)
    );
    
    assign dbg_pc = pc_address;

    // ==================== 指令内存（IMem）====================
    
    IMem imem_inst (
        .rst_n(rst_n),
        .address(pc_address),
        .instruction(instruction),
        .mem_rdata(mem_rdata_a),
        .mem_addr(mem_addr_a),
        .mem_we(mem_we_a),
        .mem_wdata(mem_wdata_a)
    );

    // ==================== 控制单元（Control）====================
    
    Control control_inst (
        .opcode(opcode),
        .branch(branch),
        .mem_read(ctrl_mem_read),
        .mem_to_reg(ctrl_mem_to_reg),
        .alu_op(ctrl_alu_op),
        .mem_write(ctrl_mem_write),
        .alu_src(ctrl_alu_src),
        .reg_write(ctrl_reg_write)
    );

    // ==================== 指令解码（Decoder）====================
    
    Decoder decoder_inst (
        .alu_op(ctrl_alu_op),
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm),
        .alu_ctrl_op(alu_ctrl_op)
    );
    
    // 分支地址计算：PC + imm（imm已在解码器中处理为偏移量）
    assign branch_imm = imm;

    // ==================== 寄存器文件（Reg）====================
    
    Reg reg_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(ctrl_reg_write && cpu_enable),
        .mem_to_reg(ctrl_mem_to_reg),
        .read_data(mem_read_data),
        .write_data(reg_write_data),
        .read_data1(reg_read_data1),
        .read_data2(reg_read_data2),
        .dbg_reg_addr(dbg_reg_addr),
        .dbg_reg_data(dbg_reg_data)
    );

    // ==================== ALU ====================
    
    ALU alu_inst (
        .alu_op(ctrl_alu_op),
        .alu_ctrl_op(alu_ctrl_op),
        .alu_src(ctrl_alu_src),
        .read_data1(reg_read_data1),
        .read_data2(reg_read_data2),
        .imm(imm),
        .zero(alu_zero),
        .alu_result(alu_result)
    );

    // ==================== 随机数生成器 ====================
    
    wire [31:0] rand_num;
    RandomGen rand_gen (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .rand_num(rand_num)
    );
    
    DMem dmem_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .mem_write(ctrl_mem_write && cpu_enable),
        .type(dmem_access_type),  // lb/lh/lw/lbu/lhu/sb/sh/sw
        .address(alu_result),
        .write_data(reg_read_data2),
        .read_data(mem_read_data),
        .mem_rdata(mem_rdata_b),
        .mem_addr(mem_addr_b),
        .mem_we(mem_we_b),
        .mem_wdata(mem_wdata_b),
        .sw_data(sw),
        .time_value(time_value),
        .kbd_data(8'b0),      // 键盘暂未实现
        .rand_num(rand_num),  // 连接随机数生成器
        .led_data(led),
        .seg_data(seg_data_left),
        .seg_an(seg_sel_left)
    );
    
    // 未使用的输出
    assign seg_data_right = 8'b0;

    // ==================== 最终写回数据选择 ====================
    
    // reg_write_data 在 Reg 模块中已通过 mem_to_reg 选择
    // 此处仅作参考：
    // assign reg_write_data = ctrl_mem_to_reg ? mem_read_data : alu_result;

endmodule

