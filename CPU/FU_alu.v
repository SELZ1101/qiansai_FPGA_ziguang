`timescale 1ps/1ps
//对ID前推可以认为EX阶段的是EX/MEM寄存器中的下一个数据，
module fu_alu
(
    input [4:0] alu_rs1,
    input [4:0] alu_rs2, 
    input [4:0] ex_mem_rd,
    input [4:0] mem_wb_rd,
    input  ex_mem_reg_write,
    input  mem_wb_reg_write,

    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
//Cache miss等待时，不应该发生前递。但实则不会有任何影响
always@(*)begin//if和else必须在always块中
    if((alu_rs1 == ex_mem_rd)&&(alu_rs1 != 5'b0)&& ex_mem_reg_write)
        forward_a = 2'b01;
    else if((alu_rs1 == mem_wb_rd)&&(alu_rs1 != 5'b0)&& mem_wb_reg_write)
        forward_a = 2'b10;
    else forward_a = 2'b00;

    if((alu_rs2 == ex_mem_rd)&&(alu_rs2 != 5'b0)&& ex_mem_reg_write)
        forward_b = 2'b01;
    else if((alu_rs2 == mem_wb_rd)&&(alu_rs2 != 5'b0)&& mem_wb_reg_write)
        forward_b = 2'b10;
    else forward_b = 2'b00;
end
endmodule
