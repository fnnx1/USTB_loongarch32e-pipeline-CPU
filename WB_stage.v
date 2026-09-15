module WB_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        ws_allowin,  //握手信号
    output wire        ms_allowin,  //该阶段是否k可以接收数据
    //from mem stage
    input  wire        ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus,  //上一级缓冲区
    //to rf :write back
    output wire [`WS_TO_RF_BUS_WD -1 :0] ws_to_rf_bus   //写回缓冲区
);

endmodule