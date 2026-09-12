`timescale 1ns / 1ps

module tb_cpu_top();

    // 时钟与复位
    reg clk;
    reg rst_n;

    // I-Cache / Router 接口
    wire [31:0] inst_addr_o;
    wire        inst_req_o;
    reg  [31:0] inst_rdata_i;
    reg         inst_rvalid_i;

    // D-Cache / Router 接口
    wire [31:0] data_addr_o;
    wire        data_req_o;
    wire        data_we_o;
    wire [ 3:0] data_wmask_o;
    wire [31:0] data_wdata_o;
    reg  [31:0] data_rdata_i;
    reg         data_rvalid_i;

    // 实例化 CPU 顶层
    cpu_top u_cpu_top (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_addr_o    (inst_addr_o),
        .inst_req_o     (inst_req_o),
        .inst_rdata_i   (inst_rdata_i),
        .inst_rvalid_i  (inst_rvalid_i),
        .data_addr_o    (data_addr_o),
        .data_req_o     (data_req_o),
        .data_we_o      (data_we_o),
        .data_wmask_o   (data_wmask_o),
        .data_wdata_o   (data_wdata_o),
        .data_rdata_i   (data_rdata_i),
        .data_rvalid_i  (data_rvalid_i)
    );

    // 模拟存储器 (4K 空间，按字寻址，深度为1024)
    // 【修改】将 imem 的容量扩大为 1024，解决 inst_addr_o[11:2] 带来的越界隐患
    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];

    // 载入机器码
    initial begin
        // 确保 inst_rom.txt 在 Vivado 仿真工作目录下
        $readmemh("inst_rom.txt", imem);
    end

    // 时钟生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 仿真流程控制
    initial begin
        rst_n = 0;
        // initial块中不再需要给 valid 赋初值，因为复位逻辑已处理
        #20;
        rst_n = 1; // 释放复位
        
        #1500;
        $finish;
    end

    // 模拟取指 Router/Cache (单周期响应)
    always @(posedge clk) begin
        // 【修改】增加复位逻辑判断
        if (!rst_n) begin
            inst_rvalid_i <= 1'b0;
            inst_rdata_i  <= 32'b0;
        end else if (inst_req_o) begin
            // 按字寻址需右移 2 位
            inst_rdata_i <= imem[inst_addr_o[11:2]]; 
            inst_rvalid_i <= 1'b1;
        end else begin
            inst_rvalid_i <= 1'b0;
        end
    end

    // 模拟访存 Router/Cache (单周期响应)
    always @(posedge clk) begin
        // 【修改】增加复位逻辑判断
        if (!rst_n) begin
            data_rvalid_i <= 1'b0;
            data_rdata_i  <= 32'b0;
        end else if (data_req_o) begin
            if (data_we_o) begin
                // 简化仿真，假设这里是整字对齐写入，暂未处理 wmask
                dmem[data_addr_o[11:2]] <= data_wdata_o;
            end else begin
                data_rdata_i <= dmem[data_addr_o[11:2]];
            end
            data_rvalid_i <= 1'b1;
        end else begin
            data_rvalid_i <= 1'b0;
        end
    end

endmodule