`include "mycpu_defines.vh"

module WB_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    output wire        ws_allowin,  //该阶段是否可以接收数据(最后一级, 恒为1)
    //from ms stage
    input  wire        ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus,  //上一级缓冲区
    //to rf :write back
    output wire [`WS_TO_RF_BUS_WD -1 :0] ws_to_rf_bus,  //写回缓冲区
    output wire [`WS_TO_CSR_BUS_WD -1 :0] ws_to_csr_bus,  //写回CSR缓冲区
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    input  wire        ws_to_rf_valid
    
);
    //异常处理
    wire ws_ex;
    wire [5:0] ws_excode;
    wire [8:0] ws_esubcode;
    
    wire [11:0] csr_write_num;
    wire [31:0] csr_wmask;
    wire csr_xchg;
    wire csr_re;
    wire csr_we;
    wire [31:0] csr_wdata;
    reg ws_valid;
    reg [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus_r;
    wire ws_ready_go;
    /*assign es_to_mem_bus = {gr_we,  //写寄存器使能
                            dest,  //写寄存器地址
                            
                            load_op,  //load指令
                            res_from_mem,  //结果是否来自内存

                            mem_we,  //写内存使能
                            rkd_value,  //写内存数据
                            alu_result,  //alu计算结果
                            ds_pc  //当前指令的pc,用于debug
                            };*/
    assign ws_ready_go     = 1'b1;
    //最后一级, 没有下游 allowin
    assign ws_allowin      = !ws_valid || ws_ready_go;

   
    // ws_to_rf_bus 总位宽 = 1+1+1+32+1+6+9+1+1+5+32 = 90 bit
    assign ws_to_rf_bus = {
                        csr_xchg,       //[89]
                        csr_re,         //[88]
                        csr_we,         //[87]
                        csr_wdata,      //[86:55]
                        ws_ex,          //[54]
                        ws_excode,      //[53:48]
                        ws_esubcode,    //[47:39]
                        ws_valid && ms_to_ws_bus_r[71],  //[38]    load标志
                        ws_valid && ms_to_ws_bus_r[70],  //[37]    写寄存器使能
                        ms_to_ws_bus_r[69:65],           //[36:32] 写寄存器地址
                        ms_to_ws_bus_r[63:32]//[31: 0] 写回数据
                        };
    // ws_to_csr_bus 总位宽 = 12+32+1+1+1+32 = 79 bit
    assign ws_to_csr_bus = {
                            csr_write_num,  //[78:67]
                            csr_wmask,      //[66:35]
                            csr_xchg,       //[34]
                            csr_re,         //[33]
                            csr_we,         //[32]
                            csr_wdata       //[31:0]
                            };

    assign ws_ex = ms_to_ws_bus_r[87];
    assign ws_excode = ms_to_ws_bus_r[86:81];
    assign ws_esubcode = ms_to_ws_bus_r[80:72];
    assign csr_xchg = ms_to_ws_bus_r[122];
    assign csr_re = ms_to_ws_bus_r[121];
    assign csr_we = ws_valid && ms_to_ws_bus_r[120];
    assign csr_wdata = ms_to_ws_bus_r[119:88];
    assign csr_wmask = ms_to_ws_bus_r[154:123];
    assign csr_write_num = ms_to_ws_bus_r[166:155];
    assign ws_to_rf_valid = ws_valid;
    // debug info generate
    assign debug_wb_pc       = ws_valid ? ms_to_ws_bus_r[31:0] : 32'b0;
    assign debug_wb_rf_we    = {4{ws_valid && ms_to_ws_bus_r[70]}};
    assign debug_wb_rf_wnum  = ws_valid ? ms_to_ws_bus_r[69:65] : 5'b0;
    assign debug_wb_rf_wdata = ws_valid ? ws_to_rf_bus[31:0] : 32'b0;
    always @(posedge clk) begin
        if (reset) begin
            ws_valid <= 1'b0;
            ms_to_ws_bus_r <= 0;
        end
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end

        if (ms_to_ws_valid && ws_allowin) begin
            ms_to_ws_bus_r <= ms_to_ws_bus;
        end
    end
endmodule