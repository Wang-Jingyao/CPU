module Decoder(
    input [31:0] instruction,
    output reg [4:0] rs1,
    output reg [4:0] rs2,
    output reg [4:0] rd,
    output reg [31:0] imm,
    output reg [4:0] alu_ctrl_op
);
    wire [6:0]opcode=instruction[6:0];
    wire [3:0]func={instruction[30],instruction[14:12]};
    always @(*) begin
        rs1 = 5'b0;
        rs2 = 5'b0;
        rd = 5'b0;
        imm = 32'b0;
        alu_ctrl_op = 5'b00000;

        case(opcode)
            7'b0110011:begin//R-type
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                rd = instruction[11:7];
            end
            7'b0010011,7'b0000011,7'b1100111:begin//I-type
                rs1 = instruction[19:15];
                rd = instruction[11:7];
                imm = {{20{instruction[31]}},instruction[31:20]};
            end
            7'b0100011:begin//S-type
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                imm = {{20{instruction[11]}},instruction[31:25],instruction[11:7]};
            end
            7'b1100011:begin//B-type
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                imm = {{19{instruction[7]}},instruction[31],instruction[7],instruction[30:25],instruction[11:8],1'b0};
            end
            7'b1101111:begin//J-type
                rd = instruction[11:7];
                imm = {{11{instruction[31]}},instruction[31],instruction[19:12],instruction[20],instruction[30:21],1'b0};
            end
            7'b0110111,7'b0010111:begin//U-type
                rd = instruction[11:7];
                imm = {instruction[31:12],12'b0};
            end
        endcase

        case(opcode)
            7'b0110011:begin//R-type
                if (instruction[31:25] == 7'b0000001) begin
                    case(instruction[14:12])
                        3'b000:alu_ctrl_op=5'b10000;//mul
                        3'b001:alu_ctrl_op=5'b10001;//mulh
                        3'b010:alu_ctrl_op=5'b10010;//mulhsu
                        3'b011:alu_ctrl_op=5'b10011;//mulhu
                        3'b100:alu_ctrl_op=5'b10100;//div
                        3'b101:alu_ctrl_op=5'b10101;//divu
                        3'b110:alu_ctrl_op=5'b10110;//rem
                        3'b111:alu_ctrl_op=5'b10111;//remu
                    endcase
                end else begin
                    case(func)
                        4'b0000:alu_ctrl_op=5'b00000;//add
                        4'b1000:alu_ctrl_op=5'b00001;//sub
                        4'b0111:alu_ctrl_op=5'b00010;//and
                        4'b0110:alu_ctrl_op=5'b00011;//or
                        4'b0100:alu_ctrl_op=5'b00100;//xor
                        4'b0001:alu_ctrl_op=5'b00110;//sll
                        4'b0101:alu_ctrl_op=5'b00111;//srl
                        4'b0010:alu_ctrl_op=5'b01000;//slt
                        4'b1101:alu_ctrl_op=5'b01001;//sra
                        4'b0011:alu_ctrl_op=5'b01010;//sltu
                    endcase
                end
            end
            7'b0010011:begin//计算类I
                case(func[2:0])
                3'b000:alu_ctrl_op=5'b00000;//addi
                3'b111:alu_ctrl_op=5'b00010;//andi
                3'b110:alu_ctrl_op=5'b00011;//ori
                3'b100:alu_ctrl_op=5'b00100;//xori
                3'b001:if(func[3]==0)alu_ctrl_op=5'b00110;//slli
                3'b101:begin
                    if(func[3]==0)alu_ctrl_op=5'b00111;//srli
                    if(func[3]==1)alu_ctrl_op=5'b01001;//srai
                end
                3'b010:alu_ctrl_op=5'b01000;//slti
                3'b011:alu_ctrl_op=5'b01010;//sltiu
                endcase
            end
            7'b0000011:begin//load类
                
            end
            7'b0100011:begin//store类
                
            end
            7'b1100011:begin//B-type
                case(func[2:0])
                    3'b000:alu_ctrl_op=5'b01011;//beq
                    3'b001:alu_ctrl_op=5'b01100;//bne
                    3'b100:alu_ctrl_op=5'b01101;
                endcase
            end
            7'b1101111:begin//jal
                
            end
            7'b1100111:begin//jalr
            
            end
            7'b0110111:begin//lui
                alu_ctrl_op=5'b00101;
            end
            7'b0010111:begin//auipc

            end
            default: begin
            end
        endcase

    end
endmodule
