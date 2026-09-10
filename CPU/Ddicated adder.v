//J型和B型的跳转地址计算
`timescale 1ps/1ps

module D_adder4
{
    input [31:0] rs1_data,//JALR要用
    input [31:0] pc_data,//B和JAL
    input [31:0] imm,
    input is_jalr,

    output [31:0]add

};


    wire [31:0] a_data = is_jalr?rs1_data:pc_data;

    wire [31:0] sum = a_data + imm;

    wire add = {sum[31:1]+1'b0};//做地址对齐。

endmodule