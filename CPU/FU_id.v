`timescale 1ps/1ps
//对ID前推可以认为EX阶段的是EX/MEM寄存器中的下一个数据，
module fu_id
(
    input [4:0] id_rs1,
    input [4:0] id_rs2,
    input [4:0] ex_rd, 
    input [4:0] ex_mem_rd,
    input [4:0] mem_wb_rd,
    input  ex_rd_reg_write,
    input  ex_mem_reg_write,
    input  mem_wb_reg_write,

    output reg [1:0] id_forward_a,
    output reg [1:0] id_forward_b
);

always@(*)begin//if和else必须在always块中,写回阶段前推直接在rf内部完成了。
    if((id_rs1 == ex_rd)&&(id_rs1 != 5'b0)&& ex_rd_reg_write)
        id_forward_a = 2'b01;
    else if((id_rs1 == ex_mem_rd)&&(id_rs1 != 5'b0)&&ex_mem_reg_write)
        id_forward_a = 2'b10;
    else id_forward_a = 2'b00;

    if((id_rs2 == ex_rd)&&(id_rs2 != 5'b0)&& ex_rd_reg_write)
        id_forward_b = 2'b01;
    else if((id_rs2 == ex_mem_rd)&&(id_rs2 != 5'b0)&&ex_mem_reg_write)
        id_forward_b = 2'b10;
    else id_forward_b = 2'b00;
end
endmodule