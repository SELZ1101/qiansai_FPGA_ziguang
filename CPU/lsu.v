module lsu (
    input  wire [2:0]  funct3,         // 指令 funct3 字段，决定读写类型 (b/h/w/bu/hu)
    input  wire [31:0] addr,           // 来自 ALU 的内存地址
    input  wire [31:0] write_data,     // 来自 Rs2 的待写入原始数据 (用于 Store)
    input  wire        mem_write,      // 控制信号：是否写内存
    input  wire        mem_read,       // 控制信号：是否读内存
    input  wire [31:0] router_read_data,  // 从 router 取回的 32 位整行原始数据

    output reg  [3:0]  router_we,         // 输出给 router 的 4 位字节写使能 (Byte Enable)
    output reg  [31:0] router_write_data, // 输出给 router 的对齐后写入数据
    output reg  [31:0] lsu_out_data    // 输出给 WB 阶段的目标寄存器写入数据
);

    // funct3 编码定义
    localparam F3_LB  = 3'b000;
    localparam F3_LH  = 3'b001;
    localparam F3_LW  = 3'b010;
    localparam F3_LBU = 3'b100;
    localparam F3_LHU = 3'b101;
    localparam F3_SB  = 3'b000;
    localparam F3_SH  = 3'b001;
    localparam F3_SW  = 3'b010;

    wire [1:0] offset = addr[1:0];

    // ==========================================
    // 1. Store 操作：生成写使能 (router_we) 与数据对齐
    // ==========================================
    always @(*) begin
        // 默认不写内存，数据清零
        router_we         = 4'b0000;
        router_write_data = 32'b0;

        if (mem_write) begin
            case (funct3)
                F3_SB: begin // Store Byte (8-bit)
                    case (offset)
                        2'b00: begin router_we = 4'b0001; router_write_data = {24'b0, write_data[7:0]}; end
                        2'b01: begin router_we = 4'b0010; router_write_data = {16'b0, write_data[7:0], 8'b0}; end
                        2'b10: begin router_we = 4'b0100; router_write_data = {8'b0,  write_data[7:0], 16'b0}; end
                        2'b11: begin router_we = 4'b1000; router_write_data = {write_data[7:0], 24'b0}; end
                    endcase
                end
                F3_SH: begin // Store Halfword (16-bit)
                    case (offset[1]) // 只看最高位，因为半字对齐必定是 00 或 10
                        1'b0:  begin router_we = 4'b0011; router_write_data = {16'b0, write_data[15:0]}; end
                        1'b1:  begin router_we = 4'b1100; router_write_data = {write_data[15:0], 16'b0}; end
                    endcase
                end
                F3_SW: begin // Store Word (32-bit)
                    router_we = 4'b1111;
                    router_write_data = write_data;
                end
                default: begin
                    router_we = 4'b0000;
                    router_write_data = 32'b0;
                end
            endcase
        end
    end

    // ==========================================
    // 2. Load 操作：数据截取与符号扩展
    // ==========================================
    always @(*) begin
        lsu_out_data = 32'b0; // 默认输出 0

        if (mem_read) begin
            case (funct3)
                F3_LB: begin // Load Byte (有符号扩展)
                    case (offset)
                        2'b00: lsu_out_data = {{24{router_read_data[7]}},  router_read_data[7:0]};
                        2'b01: lsu_out_data = {{24{router_read_data[15]}}, router_read_data[15:8]};
                        2'b10: lsu_out_data = {{24{router_read_data[23]}}, router_read_data[23:16]};
                        2'b11: lsu_out_data = {{24{router_read_data[31]}}, router_read_data[31:24]};
                    endcase
                end
                F3_LBU: begin // Load Byte Unsigned (零扩展)
                    case (offset)
                        2'b00: lsu_out_data = {24'b0, router_read_data[7:0]};
                        2'b01: lsu_out_data = {24'b0, router_read_data[15:8]};
                        2'b10: lsu_out_data = {24'b0, router_read_data[23:16]};
                        2'b11: lsu_out_data = {24'b0, router_read_data[31:24]};
                    endcase
                end
                F3_LH: begin // Load Halfword (有符号扩展)
                    case (offset[1])
                        1'b0: lsu_out_data = {{16{router_read_data[15]}}, router_read_data[15:0]};
                        1'b1: lsu_out_data = {{16{router_read_data[31]}}, router_read_data[31:16]};
                    endcase
                end
                F3_LHU: begin // Load Halfword Unsigned (零扩展)
                    case (offset[1])
                        1'b0: lsu_out_data = {16'b0, router_read_data[15:0]};
                        1'b1: lsu_out_data = {16'b0, router_read_data[31:16]};
                    endcase
                end
                F3_LW: begin // Load Word (直接输出全 32 位)
                    lsu_out_data = router_read_data;
                end
                default: begin
                    lsu_out_data = 32'b0;
                end
            endcase
        end
    end

endmodule