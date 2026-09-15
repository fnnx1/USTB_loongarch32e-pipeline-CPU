/* fs: fetch stage
 * ds: decode stage
 * es: execute stage
 * ms: memory stage
 * ws: write back stage
 */
`include "mycpu_defines.vh"

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3:0]  inst_sram_we,    //指令内存对应字节访问使能
    output wire        inst_sram_en,    // block Memory 使能
    output wire [31:0] inst_sram_addr,  //访问地址
    output wire [31:0] inst_sram_wdata, //写入数据
    input  wire [31:0] inst_sram_rdata, //读数据
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire        data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,         //pc值
    output wire [ 3:0] debug_wb_rf_we,      //写寄存器信号
    output wire [ 4:0] debug_wb_rf_wnum,    //写入的寄存器号
    output wire [31:0] debug_wb_rf_wdata    //写入数据
);
    assign reset = ~resetn; //复位信号


    /*wire [11:0] alu_op;         //
    wire        load_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        res_from_mem;
    wire        dst_is_r1;
    wire        gr_we;
    wire        mem_we;
    wire        src_reg_is_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    wire        rf_we   ;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;

    wire [31:0] alu_src1   ;
    wire [31:0] alu_src2   ;
    wire [31:0] alu_result ;

    wire [31:0] mem_result;
    wire [31:0] final_result;
    wire        rj_eq_rd;*/

    wire        ds_allowin, es_allowin, ms_allowin, ws_allowin;
    wire        fs_to_ds_valid, ds_to_es_valid, es_to_ms_valid, ms_to_ws_valid;

    wire [`BR_BUS_WD       -1:0] br_bus;
    wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
    wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
    wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
    wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
    wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;

    // 取指
    IF_stage if_stage(
        .clk(clk), //时钟
        .reset(reset),   //复位
        .ds_allowin(ds_allowin),  //告知是否下个阶段可以接受数据输入
        .br_bus(br_bus), //
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        // inst sram interface
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata)
    );

    // 译码
    ID_stage id_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .es_allowin(es_allowin),  //握手信号
        .ds_allowin(ds_allowin),  //该阶段是否k可以接收数据
        //from if stage
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        //to ex stage
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        //to if stage
        .br_bus(br_bus),
        //to rf :write back
        .ws_to_rf_bus(ws_to_rf_bus)
    );

    EX_stage ex_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ms_allowin(ms_allowin),  //握手信号
        .es_allowin(es_allowin),  //该阶段是否k可以接收数据
        //from ds stage
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),  //上一级缓冲区
        //to ms stage
        .es_to_ms_valid(es_to_ms_valid),  //告知下一级数据是否有效
        .es_to_ms_bus(es_to_ms_bus)       //下一级缓冲区
    );

    MEM_stage mem_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ws_allowin(ws_allowin),  //握手信号
        .ms_allowin(ms_allowin),  //该阶段是否可以接收数据
        //from es stage
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),  //上一级缓冲区
        //to ws stage
        .ms_to_ws_valid(ms_to_ws_valid),  //告知下一级数据是否有效
        .ms_to_ws_bus(ms_to_ws_bus),   //写回缓冲区
        // data sram interface
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata)
    );

    WB_stage wb_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ws_allowin(ws_allowin),  //该阶段是否k可以接收数据
        //from ms stage
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),  //上一级缓冲区
        //to rf :write back
        .ws_to_rf_bus(ws_to_rf_bus),   //写回缓冲区
        // trace debug interface
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule
