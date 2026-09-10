`timescale 1ps/1ps

module cpu_top (
    input  wire        clk,
    input  wire        rst_n,

    // ==========================================
    // 接口：连接到外部的 Address Router 或 Cache
    // ==========================================
    // I-Cache / Router 接口 (IF 阶段)
    output wire [31:0] inst_addr_o,
    output wire        inst_req_o,
    input  wire [31:0] inst_rdata_i,
    input  wire        inst_rvalid_i,

    // D-Cache / Router 接口 (MEM 阶段)
    output wire [31:0] data_addr_o,
    output wire        data_req_o,
    output wire        data_we_o,
    output wire [ 3:0] data_wmask_o,
    output wire [31:0] data_wdata_o,
    input  wire [31:0] data_rdata_i,
    input  wire        data_rvalid_i
);

    // ==========================================
    // 0. 全局声明：冒险控制与 Valid Bit
    // ==========================================
    // 提前声明后续阶段的写回/前递信号，解开依赖环
    wire [4:0]  rd_ex, rd_mem, rd_wb;
    wire        reg_write_ex, reg_write_mem, reg_write_wb;
    wire [31:0] alu_result_ex, alu_result_mem, wb_data;
    wire        MemRead_ex;

    // 分支判定结果 (ID阶段产生)
    wire branch_taken_id; 

    // ID阶段操作数
    wire [4:0] rs1_id = if2_id_bus_out[19:15];
    wire [4:0] rs2_id = if2_id_bus_out[24:20];

    // Load-Use 冒险检测: EX 阶段是 Load 指令，且目标寄存器与 ID 阶段的源寄存器冲突
    wire load_use_stall = MemRead_ex && (rd_ex != 5'd0) && ((rd_ex == rs1_id) || (rd_ex == rs2_id));

    // 各级 Stall 控制
    wire pc_stall      = load_use_stall;
    wire if1_if2_stall = load_use_stall;
    wire if2_id_stall  = load_use_stall;
    wire id_ex_stall   = 1'b0; 
    wire ex_mem_stall  = 1'b0;
    wire mem_wb_stall  = 1'b0;

    // 各阶段有效位寄存器 (1代表有效指令，0代表气泡)
    reg valid_if1_if2, valid_if2_id, valid_id_ex, valid_ex_mem, valid_mem_wb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_if1_if2 <= 1'b0;
            valid_if2_id  <= 1'b0;
            valid_id_ex   <= 1'b0;
            valid_ex_mem  <= 1'b0;
            valid_mem_wb  <= 1'b0;
        end else begin
            // IF1 -> IF2
            if (branch_taken_id) 
                valid_if1_if2 <= 1'b0; 
            else if (!if1_if2_stall)
                valid_if1_if2 <= 1'b1; // 默认取指有效

            // IF2 -> ID
            if (branch_taken_id)
                valid_if2_id <= 1'b0;  
            else if (!if2_id_stall)
                valid_if2_id <= valid_if1_if2;

            // ID -> EX (处理 Load-Use 气泡注入)
            if (load_use_stall)
                valid_id_ex <= 1'b0;   
            else if (!id_ex_stall)
                valid_id_ex <= valid_if2_id;

            // EX -> MEM
            if (!ex_mem_stall)
                valid_ex_mem <= valid_id_ex;

            // MEM -> WB
            if (!mem_wb_stall)
                valid_mem_wb <= valid_ex_mem;
        end
    end

    // ==========================================
    // 1. IF1 阶段: PC 与 Next PC 计算
    // ==========================================
    wire [31:0] pc_if1;
    wire [31:0] pc_plus_4 = pc_if1 + 32'd4;
    wire [31:0] branch_target_id; 
    
    // MUX 紧贴 PC 输入端[cite: 13]
    wire [31:0] next_pc = branch_taken_id ? branch_target_id : pc_plus_4;
    
    pc u_pc (
        .clk      (clk),
        .rst      (~rst_n),
        .next_pc  (next_pc),
        .pc_stall (pc_stall),
        .pc_out   (pc_if1)
    );
    
    assign inst_addr_o = pc_if1;
    assign inst_req_o  = ~pc_stall; 

    // IF1/IF2 流水线寄存器[cite: 14]
    wire [31:0] if1_if2_bus_out;
    pipe_reg #(.WIDTH(32)) if1_if2_reg (
        .clk            (clk),
        .reset          (~rst_n),
        .pipe_reg_stall (if1_if2_stall),
        .pipe_reg_flush (1'b0), 
        .data_in        (pc_if1),
        .data_out       (if1_if2_bus_out)
    );
    wire [31:0] pc_if2 = if1_if2_bus_out;

    // ==========================================
    // 2. IF2 阶段: 接收指令
    // ==========================================
    wire [31:0] inst_if2 = inst_rdata_i;

    // IF2/ID 流水线寄存器
    wire [63:0] if2_id_bus_out;
    pipe_reg #(.WIDTH(64)) if2_id_reg (
        .clk            (clk),
        .reset          (~rst_n),
        .pipe_reg_stall (if2_id_stall),
        .pipe_reg_flush (1'b0), 
        .data_in        ({pc_if2, inst_if2}),
        .data_out       (if2_id_bus_out)
    );
    wire [31:0] pc_id   = if2_id_bus_out[63:32];
    wire [31:0] inst_id = if2_id_bus_out[31:0];

    // ==========================================
    // 3. ID 阶段: 译码、分发、前递与分支解析
    // ==========================================
    wire [6:0] opcode_id = inst_id[6:0];
    wire [4:0] rd_id     = inst_id[11:7];
    wire [2:0] func3_id  = inst_id[14:12];

    // --- 主控制单元 ---[cite: 11]
    wire Branch_id, MemRead_id, MemWrite_id, ALUSrc_id, RegWrite_id, is_jump_id;
    wire [1:0] MemtoReg_id, ALUOp_id;
    main_control u_main_cu (
        .opcode   (opcode_id),
        .Branch   (Branch_id),
        .MemRead  (MemRead_id),
        .MemtoReg (MemtoReg_id),
        .ALUOp    (ALUOp_id),
        .MemWrite (MemWrite_id),
        .ALUSrc   (ALUSrc_id),
        .RegWrite (RegWrite_id),
        .is_jump  (is_jump_id)
    );

    // --- ALU 控制单元 (提前到 ID 阶段) ---[cite: 3]
    wire [3:0] alu_ctr_id;
    alu_cu u_alu_cu (
        .alu_op  (ALUOp_id),
        .func3   (func3_id),
        .inst_30 (inst_id[30]),
        .alu_ctr (alu_ctr_id)
    );

    // --- 立即数生成 ---[cite: 9]
    wire [2:0] imm_sel_id;
    wire [31:0] imm_id;
    imm_CU u_imm_cu (.opcode(opcode_id), .Imm_sel(imm_sel_id));
    imm_gen u_imm_gen (.inst(inst_id), .Imm_sel(imm_sel_id), .imm(imm_id));

    // --- 寄存器堆 (RF) ---[cite: 15]
    wire [31:0] rf_rs1_data, rf_rs2_data;
    RF u_rf (
        .clk      (clk),
        .rs1_addr (rs1_id),
        .rs2_addr (rs2_id),
        .rd_addr  (rd_wb),         
        .w_en     (reg_write_wb),  
        .w_data   (wb_data),       
        .rs1_data (rf_rs1_data),
        .rs2_data (rf_rs2_data)
    );

    // --- ID 阶段前递单元 ---[cite: 7]
    wire [1:0] id_forward_a, id_forward_b;
    fu_id u_fu_id (
        .id_rs1           (rs1_id),
        .id_rs2           (rs2_id),
        .ex_rd            (rd_ex),
        .ex_mem_rd        (rd_mem),
        .mem_wb_rd        (rd_wb),
        .ex_rd_reg_write  (reg_write_ex),
        .ex_mem_reg_write (reg_write_mem),
        .mem_wb_reg_write (reg_write_wb),
        .id_forward_a     (id_forward_a),
        .id_forward_b     (id_forward_b)
    );

    wire [31:0] id_rs1_fwd, id_rs2_fwd;
    mux4 #(.WIDTH(32)) u_mux_id_rs1 (
        .in0(rf_rs1_data), .in1(alu_result_ex), .in2(alu_result_mem), .in3(32'b0),
        .sel(id_forward_a), .out(id_rs1_fwd)
    );
    mux4 #(.WIDTH(32)) u_mux_id_rs2 (
        .in0(rf_rs2_data), .in1(alu_result_ex), .in2(alu_result_mem), .in3(32'b0),
        .sel(id_forward_b), .out(id_rs2_fwd)
    );

    // --- 专用比较器与加法器 ---[cite: 4, 5]
    wire comparer_branch_taken;
    D_comparer u_d_comparer (
        .rs1_data     (id_rs1_fwd),
        .rs2_data     (id_rs2_fwd),
        .ctr          (func3_id), 
        .branch_taken (comparer_branch_taken)
    );

    // 气泡指令(Valid=0)强制不发生跳转
    assign branch_taken_id = valid_if2_id & (is_jump_id | (Branch_id & comparer_branch_taken));

    wire is_jalr_id = (opcode_id == 7'b1100111);
    D_adder4 u_d_adder4 (
        .rs1_data (id_rs1_fwd),
        .pc_data  (pc_id),
        .imm      (imm_id),
        .is_jalr  (is_jalr_id),
        .add      (branch_target_id)
    );

    // ID/EX 流水线寄存器数据打包 (优化后为 151 位)
    wire [150:0] id_ex_bus_in = {
        pc_id,       // [150:119] 32-bit
        id_rs1_fwd,  // [118:87]  32-bit
        id_rs2_fwd,  // [86:55]   32-bit
        imm_id,      // [54:23]   32-bit
        rs1_id,      // [22:18]   5-bit
        rs2_id,      // [17:13]   5-bit
        rd_id,       // [12:8]    5-bit
        func3_id,    // [7:5]     3-bit: 留给 LSU 判断掩码用
        alu_ctr_id,  // [4:1]     4-bit: 预计算好的 ALU 控制码
        ALUSrc_id    // [0]       1-bit
    };
    
    wire [4:0] id_ex_ctrl_in = {MemWrite_id, MemRead_id, MemtoReg_id, RegWrite_id};
    wire [150:0] id_ex_bus_out;
    wire [4:0]   id_ex_ctrl_out;

    pipe_reg #(.WIDTH(151)) id_ex_data_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(id_ex_stall), .pipe_reg_flush(1'b0), 
        .data_in(id_ex_bus_in), .data_out(id_ex_bus_out)
    );
    
    // Valid 位屏障：有效则透传，气泡则清空控制信号
    wire [4:0] safe_ctrl_in = valid_id_ex ? id_ex_ctrl_in : 5'b0;
    pipe_reg #(.WIDTH(5)) id_ex_ctrl_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(id_ex_stall), .pipe_reg_flush(1'b0), 
        .data_in(safe_ctrl_in), .data_out(id_ex_ctrl_out)
    );

    // ==========================================
    // 4. EX 阶段: ALU 计算与前递
    // ==========================================
    wire [31:0] pc_ex       = id_ex_bus_out[150:119];
    wire [31:0] rs1_data_ex = id_ex_bus_out[118:87];
    wire [31:0] rs2_data_ex = id_ex_bus_out[86:55];
    wire [31:0] imm_ex      = id_ex_bus_out[54:23];
    wire [4:0]  rs1_ex      = id_ex_bus_out[22:18];
    wire [4:0]  rs2_ex      = id_ex_bus_out[17:13];
    assign      rd_ex       = id_ex_bus_out[12:8];
    wire [2:0]  func3_ex    = id_ex_bus_out[7:5];
    wire [3:0]  alu_ctr_ex  = id_ex_bus_out[4:1];
    wire        ALUSrc_ex   = id_ex_bus_out[0];

    wire MemWrite_ex;
    wire [1:0] MemtoReg_ex;
    assign {MemWrite_ex, MemRead_ex, MemtoReg_ex, reg_write_ex} = id_ex_ctrl_out;

    // --- EX 阶段前递 ---[cite: 6]
    wire [1:0] forward_a_ex, forward_b_ex;
    fu_alu u_fu_alu (
        .alu_rs1          (rs1_ex),
        .alu_rs2          (rs2_ex),
        .ex_mem_rd        (rd_mem),      
        .mem_wb_rd        (rd_wb),       
        .ex_mem_reg_write (reg_write_mem),
        .mem_wb_reg_write (reg_write_wb),
        .forward_a        (forward_a_ex),
        .forward_b        (forward_b_ex)
    );

    wire [31:0] alu_in_a, alu_in_b_fwd;
    mux4 #(.WIDTH(32)) u_mux_ex_fwd_a (
        .in0(rs1_data_ex), .in1(alu_result_mem), .in2(wb_data), .in3(32'b0),
        .sel(forward_a_ex), .out(alu_in_a)
    );
    mux4 #(.WIDTH(32)) u_mux_ex_fwd_b (
        .in0(rs2_data_ex), .in1(alu_result_mem), .in2(wb_data), .in3(32'b0),
        .sel(forward_b_ex), .out(alu_in_b_fwd)
    );
    wire [31:0] alu_in_b = ALUSrc_ex ? imm_ex : alu_in_b_fwd;

    // --- ALU 执行 (直接使用译码好的 alu_ctr) ---[cite: 2]
    alu u_alu (
        .alu_op  (alu_ctr_ex), 
        .a_data  (alu_in_a), 
        .b_data  (alu_in_b), 
        .rd_data (alu_result_ex)
    );

    wire [31:0] pc_plus_4_ex = pc_ex + 32'd4;

    // EX/MEM 流水线寄存器
    wire [103:0] ex_mem_bus_in = {pc_plus_4_ex, alu_result_ex, alu_in_b_fwd, rd_ex, func3_ex};
    wire [4:0]   ex_mem_ctrl_in = id_ex_ctrl_out;
    wire [103:0] ex_mem_bus_out;
    wire [4:0]   ex_mem_ctrl_out;

    pipe_reg #(.WIDTH(104)) ex_mem_data_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(ex_mem_stall), .pipe_reg_flush(1'b0), 
        .data_in(ex_mem_bus_in), .data_out(ex_mem_bus_out)
    );
    pipe_reg #(.WIDTH(5)) ex_mem_ctrl_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(ex_mem_stall), .pipe_reg_flush(1'b0), 
        .data_in(ex_mem_ctrl_in), .data_out(ex_mem_ctrl_out)
    );

    // ==========================================
    // 5. MEM 阶段: 访存
    // ==========================================
    wire [31:0] pc_plus_4_mem  = ex_mem_bus_out[103:72];
    assign      alu_result_mem = ex_mem_bus_out[71:40];
    wire [31:0] store_data_mem = ex_mem_bus_out[39:8];
    assign      rd_mem         = ex_mem_bus_out[7:3];
    wire [2:0]  func3_mem      = ex_mem_bus_out[2:0];

    wire MemWrite_mem = ex_mem_ctrl_out[4];
    wire MemRead_mem  = ex_mem_ctrl_out[3];
    assign reg_write_mem = ex_mem_ctrl_out[0];

    // --- LSU ---[cite: 10]
    wire [31:0] lsu_out_data_mem;
    lsu u_lsu (
        .funct3            (func3_mem),
        .addr              (alu_result_mem),
        .write_data        (store_data_mem),
        .mem_write         (MemWrite_mem),
        .mem_read          (MemRead_mem),
        .router_read_data  (data_rdata_i),      
        .router_we         (data_wmask_o),      
        .router_write_data (data_wdata_o),      
        .lsu_out_data      (lsu_out_data_mem)   
    );
    assign data_addr_o = alu_result_mem;
    assign data_req_o  = MemWrite_mem | MemRead_mem;
    assign data_we_o   = MemWrite_mem;

    // MEM/WB 流水线寄存器
    wire [100:0] mem_wb_bus_in = {pc_plus_4_mem, lsu_out_data_mem, alu_result_mem, rd_mem};
    wire [2:0]   mem_wb_ctrl_in = ex_mem_ctrl_out[2:0]; // MemtoReg[1:0], RegWrite
    wire [100:0] mem_wb_bus_out;
    wire [2:0]   mem_wb_ctrl_out;

    pipe_reg #(.WIDTH(101)) mem_wb_data_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(mem_wb_stall), .pipe_reg_flush(1'b0), 
        .data_in(mem_wb_bus_in), .data_out(mem_wb_bus_out)
    );
    pipe_reg #(.WIDTH(3)) mem_wb_ctrl_reg (
        .clk(clk), .reset(~rst_n), .pipe_reg_stall(mem_wb_stall), .pipe_reg_flush(1'b0), 
        .data_in(mem_wb_ctrl_in), .data_out(mem_wb_ctrl_out)
    );

    // ==========================================
    // 6. WB 阶段: 写回
    // ==========================================
    wire [31:0] pc_plus_4_wb  = mem_wb_bus_out[100:69];
    wire [31:0] lsu_data_wb   = mem_wb_bus_out[68:37];
    wire [31:0] alu_result_wb = mem_wb_bus_out[36:5];
    assign      rd_wb         = mem_wb_bus_out[4:0];

    wire [1:0]  MemtoReg_wb   = mem_wb_ctrl_out[2:1];
    assign      reg_write_wb  = mem_wb_ctrl_out[0];
    
    // 终极写回 MUX[cite: 12]
    mux4 #(.WIDTH(32)) u_mux_wb (
        .in0 (alu_result_wb), // 00: 写回 ALU 结果
        .in1 (lsu_data_wb),   // 01: 写回内存读取结果
        .in2 (pc_plus_4_wb),  // 10: 写回 PC+4 (JAL/JALR)
        .in3 (32'b0),
        .sel (MemtoReg_wb),
        .out (wb_data)        
    );

endmodule