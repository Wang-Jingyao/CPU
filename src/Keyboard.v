/*******************************************************************************
 * 名称：Keyboard
 * 描述：PS/2 键盘接收模块 (带物理层滤波、奇偶校验与内部 FIFO)
 * 说明：本模块对 PS/2 时钟和数据进行毛刺滤除与奇偶校验，只提取按键按下
 * (Make code) 对应的有效字符；按键释放 (Break code) 和扩展码只作为
 * 状态标志，不写入 FIFO。内部集成 16 字节 FIFO 处理读写并发。
 ******************************************************************************/
module Keyboard(
    input  wire       clk,        // 系统时钟
    input  wire       rst_n,      // 低电平复位
    input  wire       ps2_clk,    // 原始 PS/2 时钟信号
    input  wire       ps2_data,   // 原始 PS/2 数据信号
    input  wire       re,         // CPU 读请求 (Read Enable)
    output reg  [7:0] kbd_data    // 读出的 ASCII 数据
);

    localparam FIFO_DEPTH = 16;

    // ==========================================
    // 物理层：滤波与下降沿检测寄存器
    // ==========================================
    reg [7:0] ps2_clk_filter;
    reg [7:0] ps2_data_filter;
    reg       ps2_clk_stable;
    reg       ps2_data_stable;
    reg       ps2_clk_stable_d1;
    reg       ps2_clk_stable_d2;

    // 提取系统时钟下的 PS/2 下降沿脉冲
    wire neg_edge = (ps2_clk_stable_d2 == 1'b1) && (ps2_clk_stable_d1 == 1'b0);

    // ==========================================
    // 协议层：解码状态机寄存器
    // ==========================================
    reg [3:0]  bit_count;
    reg [10:0] frame_bits;
    reg        is_e0;
    reg        is_f0;

    // ==========================================
    // 缓冲层：FIFO 控制信号与内存
    // ==========================================
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [3:0] head;
    reg [3:0] tail;
    reg [4:0] fifo_count;

    wire fifo_not_empty = (fifo_count != 5'd0);
    wire fifo_not_full  = (fifo_count != FIFO_DEPTH);
    wire [10:0] cur_frame = {ps2_data_stable, frame_bits[10:1]};

    reg       push_req;      // 解码成功，请求压入 FIFO
    reg [7:0] push_data;     // 准备压入 FIFO 的字符

    // ==========================================
    // 时钟与数据的毛刺滤除
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_filter    <= 8'hFF;
            ps2_data_filter   <= 8'hFF;
            ps2_clk_stable    <= 1'b1;
            ps2_data_stable   <= 1'b1;
            ps2_clk_stable_d1 <= 1'b1;
            ps2_clk_stable_d2 <= 1'b1;
        end else begin
            // 移位滤波：只有连续 8 个周期为 0 或 1 才改变稳定状态
            ps2_clk_filter  <= {ps2_clk_filter[6:0], ps2_clk};
            ps2_data_filter <= {ps2_data_filter[6:0], ps2_data};

            if (ps2_clk_filter == 8'hFF) begin
                ps2_clk_stable <= 1'b1;
            end else if (ps2_clk_filter == 8'h00) begin
                ps2_clk_stable <= 1'b0;
            end

            if (ps2_data_filter == 8'hFF) begin
                ps2_data_stable <= 1'b1;
            end else if (ps2_data_filter == 8'h00) begin
                ps2_data_stable <= 1'b0;
            end

            // 打两拍用于检测下降沿
            ps2_clk_stable_d1 <= ps2_clk_stable;
            ps2_clk_stable_d2 <= ps2_clk_stable_d1;
        end
    end

    // ==========================================
    // PS/2 11-bit 帧解析与键码映射
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count  <= 4'd0;
            frame_bits <= 11'd0;
            is_e0      <= 1'b0;
            is_f0      <= 1'b0;
            push_req   <= 1'b0;
            push_data  <= 8'h00;
        end else begin
            // 默认清除写请求脉冲
            push_req <= 1'b0; 

            if (neg_edge) begin
                // 移位：最新到达的 bit 放最高位，最先到达的 bit 被挤到最低位
                frame_bits <= {ps2_data_stable, frame_bits[10:1]};

                if (bit_count == 4'd10) begin
                    bit_count <= 4'd0; // 接收完 11 bit，重置计数器

                    // 组合当前的 11 位完整数据
                    // [10]: 停止位, [9]: 奇校验位, [8:1]: 数据位, [0]: 起始位
                    begin : decode_block    
                        // 校验：起始位0，停止位1，奇校验通过
                        if ((cur_frame[0] == 1'b0) && (cur_frame[10] == 1'b1) && 
                            (^(cur_frame[8:1]) == ~cur_frame[9])) begin
                            
                            if (cur_frame[8:1] == 8'hE0) begin
                                is_e0 <= 1'b1;
                                is_f0 <= 1'b0;
                            end else if (cur_frame[8:1] == 8'hF0) begin
                                is_f0 <= 1'b1;
                            end else begin
                                // 如果既不是扩展码前缀，也不是松开码前缀，那就是有效的 Make Code
                                if (!is_e0 && !is_f0) begin
                                    push_req <= 1'b1; // 请求写入 FIFO
                                    case (cur_frame[8:1])
                                        8'h16: push_data <= 8'h31; // '1'
                                        8'h1E: push_data <= 8'h32; // '2'
                                        8'h26: push_data <= 8'h33; // '3'
                                        8'h25: push_data <= 8'h34; // '4'
                                        8'h2E: push_data <= 8'h35; // '5'
                                        8'h36: push_data <= 8'h36; // '6'
                                        8'h3D: push_data <= 8'h37; // '7'
                                        8'h3E: push_data <= 8'h38; // '8'
                                        8'h46: push_data <= 8'h39; // '9'
                                        8'h45: push_data <= 8'h30; // '0'
                                        8'h4E: push_data <= 8'h2D; // '-'
                                        8'h29: push_data <= 8'h20; // 'Space'
                                        8'h1C: push_data <= 8'h41; // 'A'
                                        8'h32: push_data <= 8'h42; // 'B'
                                        8'h21: push_data <= 8'h43; // 'C'
                                        8'h23: push_data <= 8'h44; // 'D'
                                        8'h24: push_data <= 8'h45; // 'E'
                                        8'h2B: push_data <= 8'h46; // 'F'
                                        8'h34: push_data <= 8'h47; // 'G'
                                        8'h33: push_data <= 8'h48; // 'H'
                                        8'h43: push_data <= 8'h49; // 'I'
                                        8'h3B: push_data <= 8'h4A; // 'J'
                                        8'h42: push_data <= 8'h4B; // 'K'
                                        8'h4B: push_data <= 8'h4C; // 'L'
                                        8'h3A: push_data <= 8'h4D; // 'M'
                                        8'h31: push_data <= 8'h4E; // 'N'
                                        8'h44: push_data <= 8'h4F; // 'O'
                                        8'h4D: push_data <= 8'h50; // 'P'
                                        8'h15: push_data <= 8'h51; // 'Q'
                                        8'h2D: push_data <= 8'h52; // 'R'
                                        8'h1B: push_data <= 8'h53; // 'S'
                                        8'h2C: push_data <= 8'h54; // 'T'
                                        8'h3C: push_data <= 8'h55; // 'U'
                                        8'h2A: push_data <= 8'h56; // 'V'
                                        8'h1D: push_data <= 8'h57; // 'W'
                                        8'h22: push_data <= 8'h58; // 'X'
                                        8'h35: push_data <= 8'h59; // 'Y'
                                        8'h1A: push_data <= 8'h5A; // 'Z'
                                        8'h5A: push_data <= 8'h0D; // 'Enter'
                                        default: push_req <= 1'b0; // 未映射字符不写入
                                    endcase
                                end
                                // 无论如何，清空前缀状态，准备接收下一次独立按键
                                is_e0 <= 1'b0;
                                is_f0 <= 1'b0;
                            end
                        end
                    end
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end
        end
    end

    // ==========================================
    // FIFO 并发读写管理
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= 4'd0;
            tail <= 4'd0;
            fifo_count <= 5'd0;
        end else begin
            // {写使能, 读使能}
            case ({push_req && fifo_not_full, re && fifo_not_empty})
                2'b10: begin // 仅写入数据
                    fifo_mem[tail] <= push_data;
                    tail <= tail + 4'd1;
                    fifo_count <= fifo_count + 5'd1;
                end
                2'b01: begin // 仅读取数据
                    head <= head + 4'd1;
                    fifo_count <= fifo_count - 5'd1;
                end
                2'b11: begin // 同步读写
                    fifo_mem[tail] <= push_data;
                    tail <= tail + 4'd1;
                    head <= head + 4'd1;
                end
                2'b00: begin 
                end
            endcase
        end
    end

    // ==========================================
    // 输出逻辑
    // ==========================================
    // 只要 FIFO 非空，最前端的数据直接透传到 kbd_data 端口
    // 这样 CPU 轮询状态寄存器发现有数据后，读取数据寄存器即可直接拿到字符
    always @(*) begin
        if (fifo_not_empty) begin
            kbd_data = fifo_mem[head];
        end else begin
            kbd_data = 8'h00; 
        end
    end

endmodule