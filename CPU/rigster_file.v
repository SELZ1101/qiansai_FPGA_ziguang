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
        if(w_en && (rd_addr !=5'b0))begin//注意保护x0
            reg_file[rd_addr] <= w_data;
        end
    end
    always @(*) begin
        // 对于 rs1
        if (rs1_addr == 5'b0)//由于没有复位，x0里面是x态
            rs1_data = 32'b0;
        else if ((rs1_addr == rd_addr) && w_en) // 内部写旁路：同周期读写同一寄存器，直接输出新值
            rs1_data = w_data;
        else
            rs1_data = reg_file[rs1_addr];
            
        // 对于 rs2
        if (rs2_addr == 5'b0)
            rs2_data = 32'b0;
        else if ((rs2_addr == rd_addr) && w_en)
            rs2_data = w_data;
        else
            rs2_data = reg_file[rs2_addr];
    end
endmodule
