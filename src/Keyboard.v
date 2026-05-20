/*******************************************************************************
 * 名称：Keyboard
 * 描述：PS/2 键盘接收模块
 * 说明：本模块仅接收并输出键盘按下（Make code）信号；按键释放（Break code）
 *       不会被作为有效按键传出，释放时输出为 0x00。
 *
 * 键盘对应数值说明：
 * 数字 0-9: 0x30 - 0x39 (ASCII)
 * 字母 A-Z: 0x41 - 0x5A (大写 ASCII)
 * Enter:    0x0D
 * 方向键上: 0x11
 * 方向键下: 0x12
 * 方向键左: 0x13
 * 方向键右: 0x14
 * 减号 - : 0x2D
 * 无按键:   0x00
 ******************************************************************************/
module Keyboard(
    input clk,
    input rst_n,
    input ps2_clk,
    input ps2_data,
    output reg [7:0] kbd_data
);

    reg [2:0] ps2_clk_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync <= 3'b111;
        end else begin
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
        end
    end
    wire neg_edge = (ps2_clk_sync[2:1] == 2'b10);

    reg [3:0] count;
    reg [9:0] shift_reg;
    reg [7:0] rx_data;
    reg rx_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            shift_reg <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            if (neg_edge) begin
                if (count == 4'd10) begin
                    count <= 0;
                    if (shift_reg[0] == 0 && ps2_data == 1) begin
                        rx_data <= shift_reg[8:1];
                        rx_valid <= 1;
                    end
                end else begin
                    shift_reg <= {ps2_data, shift_reg[9:1]};
                    count <= count + 1;
                end
            end
        end
    end

    reg is_e0;
    reg is_f0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kbd_data <= 8'h00;
            is_e0 <= 0;
            is_f0 <= 0;
        end else if (rx_valid) begin
            if (rx_data == 8'hE0) begin
                is_e0 <= 1;
            end else if (rx_data == 8'hF0) begin
                is_f0 <= 1;
            end else begin
                if (is_f0) begin
                    // Break code
                    kbd_data <= 8'h00;
                end else begin
                    // Make code
                    if (is_e0) begin
                        case (rx_data)
                            8'h75: kbd_data <= 8'h11; // Up
                            8'h72: kbd_data <= 8'h12; // Down
                            8'h6B: kbd_data <= 8'h13; // Left
                            8'h74: kbd_data <= 8'h14; // Right
                        endcase
                    end else begin
                        case (rx_data)
                            8'h16: kbd_data <= 8'h31; // 1
                            8'h1E: kbd_data <= 8'h32; // 2
                            8'h26: kbd_data <= 8'h33; // 3
                            8'h25: kbd_data <= 8'h34; // 4
                            8'h2E: kbd_data <= 8'h35; // 5
                            8'h36: kbd_data <= 8'h36; // 6
                            8'h3D: kbd_data <= 8'h37; // 7
                            8'h3E: kbd_data <= 8'h38; // 8
                            8'h46: kbd_data <= 8'h39; // 9
                            8'h45: kbd_data <= 8'h30; // 0
                            8'h4E: kbd_data <= 8'h2D; // - (minus)
                            
                            8'h1C: kbd_data <= 8'h41; // A
                            8'h32: kbd_data <= 8'h42; // B
                            8'h21: kbd_data <= 8'h43; // C
                            8'h23: kbd_data <= 8'h44; // D
                            8'h24: kbd_data <= 8'h45; // E
                            8'h2B: kbd_data <= 8'h46; // F
                            8'h34: kbd_data <= 8'h47; // G
                            8'h33: kbd_data <= 8'h48; // H
                            8'h43: kbd_data <= 8'h49; // I
                            8'h3B: kbd_data <= 8'h4A; // J
                            8'h42: kbd_data <= 8'h4B; // K
                            8'h4B: kbd_data <= 8'h4C; // L
                            8'h3A: kbd_data <= 8'h4D; // M
                            8'h31: kbd_data <= 8'h4E; // N
                            8'h44: kbd_data <= 8'h4F; // O
                            8'h4D: kbd_data <= 8'h50; // P
                            8'h15: kbd_data <= 8'h51; // Q
                            8'h2D: kbd_data <= 8'h52; // R
                            8'h1B: kbd_data <= 8'h53; // S
                            8'h2C: kbd_data <= 8'h54; // T
                            8'h3C: kbd_data <= 8'h55; // U
                            8'h2A: kbd_data <= 8'h56; // V
                            8'h1D: kbd_data <= 8'h57; // W
                            8'h22: kbd_data <= 8'h58; // X
                            8'h35: kbd_data <= 8'h59; // Y
                            8'h1A: kbd_data <= 8'h5A; // Z
                            
                            8'h5A: kbd_data <= 8'h0D; // Enter
                            default: kbd_data <= 8'h00;
                        endcase
                    end
                end
                is_e0 <= 0;
                is_f0 <= 0;
            end
        end
    end
endmodule
