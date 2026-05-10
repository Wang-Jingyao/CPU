# 时钟信号 100MHz
set_property PACKAGE_PIN P17   [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]

# 复位按键（低有效）
set_property PACKAGE_PIN P15  [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]

# UART 接口
set_property PACKAGE_PIN N5 [get_ports {uart_rxd}]
set_property PACKAGE_PIN T4 [get_ports {uart_txd}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rxd uart_txd}]

# 拨码开关 sw[7:0]
set_property PACKAGE_PIN P5 [get_ports {sw[7]}]
set_property PACKAGE_PIN P4 [get_ports {sw[6]}]
set_property PACKAGE_PIN P3 [get_ports {sw[5]}]
set_property PACKAGE_PIN P2 [get_ports {sw[4]}]
set_property PACKAGE_PIN R2 [get_ports {sw[3]}]
set_property PACKAGE_PIN M4 [get_ports {sw[2]}]
set_property PACKAGE_PIN N4 [get_ports {sw[1]}]
set_property PACKAGE_PIN R1 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

# LED 指示灯 led[7:0]
set_property PACKAGE_PIN F6 [get_ports {led[7]}] ;# LED7
set_property PACKAGE_PIN G4 [get_ports {led[6]}] ;# LED6
set_property PACKAGE_PIN G3 [get_ports {led[5]}] ;# LED5
set_property PACKAGE_PIN J4 [get_ports {led[4]}] ;# LED4
set_property PACKAGE_PIN H4 [get_ports {led[3]}] ;# LED3
set_property PACKAGE_PIN J3 [get_ports {led[2]}] ;# LED2
set_property PACKAGE_PIN J2 [get_ports {led[1]}] ;# LED1
set_property PACKAGE_PIN K2 [get_ports {led[0]}] ;# LED0
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# halt LED
set_property PACKAGE_PIN K3 [get_ports {halt_led}]
set_property IOSTANDARD LVCMOS33 [get_ports {halt_led}]

# 七段数码管（四位数显示数字）
## 位选 seg_sel_right[3:0]
set_property PACKAGE_PIN G1 [get_ports {seg_sel_right[3]}] ;# AN3
set_property PACKAGE_PIN F1 [get_ports {seg_sel_right[2]}] ;# AN2
set_property PACKAGE_PIN E1 [get_ports {seg_sel_right[1]}] ;# AN1
set_property PACKAGE_PIN G6 [get_ports {seg_sel_right[0]}] ;# AN0
set_property IOSTANDARD LVCMOS33 [get_ports {seg_sel_right[*]}]
## 段选 seg_data_right[7:0]
set_property PACKAGE_PIN D4 [get_ports {seg_data_right[7]}]
set_property PACKAGE_PIN E3 [get_ports {seg_data_right[6]}]
set_property PACKAGE_PIN D3 [get_ports {seg_data_right[5]}]
set_property PACKAGE_PIN F4 [get_ports {seg_data_right[4]}]
set_property PACKAGE_PIN F3 [get_ports {seg_data_right[3]}]
set_property PACKAGE_PIN E2 [get_ports {seg_data_right[2]}]
set_property PACKAGE_PIN D2 [get_ports {seg_data_right[1]}]
set_property PACKAGE_PIN H2 [get_ports {seg_data_right[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_data_right[*]}]

# 单个数码管（显示操作状态）
## 位选 seg_sel_left
set_property PACKAGE_PIN G2 [get_ports {seg_sel_left[3]}] ;# AN3
set_property PACKAGE_PIN C2 [get_ports {seg_sel_left[2]}] ;# AN2
set_property PACKAGE_PIN C1 [get_ports {seg_sel_left[1]}] ;# AN1
set_property PACKAGE_PIN H1 [get_ports {seg_sel_left[0]}] ;# AN0
set_property IOSTANDARD LVCMOS33 [get_ports {seg_sel_left[*]}]
## 段选 seg_data_left[7:0]
set_property PACKAGE_PIN D5 [get_ports {seg_data_left[0]}]
set_property PACKAGE_PIN B2 [get_ports {seg_data_left[1]}]
set_property PACKAGE_PIN B3 [get_ports {seg_data_left[2]}]
set_property PACKAGE_PIN A1 [get_ports {seg_data_left[3]}]
set_property PACKAGE_PIN B1 [get_ports {seg_data_left[4]}]
set_property PACKAGE_PIN A3 [get_ports {seg_data_left[5]}]
set_property PACKAGE_PIN A4 [get_ports {seg_data_left[6]}]
set_property PACKAGE_PIN B4 [get_ports {seg_data_left[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_data_left[*]}]