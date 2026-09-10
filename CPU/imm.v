`timescale 1ps/1ps
//空间换时间
module imm_gen
(
    input [31:0] inst,
    input [2:0] Imm_sel, 
    output reg [31:0] imm
);
    wire [31:0] imm_I;
    wire [31:0] imm_S;
    wire [31:0] imm_U;
    wire [31:0] imm_B;
    wire [31:0] imm_J;

    assign imm_I = {{20{inst[31]}},inst[31:20]};//位运算符需要独立的大括号
    assign imm_S = {{20{inst[31]}},inst[31:25],inst[11:7]};
    assign imm_U = {inst[31:12],12'b0};
    assign imm_B = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};//注意地址保护
    assign imm_J = {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0};
    always@(*)begin
        case(Imm_sel)
        3'b000: imm = imm_I;
        3'b001: imm = imm_S;
        3'b010: imm = imm_B;
        3'b011: imm = imm_U;
        3'b100: imm = imm_J;
        default: imm = 32'b0;
        endcase
    end
endmodule