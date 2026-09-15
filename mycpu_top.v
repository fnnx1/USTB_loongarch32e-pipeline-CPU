/* fs: fetch stage
 * ds: decode stage
 * es: execute stage
 * ms: memory stage
 * ws: write back stage
 */
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
reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

wire [31:0] seq_pc;         //预计的下一个pc
wire [31:0] nextpc;         //真正的下个pc
wire        br_taken;       //是否要跳转
wire [31:0] br_target;      //跳转目标
wire [31:0] inst;           //指令
reg  [31:0] pc;             //pc

wire [11:0] alu_op;         //
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
wire        rj_eq_rd;

assign seq_pc       = pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else begin
        pc <= nextpc;
    end
end

// 取指
IF_stage if_stage(
    clk(clk), //时钟
    reset(resetn),   //复位
    ds_allowin(ds_allowin),  //告知是否下个阶段可以接受数据输入
    br_bus(br_bus), //
    fs_to_ds_valid(fs_to_ds_valid),
    fs_to_ds_bus(fs_to_ds_bus),
    // inst sram interface
    inst_sram_en(inst_sram_en),
    inst_sram_we(inst_sram_we),
    inst_sram_addr(inst_sram_addr),
    inst_sram_wdata(inst_sram_wdata),
    inst_sram_rdata(inst_sram_rdata)
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

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = (inst_ld_w || inst_st_w) && valid;
assign data_sram_we    = {4{mem_we && valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign rf_we    = gr_we && valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

endmodule
