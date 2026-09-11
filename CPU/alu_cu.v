`timescale 1ps/1ps

module alu_cu
(
    input [1:0] alu_op,
    input [2:0] func3,
    input inst_30,

    output wire [3:0] alu_ctr
);

   // 假设主 CU 发出的 ALUOp: 10 代表 R型/I型运算类指令
wire is_R_type    = (alu_op == 2'b11);
wire is_shift_op  = (func3 == 3'b101); // 命中 sra/srl/srai/srli

// 核心掩码逻辑：是 R型，或者是移位指令，才放行 inst[30]
wire valid_inst30 = inst_30 & (is_R_type | is_shift_op);

// 最终拼接
assign alu_ctr = {valid_inst30, func3};

endmodule