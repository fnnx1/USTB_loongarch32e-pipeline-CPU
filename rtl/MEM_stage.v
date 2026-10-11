`include "mycpu_defines.vh"

module MEM_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        ws_allowin,  //握手信号(来自 ws 级)
    output wire        ms_allowin,  //该阶段是否可以接收数据
    //from es stage
    input  wire        es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus,  //上一级缓冲区
    //to rf :write back
    output wire        ms_to_ws_valid,  //告知下一级数据是否有效
    output wire [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus,  //写回缓冲区
    //内存访问端口
    input  wire [31:0] data_sram_rdata  //访存数据
);
    //异常处理
    wire mem_ex;
    wire [5:0] mem_excode;
    wire [8:0] mem_esubcode;

    wire es_ex;
    wire [5:0] es_excode;
    wire [8:0] es_esubcode;

    assign mem_ex = es_ex;
    assign mem_excode = es_excode;
    assign mem_esubcode = es_esubcode;

    //CSR相关
    wire [11:0] csr_write_num;
    wire [31:0] csr_wmask;
    wire csr_xchg;
    wire csr_we;
    wire [31:0] csr_wdata;
    reg mem_valid;
    reg [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus_r;
    wire ms_ready_go;
    /*assign es_to_mem_bus = {gr_we,  //写寄存器使能
                            dest,  //写寄存器地址
                            
                            load_op,  //load指令
                            res_from_mem,  //结果是否来自内存

                            mem_we,  //写内存使能
                            rkd_value,  //写内存数据
                            alu_result,  //alu计算结果
                            ds_pc  //当前指令的pc,用于debug
                            };*/
    assign ms_ready_go     = 1'b1;
    assign ms_allowin      = !mem_valid || ms_ready_go && ws_allowin;
    assign ms_to_ws_valid  = mem_valid && ms_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
            es_to_ms_bus_r <= 0;
        end
        else if (ms_allowin) begin
            mem_valid <= es_to_ms_valid;
        end

        if (es_to_ms_valid && ms_allowin) begin
            es_to_ms_bus_r <= es_to_ms_bus;
        end
    end
    wire         mem_we, gr_we,res_from_mem, load_op, load_signed;
    wire [1:0] mem_size ,mem_addr_offset;
    wire [4:0] dest;
    wire [31:0] rkd_value, alu_result, ds_pc, sram_wdata;
    wire [3:0] sram_we;
    assign {
            csr_write_num,
            csr_wmask,
            csr_xchg,
            csr_we,
            csr_wdata,
            es_ex,
            es_excode,
            es_esubcode,
            load_signed,  //load指令
            mem_size,
            gr_we,  //写寄存器使能
            dest,  //写寄存器地址
            
            load_op,  //load指令
            res_from_mem,  //结果是否来自内存

            mem_we,  //写内存使能
            rkd_value,  //写内存数据
            alu_result,  //alu计算结果
            ds_pc  //当前指令的pc,用于debug
            } = es_to_ms_bus_r;

    assign mem_addr_offset = alu_result[1:0];

    //load data from sram
    wire [7:0] sram_rdata_byte0, sram_rdata_byte1, sram_rdata_byte2, sram_rdata_byte3;  //字节选
    wire [15:0] sram_rdata_half0, sram_rdata_half1;  //半字选
    wire [7:0] sram_rdata_byte;
    wire [15:0] sram_rdata_half;

    assign sram_rdata_byte0 = data_sram_rdata[7:0];
    assign sram_rdata_byte1 = data_sram_rdata[15:8];
    assign sram_rdata_byte2 = data_sram_rdata[23:16];
    assign sram_rdata_byte3 = data_sram_rdata[31:24];
    assign sram_rdata_half0 = data_sram_rdata[15:0];
    assign sram_rdata_half1 = data_sram_rdata[31:16];

    assign sram_rdata_byte = mem_addr_offset == 2'b00 ? sram_rdata_byte0 :
                             mem_addr_offset == 2'b01 ? sram_rdata_byte1 :
                             mem_addr_offset == 2'b10 ? sram_rdata_byte2 :
                             sram_rdata_byte3;
    assign sram_rdata_half = mem_addr_offset[1] == 1'b0 ? sram_rdata_half0 :
                             sram_rdata_half1;

    wire [31:0] sram_rdata;
    wire debug_mem_size = mem_size == `B;
    wire debug_mem_size_H = mem_size == `H;
    assign sram_rdata = (mem_size == `B) ? (load_signed ? {{24{sram_rdata_byte[7]}}, sram_rdata_byte} : {24'b0, sram_rdata_byte}) :
                        (mem_size == `H) ? (load_signed ? {{16{sram_rdata_half[15]}}, sram_rdata_half} : {16'b0, sram_rdata_half}) :
                        data_sram_rdata;

    //访存请求只在本级有效时才发出
    /*assign data_sram_en    = mem_valid && (mem_we | res_from_mem | load_op);

    assign sram_wdata = mem_size == `B ? {4{rkd_value[7:0]}} :
                        mem_size == `H ? {2{rkd_value[15:0]}} :
                        rkd_value;
    assign sram_we    = mem_size == `B ? (alu_result[1:0] == 2'b00 ? 4'b0001 :
                                         alu_result[1:0] == 2'b01 ? 4'b0010 :
                                         alu_result[1:0] == 2'b10 ? 4'b0100 :
                                         4'b1000) :
                        mem_size == `H ? (alu_result[1] == 1'b0 ? 4'b0011 : 4'b1100):
                        4'b1111;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = sram_wdata;
    assign data_sram_we    = (mem_valid & mem_we) ? sram_we : 4'b0;

    assign mem_addr_offset = alu_result[1:0];   //内存地址的偏移量*/
    // ms_to_ws_bus 总位宽 = 166 bit
    wire [31:0] final_result;
    assign final_result = (res_from_mem | load_op) ? sram_rdata : alu_result;
    assign ms_to_ws_bus = {
                            csr_write_num ,  //[165:154] 12 bit  CSR写地址
                            csr_wmask    ,  //[153:122] 32 bit  CSR写掩码
                            csr_xchg      ,  //[121]      1 bit
                            csr_we        ,  //[120]      1 bit
                            csr_wdata     ,  //[119:88]  32 bit
                            mem_ex      ,  //[87]     异常标志
                            mem_excode  ,  //[86:81]  异常码
                            mem_esubcode,  //[80:72]  异常子码
                            load_op      ,  //[71]     load标志
                            gr_we        ,  //[70]     写寄存器使能
                            dest         ,  //[69:65]  写寄存器地址
                            res_from_mem ,
                            final_result ,  //[63:32]  写回数据(load/alu 已 mux)
                            ds_pc           //[31: 0]  当前指令的pc, 用于debug
                          };
endmodule