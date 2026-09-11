//高性能处理器中将CU分为了主CU和aluCU,这样可以是精细译码和寄存器取值并行发生，有效提高主频。
//两个CU均为组合逻辑。没写完，加一个jal
`timescale 1ps/1ps

module main_control(
    input  [6:0] opcode,//只需要看opcode
    output       Branch,
    output       MemRead,
    output [1:0] MemtoReg, 
    output [1:0] ALUOp,//强制的意义在哪,10指的是读func3和func7
    output       MemWrite,
    output       ALUSrc,
    output       RegWrite,
    output       is_jump   
);

    wire [9:0] controls;
    assign {Branch, MemRead, MemtoReg, ALUOp, MemWrite, ALUSrc, RegWrite,is_jump} = controls;
   
    reg [9:0] ctrl_reg;
    assign controls = ctrl_reg;

    always @(*) begin
        case(opcode)
            // {Branch, MemRead, MemtoReg[1:0], ALUOp[1:0], MemWrite, ALUSrc, RegWrite,is_jump},写回选择要不要加到两位
            7'b0110011: ctrl_reg = 10'b0_0_00_11_0_0_1_0; // R-Type: ALUOp=10
            7'b0000011: ctrl_reg = 10'b0_1_01_00_0_1_1_0; // Load:   ALUOp=00
            7'b0100011: ctrl_reg = 10'b0_0_00_00_1_1_0_0; // Store:  ALUOp=00
            7'b1100011: ctrl_reg = 10'b1_0_00_01_0_0_0_0; // Branch: ALUOp=01
            7'b0010011: ctrl_reg = 10'b0_0_00_10_0_1_1_0;//I指令
            7'b1101111: ctrl_reg = 10'b0_0_10_00_0_1_1_1;//jal指令
            7'b1100111: ctrl_reg = 10'b0_0_10_00_0_1_1_1;//jalr,是rs1+imm
            7'b0110111: ctrl_reg = 10'b0_0_00_00_0_1_1_0;//lui,默认加
            7'b0010111: ctrl_reg = 10'b0_0_00_00_0_1_1_0;//auipc,也是往RF写，默认加
            default:    ctrl_reg = 10'b0_0_00_00_0_0_0_0;
        endcase
    end
endmodule