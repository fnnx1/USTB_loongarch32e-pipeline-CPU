`include "mycpu_defines.vh"

module EX_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        ms_allowin,  //握手信号
    output wire        es_allowin,  //该阶段是否k可以接收数据
    //from ds stage
    input  wire        ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD -1 :0] ds_to_es_bus,  //上一级缓冲区
    //to ms stage
    output wire        es_to_ms_valid,  //告知下一级数据是否有效
    output wire [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus,  //下一级缓冲区
    //to data sram
    output wire        data_sram_en,    //数据内存使能
    output wire [31:0] data_sram_addr,  //访问地址
    output wire [31:0] data_sram_wdata, //写入数据
    output wire [3:0]  data_sram_we     //数据内存对应字节访问使能
);
    //异常处理
    wire es_ex; //ex阶段的异常信号
    wire [5:0] es_excode; //ex阶段的异常码
    wire [8:0] es_esubcode; //ex阶段的异常子码
    
    wire ds_ex; //ds阶段的异常信号
    wire [5:0] ds_excode; //ds阶段的异常码
    wire [8:0] ds_esubcode; //ds阶段的异常子码

    //CSR相关信号
    wire [11:0] csr_write_num;
    wire [31:0] csr_wmask;
    wire csr_xchg;
    wire csr_re;
    wire csr_we;
    wire [31:0] _csr_rdata; //交换前
    wire [31:0] csr_wdata; //交换后
    reg es_valid;
    reg [`DS_TO_ES_BUS_WD -1 :0] ds_to_es_bus_r;
    wire es_ready_go;

    assign es_allowin      = !es_valid || es_ready_go && ms_allowin;
    assign es_to_ms_valid  = es_valid && es_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            es_valid <= 1'b0;
            ds_to_es_bus_r <= 0;
        end
        else if (es_allowin) begin
             es_valid <= ds_to_es_valid;
        end

        if (ds_to_es_valid && es_allowin) begin
            ds_to_es_bus_r <= ds_to_es_bus;
        end
    end

    wire inst_mod_wu;
    wire inst_mod_w;
    wire inst_div_wu;
    wire inst_div_w;
    wire load_signed;
    wire [1:0] mem_size;
    wire [14:0] alu_op;
    wire load_op;
    wire ex_gr_we;
    wire [4:0] dest;
    wire [31:0] alu_result;
    wire [31:0] final_result;
    wire [31:0] mul_result;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        src2_is_4;
    wire        mem_we;
    wire [31:0] imm;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] ds_pc;
    wire        res_from_mem;
    wire [31:0] sram_wdata;
    wire [3:0] sram_we;

    assign {
            csr_write_num,
            csr_wmask,
            csr_xchg,
            csr_re,
            csr_we,
            _csr_rdata,
            ds_ex,
            ds_excode,
            ds_esubcode,
            inst_mod_wu,
            inst_mod_w,
            inst_div_wu,
            inst_div_w,
            load_signed,
            mem_size,
            alu_op,
            load_op,
            src1_is_pc,
            src2_is_imm,
            src2_is_4,
            ex_gr_we,
            mem_we,
            dest,
            imm,
            rj_value,
            rkd_value,
            ds_pc,
            res_from_mem} = ds_to_es_bus_r;

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;


    alu _alu(
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );

    
    wire dividend_valid;
    wire divisor_valid;
    wire dividend_ready_signed;
    wire divisor_ready_signed;
    wire dividend_ready_unsigned;
    wire divisor_ready_unsigned;
    wire [63:0] div_result;
    wire div_result_valid;
    wire [63:0] div_result_unsigned;
    wire div_result_unsigned_valid;
    wire [63:0] div_result_signed;
    wire div_result_signed_valid;

    wire div_signed = inst_div_w || inst_mod_w;     //选择用哪个除法器
    wire div_unsigned = inst_div_wu || inst_mod_wu;
    reg div_input_sent;     //用于置valid为0
    wire div_input_fire;    //是否完成握手
    assign div_input_fire = dividend_valid && (div_signed ? dividend_ready_signed : dividend_ready_unsigned)
                        && divisor_valid  && (div_signed ? divisor_ready_signed : divisor_ready_unsigned);
    always @(posedge clk) begin
        if (reset) begin
            div_input_sent <= 1'b0;
        end
        else if (es_allowin) begin
            // 当前 EX 指令离开，或 EX 接收一条新指令；
            div_input_sent <= 1'b0;
        end
        else if (div_input_fire) begin
            div_input_sent <= 1'b1; // 当除法输入完成握手后，置div_input_sent为1,置valid为0
        end
    end

    assign dividend_valid = es_valid && (div_signed || div_unsigned) && !div_input_sent;
    assign divisor_valid  = es_valid && (div_signed || div_unsigned) && !div_input_sent;
    div_signed u_div_signed (
         .aclk                    (clk),
         .s_axis_dividend_tdata   (alu_src1),
         .s_axis_dividend_tvalid  (dividend_valid && div_signed),
         .s_axis_dividend_tready  (dividend_ready_signed),   // output
         .s_axis_divisor_tdata    (alu_src2),
         .s_axis_divisor_tvalid   (divisor_valid && div_signed),
         .s_axis_divisor_tready   (divisor_ready_signed),    // output
         .m_axis_dout_tdata       (div_result_signed),       // output
         .m_axis_dout_tvalid      (div_result_signed_valid)  // output
    );
    div_unsigned u_div_unsigned (
         .aclk                    (clk),
         .s_axis_dividend_tdata   (alu_src1),
         .s_axis_dividend_tvalid  (dividend_valid && div_unsigned),
         .s_axis_dividend_tready  (dividend_ready_unsigned),   // output
         .s_axis_divisor_tdata    (alu_src2),
         .s_axis_divisor_tvalid   (divisor_valid && div_unsigned),
         .s_axis_divisor_tready   (divisor_ready_unsigned),    // output
         .m_axis_dout_tdata       (div_result_unsigned),       // output
         .m_axis_dout_tvalid      (div_result_unsigned_valid)  // output
    );

    assign data_sram_en    = es_valid && (mem_we | res_from_mem | load_op);

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
    assign data_sram_we    = (es_valid & mem_we) ? sram_we : 4'b0;

    assign mem_addr_offset = alu_result[1:0];   //内存地址的偏移量

    assign es_ready_go = !div_signed && !div_unsigned || (div_signed && div_result_signed_valid) || (div_unsigned && div_result_unsigned_valid);
    wire [31:0] div_mod_result;
    assign div_mod_result = div_signed ? (inst_div_w ? div_result_signed[63:32] : (inst_mod_w ? div_result_signed[31:0] : alu_result)) 
                        : (div_unsigned ? (inst_div_wu ? div_result_unsigned[63:32] : (inst_mod_wu ? div_result_unsigned[31:0] : alu_result)) : alu_result);
    //csrxchange交换逻辑
    assign final_result = csr_xchg ? _csr_rdata : div_mod_result;
    assign csr_wdata = csr_xchg ? rkd_value : 32'h0;  
    // es_to_ms_bus 总位宽 = 203 bit
    assign es_to_ms_bus = {
                        csr_write_num ,  //[202:191] 12 bit  CSR写地址
                        csr_wmask    ,  //[190:159] 32 bit  CSR写掩码
                        csr_xchg      ,  //[158]      1 bit
                        csr_re        ,  //[157]      1 bit
                        csr_we        ,  //[156]      1 bit
                        csr_wdata     ,  //[155:124] 32 bit
                        es_ex,        //[123]     1  bit
                        es_excode,    //[122:117] 6  bit
                        es_esubcode,  //[116:108] 9 bit
                        load_signed,  //[107]     1 bit   加载的数据是否要进行有符号扩展
                        mem_size,    //[106:105] 2 bit   内存写入/读取的数据大小    
                        ex_gr_we     ,  //[104]     1 bit   写寄存器使能
                        dest         ,  //[103: 99] 5 bit   写寄存器地址
                            
                        load_op      ,  //[ 98]     1 bit   load指令
                        res_from_mem ,  //[ 97]     1 bit   结果是否来自内存

                        mem_we       ,  //[ 96]     1 bit   写内存使能
                        rkd_value    ,  //[ 95: 64] 32 bit  写内存数据
                        final_result   ,  //[ 63: 32] 32 bit  alu计算结果
                        ds_pc           //[ 31:  0] 32 bit  当前指令的pc,用于debug
                        };
endmodule