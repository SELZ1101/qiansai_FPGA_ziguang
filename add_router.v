module add_router
(
    input  wire        clk,
    input  wire        rst_n,

    // ==========================================
    // 2. CPU 端接口 (Master - 来自 LSU 或 IFU)
    // ==========================================
    input  wire [31:0] cpu_addr_i,   // 32位请求地址
    input  wire        cpu_req_i,    // 访存请求有效信号
    input  wire        cpu_we_i,     // 写使能 (1: Write, 0: Read)
    input  wire [ 3:0] cpu_wmask_i,  // 字节掩码 (支持字节、半字、字写入),接收设备需要掩码来判断哪几位是有效的
    input  wire [31:0] cpu_wdata_i,  // 写数据
    
    output reg  [31:0] cpu_rdata_o,  // 返回给 CPU 的读数据
    output reg         cpu_rvalid_o, // 读数据有效信号响应
)