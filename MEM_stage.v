module MEM_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    //input  wire        wb_allowin,  //握手信号
    output wire        mem_allowin,  //该阶段是否k可以接收数据
    //from mem stage
    input  wire        ms_to_ws_valid,
    input  wire [`DS_TO_EX_BUS_WD -1 :0] es_to_mem_bus,  //上一级缓冲区
    //to rf :write back
    output wire        ms_to_es_valid,  //告知下一级数据是否有效
    output wire [`ES_TO_RF_BUS_WD -1 :0] mem_to_ws_bus   //写回缓冲区
    //内存访问端口
    output wire [3:0]  inst_sram_we,    //指令内存对应字节访问使能
    output wire        inst_sram_en,    // block Memory 使能
    output wire [31:0] inst_sram_addr,  //访问地址
    output wire [31:0] inst_sram_wdata, //写入数据
    input  wire [31:0] inst_sram_rdata, //读数据
);
    /*assign es_to_mem_bus = {gr_we,  //写寄存器使能
                            dest,  //写寄存器地址
                            
                            load_op,  //load指令
                            res_from_mem,  //结果是否来自内存

                            mem_we,  //写内存使能
                            rkd_value,  //写内存数据
                            alu_result,  //alu计算结果
                            ds_pc  //当前指令的pc,用于debug
                            };*/
    assign mem_ready_go    = 1'b1;
    assign mem_allowin      = !mem_valid || mem_ready_go /*&& wb_allowin*/;
    assign mem_to_ws_valid  = mem_valid && mem_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
        end
        else if (mem_allowin) begin
            mem_valid <= es_to_mem_valid;
        end

        if (es_to_mem_valid && mem_allowin) begin
            es_to_mem_bus_r <= es_to_mem_bus;
        end
    end
    assign mem_to_ws_bus = {gr_we,  //写寄存器使能
                            dest,  //写寄存器地址

                            res_from_mem,  //结果是否来自内存
                            inst_sram_rdata,  //内存读取结果计算结果
                            ds_pc  //当前指令的pc,用于debug
                            };
endmodule