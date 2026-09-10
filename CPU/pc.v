`timescale 1ps/1ps

module pc //pc不应支持flush，因为pc离存的是地址，flush的目标应当是指令
{
    input clk,
    input rst,
    input [31:0] next_pc,

    input pc_stall,
     
    output reg [31:0] pc_out
    
};

    always@(posedge clk or posedge rst)begin
        if(rst)
            pc_out <= 32'b0;
        else if(!pc_stall)
            pc_out <= next_pc;
        else pc_out <= pc_out;
    end
endmodule 
