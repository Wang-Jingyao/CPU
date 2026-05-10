`timescale 1ns / 1ps

module TopDebug (
    input         clk,        // 100MHz system clock (EGO1：P17)
    input         rst,        // Active-low reset button (EGO1：P15)
    // UART
    input         uart_rxd,   // PC to FPGA (EGO1：N5)
    output        uart_txd    // FPGA to PC (EGO1：T4)
    // Other physical IO such as switches/LEDs (same as CPU Top)
);

// ================================
// UART RX / TX
// ================================
wire [7:0]  rx_data;
wire        rx_valid;
wire [7:0]  tx_data;
wire        tx_start;
wire        tx_busy;

UartRx #(
    .CLK_FREQ(100_000_000),
    .BAUD(115200)
) uUartRx (
    .clk     (clk),
    .rst_n   (rst),
    .rx_pin  (uart_rxd),
    .rx_data (rx_data),
    .rx_valid(rx_valid)
);

UartTx #(
    .CLK_FREQ(100_000_000),
    .BAUD(115200)
) uUartTx (
    .clk     (clk),
    .rst_n   (rst),
    .tx_data (tx_data),
    .tx_start(tx_start),
    .tx_busy (tx_busy),
    .tx_pin  (uart_txd)
);

// ================================
// Debug Controller
// ================================
wire        cpu_halt;
wire        cpu_step;
wire        cpu_reset;
wire [4:0]  dbg_reg_addr;
wire [31:0] dbg_reg_data;
wire [31:0] dbg_pc;
wire        inst_dbg_en;
wire        inst_wr_en;
wire [31:0] inst_dbg_addr;
wire [31:0] inst_wr_data;
wire [31:0] dbg_inst_data;
wire        dmem_dbg_en;
wire        dmem_wr_en;
wire [31:0] dmem_dbg_addr;
wire [31:0] dmem_wr_data;
wire [31:0] dmem_rd_data;

DebugController uDebugCtrl (
    .clk          (clk),
    .rst_n        (rst),
    // UART
    .rx_data      (rx_data),
    .rx_valid     (rx_valid),
    .tx_data      (tx_data),
    .tx_start     (tx_start),
    .tx_busy      (tx_busy),
    // CPU control
    .cpu_halt     (cpu_halt),
    .cpu_step     (cpu_step),
    .cpu_reset    (cpu_reset),
    // Register read
    .dbg_reg_addr (dbg_reg_addr),
    .dbg_reg_data (dbg_reg_data),
    // Instruction memory debug
    .inst_dbg_en  (inst_dbg_en),
    .inst_wr_en   (inst_wr_en),
    .inst_dbg_addr(inst_dbg_addr),
    .inst_wr_data (inst_wr_data),
    .inst_rd_data (dbg_inst_data),
    // Data memory debug
    .dmem_dbg_en  (dmem_dbg_en),
    .dmem_wr_en   (dmem_wr_en),
    .dmem_dbg_addr(dmem_dbg_addr),
    .dmem_wr_data (dmem_wr_data),
    .dmem_rd_data (dmem_rd_data),
    // PC
    .dbg_pc       (dbg_pc)
);

// ================================
// CPU instance
// ================================


// ================================
// Other logic
// ================================


endmodule