//处理cache miss问题

module hazard_unit (
    // Load-Use 检测输入
    input  wire       MemRead_EX,
    input  wire [4:0] Rd_EX,
    input  wire [4:0] Rs1_ID,
    input  wire [4:0] Rs2_ID,
    
    // 分支跳转检测输入
    input  wire       Branch_Taken_ID, // 来自 ID 阶段的 Dedicated comparer

    // 控制信号输出
    output reg        PC_Stall,
    output reg        IF_ID_Stall,
    output reg        IF_ID_Flush,
    output reg        ID_EX_Flush
);

    always @(*) begin
        // 默认状态：流水线正常流动
        PC_Stall    = 1'b0;
        IF_ID_Stall = 1'b0;
        IF_ID_Flush = 1'b0;
        ID_EX_Flush = 1'b0;

        // 1. 优先级最高：Load-Use 数据冒险 (触发 Stall)
        if (MemRead_EX && (Rd_EX != 5'd0) && ((Rd_EX == Rs1_ID) || (Rd_EX == Rs2_ID))) begin
            PC_Stall    = 1'b1;  // 冻结 PC
            IF_ID_Stall = 1'b1;  // 冻结当前 ID 阶段指令
            ID_EX_Flush = 1'b1;  // 向 EX 阶段插入气泡
        end
        // 2. 控制冒险 (触发 Flush)
        // 注意：如果同时发生 Load-Use Stall，不需要立刻 Flush，等 Stall 结束后分支指令再执行
        else if (Branch_Taken_ID) begin
            IF_ID_Flush = 1'b1;  // 冲刷掉 IF 阶段取错的指令
        end
    end

endmodule