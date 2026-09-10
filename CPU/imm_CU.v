`timescale 1ps/1ps

module imm_CU (
    input  wire [6:0] opcode,
    output reg  [2:0] Imm_sel
);
    always @(*) begin
        case(opcode)
            7'b0010011: Imm_sel = 3'b000; // I-Type (addi, etc.)
            7'b0000011: Imm_sel = 3'b000; // I-Type (Load)
            7'b1100111: Imm_sel = 3'b000; // I-Type (jalr)
            7'b0100011: Imm_sel = 3'b001; // S-Type (Store)
            7'b1100011: Imm_sel = 3'b010; // B-Type (Branch)
            7'b0110111: Imm_sel = 3'b011; // U-Type (lui)
            7'b0010111: Imm_sel = 3'b011; // U-Type (auipc)
            7'b1101111: Imm_sel = 3'b100; // J-Type (jal)
            default:    Imm_sel = 3'b000; 
        endcase
    end
endmodule