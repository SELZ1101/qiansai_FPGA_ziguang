`timescale 1ps/1ps

module pipe_reg
#(
   parameter WIDTH = 32
)
(
    input clk,
    input reset,
    input pipe_reg_stall,
    input pipe_reg_flush,

    input [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    always@(posedge clk or posedge reset)begin
        if(reset)
            data_out <= 0;
        else if(pipe_reg_flush)
            data_out <= 0;
        else if(pipe_reg_stall)
            data_out <= data_out;
        else data_out <= data_in;
        end
endmodule 