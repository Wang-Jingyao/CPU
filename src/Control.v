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
        case(opcode)
            7'b0110011:begin//R-type
                branch = 0;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b10;
                mem_write = 0;
                alu_src = 0;
                reg_write = 1;
            end
            7'b0010011:begin//计算类I
                branch = 0;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b10;
                mem_write = 0;
                alu_src = 1;
                reg_write = 1;
            end
            7'b0000011:begin//load类
                branch = 0;
                mem_read = 1;
                mem_to_reg = 1;
                alu_op = 2'b00;
                mem_write = 0;
                alu_src = 1;
                reg_write = 1;
            end
            7'b0100011:begin//store类
                branch = 0;
                mem_read = 0;
                mem_to_reg = 0;//both ok
                alu_op = 2'b00;
                mem_write = 1;
                alu_src = 1;
                reg_write = 0;
            end
            7'b1100011:begin//B-type
                branch = 1;
                mem_read = 0;
                mem_to_reg = 0;//both ok
                alu_op = 2'b01;
                mem_write = 0;
                alu_src = 0;
                reg_write = 0;
            end
            7'b1101111:begin//jal
                branch = 1;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b10;
                mem_write = 0;
                alu_src = 0;
                reg_write = 1;
            end
            7'b1100111:begin//jalr
                branch = 1;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b00;
                mem_write = 0;
                alu_src = 1;
                reg_write = 1;
            end
            7'b0110111:begin//lui
                branch = 0;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b10;
                mem_write = 0;
                alu_src = 0;
                reg_write = 1;
            end
            7'b0010111:begin//auipc
                branch = 0;
                mem_read = 0;
                mem_to_reg = 0;
                alu_op = 2'b00;
                mem_write = 0;
                alu_src = 0;
                reg_write = 1;
            end
        endcase
    end
endmodule
