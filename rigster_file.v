`timescale 1ps/1ps
//无需读使能，可拉高主频.rf不需要stall和flush信号，也不需要复位全置零。
module RF
(
    input clk,//RF根本不需要复位信号
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    input [4:0] rd_addr,

    input w_en,
    input [31:0] w_data,
    output reg [31:0] rs1_data,
    output reg [31:0] rs2_data
);

    reg [31:0] reg_file[31:0];//不大，不需要一味追求用BRAM
    always@(posedge clk )begin
        if(w_en && (rd_data !=5'b0))begin//注意保护x0
            reg_file[rd_addr] <= w_data;
        end
        rs1_data <= reg_file[rs1_addr];
        rs2_data <= reg_file[rs2_addr];
    end
endmodule
