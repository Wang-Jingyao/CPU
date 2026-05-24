`timescale 1ns / 1ps

module CPU (
    input        clk,
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
    output [3:0] seg_sel_left,
    output [7:0] seg_data_left,
    output [3:0] seg_sel_right,
    output [7:0] seg_data_right,
    input [63:0] time_value,
    input        ps2_clk,
    input        ps2_data
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
            cpu_state <= CPU_HALTED;
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
                
                default: cpu_state <= CPU_HALTED;
            endcase
        end
    end
    
    // CPU使能信号：只有在运行或单步状态时才执行
    wire cpu_enable = (cpu_state == CPU_RUNNING) || (cpu_state == CPU_STEP);
    
    // 指令相关
    wire [31:0] instruction;
    wire [6:0] opcode = instruction[6:0];
    wire [31:0] pc_address;
    wire [31:0] branch_imm;
    wire branch;
    wire alu_zero;
    
    // 控制信号
    wire ctrl_mem_read, ctrl_mem_write, ctrl_mem_to_reg, ctrl_alu_src, ctrl_reg_write, jal_enable, jalr_enable;
    wire [1:0] ctrl_alu_op;
    
    // 解码相关
    wire [4:0] rs1, rs2, rd;
    wire [31:0] imm;
    wire [3:0] alu_ctrl_op;
    wire [2:0] dmem_access_type;
    
    // 寄存器相关
    wire [31:0] reg_read_data1, reg_read_data2;
    
    // ALU 相关
    wire [31:0] alu_result;
    
    // 数据内存相关
    wire [31:0] mem_read_data;

    // jal相关
    wire [31:0] jal_address;
    wire [31:0] write_reg;
    
    // ==================== PC 模块 ====================
    
    PC pc_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .en(cpu_enable),
        .jal_en(jal_enable),
        .jalr_en(jalr_enable),
        .rs1(reg_read_data1),
        .branch(branch),
        .zero(alu_zero),
        .imm(branch_imm),
        .rd_add(jal_address),
        .address(pc_address)
    );
    
    assign dbg_pc = pc_address;

    // ==================== 指令内存（IMem）====================
    IMem imem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .address(pc_address),
        .instruction(instruction),
        .inst_dbg_en(inst_dbg_en),
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data)
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
        .reg_write(ctrl_reg_write),
        .jal_en(jal_enable),
        .jalr_en(jalr_enable)
    );

    // ==================== 指令解码（Decoder）====================
    
    Decoder decoder_inst (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm),
        .alu_ctrl_op(alu_ctrl_op)
    );
    
    // 分支地址计算：PC + imm（imm已在解码器中处理为偏移量）
    assign branch_imm = imm;
    assign dmem_access_type = instruction[14:12];

    // ==================== 寄存器文件（Reg）====================
    
    assign write_reg = (jal_enable || jalr_enable) ? jal_address : alu_result;

    Reg reg_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(ctrl_reg_write && cpu_enable),
        .mem_to_reg(ctrl_mem_to_reg),
        .read_data(mem_read_data),
        .write_data(write_reg),
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
    
    // ==================== 键盘输入 ====================
    wire [7:0] kbd_data;
    Keyboard kbd_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .kbd_data(kbd_data)
    );
    
    wire [31:0] seg_data_32;

    DMem dmem_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .mem_write(ctrl_mem_write && cpu_enable),
        .type(dmem_access_type),  // lb/lh/lw/lbu/lhu/sb/sh/sw
        .address(alu_result),
        .write_data(reg_read_data2),
        .read_data(mem_read_data),

        .dmem_dbg_en(dmem_dbg_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data),

        .sw_data(sw),
        .time_value(time_value),
        .kbd_data(kbd_data),
        .rand_num(rand_num),
        .led_data(led),
        .seg_data(seg_data_32)
    );

    Seg seg_inst (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset),
        .seg_data(seg_data_32),
        .seg_data_left(seg_data_left),
        .seg_sel_left(seg_sel_left),
        .seg_data_right(seg_data_right),
        .seg_sel_right(seg_sel_right)
    );

    assign dmem_rd_data = mem_read_data;

endmodule

