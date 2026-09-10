//blt,bltu,beq,bne,bge,bgeu

`timescale 1ps/1ps

module D_comparer
{
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    input [2:0] ctr

    output branch_taken
};

    wire is_equal = (rs1_data == rs2_data);

    wire is_less = (rs1_data < rs2_data);

    wire is_less_unsigned = ($signed(rs1_data) < $signed(rs2_data))

    always@(*)begin
        case(ctr)
        000:branch_taken = is_equal;
        001:branch_taken = ~is_equal;

        100:branch_taken = is_less;
        110:branch_taken = is_less_unsigned;//注意，BGE包含等于

        101:branch_taken = ~is_less;
        111:branch_taken = ~is_less_unsigned;

        default: branch_taken = 1'b0;
    end
endmodule
