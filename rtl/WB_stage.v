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
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
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

    assign ws_to_rf_bus = {ws_valid && ms_to_ws_bus_r[69],  //[37]    写寄存器使能
                           ms_to_ws_bus_r[68:64],           //[36:32] 写寄存器地址
                           ms_to_ws_bus_r[63:32]            //[31: 0] 写回数据
                          };

    // debug info generate
    assign debug_wb_pc       = ws_valid ? ms_to_ws_bus_r[31:0] : 32'b0;
    assign debug_wb_rf_we    = {4{ws_valid && ms_to_ws_bus_r[69]}};
    assign debug_wb_rf_wnum  = ws_valid ? ms_to_ws_bus_r[68:64] : 5'b0;
    assign debug_wb_rf_wdata = ws_valid ? ms_to_ws_bus_r[63:32] : 32'b0;
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
        else begin
            ms_to_ws_bus_r <= 0;
        end
    end
endmodule