module Control(
    input [6:0] opcode,
    output reg branch,
    output reg mem_read,
    output reg mem_to_reg,
    output reg [1:0] alu_op,
    output reg mem_write,
    output reg alu_src,
    output reg reg_write
);

    always @(*) begin
        branch = 1'b0;
        mem_read = 1'b0;
        mem_to_reg = 1'b0;
        alu_op = 2'b00;
        mem_write = 1'b0;
        alu_src = 1'b0;
        reg_write = 1'b0;

        case(opcode)
            7'b0110011:begin//R-type
                alu_op = 2'b10;
                reg_write = 1'b1;
            end
            7'b0010011:begin//计算类I
                alu_op = 2'b10;
                alu_src = 1'b1;
                reg_write = 1'b1;
            end
            7'b0000011:begin//load类
                alu_op = 2'b00;
                mem_read = 1'b1;
                mem_to_reg = 1'b1;
                alu_src = 1'b1;
                reg_write = 1'b1;
            end
            7'b0100011:begin//store类
                alu_op = 2'b00;
                mem_write = 1'b1;
                alu_src = 1'b1;
            end
            7'b1100011:begin//B-type
                alu_op = 2'b01;
                branch = 1'b1;
            end
            7'b1101111:begin//jal
                alu_op = 2'b10;
                branch = 1'b1;
                reg_write = 1'b1;
            end
            7'b1100111:begin//jalr
                alu_op = 2'b00;
                branch = 1'b1;
                alu_src = 1'b1;
                reg_write = 1'b1;
            end
            7'b0110111:begin//lui
                alu_op = 2'b10;
                reg_write = 1'b1;
            end
            7'b0010111:begin//auipc
                alu_op = 2'b00;
                reg_write = 1'b1;
            end
            default: begin
            end
        endcase
    end
endmodule
