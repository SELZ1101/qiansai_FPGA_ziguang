//add,addi,slt,slti,ori,xori,slli,srli,srai,lui,auipc,and,or,xor,sll,srl,sra,sub,load系，store系，andi,sltu,sltiu

`timescale   1ps/1ps

module alu
(
    input [3:0]alu_op,//alu不需时钟信号，但要控制信号

    input [31:0] a_data,//选择a,b输入的任务交给了外部电路
    input [31:0] b_data,

    output reg [31:0] rd_data
);

    wire is_sub = (alu_op == 4'b1000)||(alu_op == 4'b0010)||(alu_op == 4'b0011);

    wire [31:0] b = is_sub?~b_data:b_data;//取反32位全取，原码变补码是只变后31位
    wire [32:0] add_res = {1'b0, a_data} + {1'b0, b} + is_sub;//复用一下
    wire sign_a = a_data[31];
    wire sign_b = b_data[31];
    wire sign_res = add_res[32];

    wire slt_res = (sign_a == sign_b) ? sign_res : sign_a;
    wire sltu_res = sign_res;

    always@(*)begin
        case(alu_op)
        4'b0000:rd_data = add_res;
        4'b1000:rd_data = add_res;
        4'b0100:rd_data = a_data ^ b_data;
        4'b0110:rd_data = a_data | b_data;
        4'b0111:rd_data = a_data & b_data;

        4'b0001:rd_data = a_data << b_data[4:0];
        4'b0101:rd_data = a_data >> b_data[4:0];
        4'b1101:rd_data = $signed(a_data) >>> b_data[4:0];

        4'b0010:rd_data = slt_res;
        4'b0011:rd_data = sltu_res;

        default rd_data = 32'b0;
        endcase
    end
endmodule
