`include "mycpu_defines.vh"

module IF_stage(
    input wire clk, //时钟
    input wire reset,   //复位
    input wire ds_allowin,  //告知是否下个阶段可以接受数据输入
    input wire [`BR_BUS_WD -1 :0] br_bus, //跳转信号
    output wire fs_to_ds_valid,     //告知下个阶段数据是否有效
    output wire [`FS_TO_DS_BUS_WD-1 :0] fs_to_ds_bus,   //传递给下一级的缓冲区
    // inst sram interface
    output wire inst_sram_en,
    output wire [3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    input wire [31:0] ex_pc,
    input wire has_ex,  //无条件例外
    input wire int_flush,
    input wire ertn_flush,
    input wire [31:0] ertn_entry
);
    //异常输出处理
    wire if_ex; //if阶段的异常信号
    wire [5:0] if_ecode; //if阶段的异常码
    wire [8:0] if_esubcode; //if阶段的异常子码

    assign if_ex = 1'b0; //暂时没有异常处理
    assign if_ecode = 6'b0;
    assign if_esubcode = 9'b0;


    //if级握手信号
    reg         fs_valid;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire        to_fs_valid;

    wire [31:0] seq_pc; //顺序的地址
    wire [31:0] next_pc; //下一个执行的地址，可能会跳转

    wire br_taken; //跳转信号
    wire [31:0] br_target;//跳转地址

    assign {br_taken,br_target} = br_bus; //跳转信号传递

    wire [31:0] fs_inst; //fs阶段的inst和pc,往后传递
    reg [31:0] fs_pc;

    //if向id传递的bus
    // fs_to_ds_bus 总位宽 = 1+6+9+32+32 = 80 bit
    assign fs_to_ds_bus = {if_ex,        // [79]
                           if_ecode,     // [78:73]
                           if_esubcode,  // [72:64]
                           fs_inst,      // [63:32]
                           fs_pc};       // [31:0]

    //pre-if stage
    assign to_fs_valid = ~reset;
    assign seq_pc = fs_pc + 3'h4; //顺序
    //哇恶意满满啊，后面甚至接着的第二个周期是个跳转指令，你无敌了计组课设
    assign next_pc = (has_ex || int_flush) ? ex_pc :
                    (ertn_flush) ? ertn_entry :
                    (br_taken == 1 ) ? br_target :
                    seq_pc;

    //IF stage
    assign fs_ready_go = 1'b1; //可以传输
    assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin; 
    //允许进入，需要了解下一级是否可以进入目的是可以实现保持停顿
    //br_taken 有效时, 本拍正要送往 ds 的那条指令属于跳转后的顺序路径(错误路径), 必须作废
    assign fs_to_ds_valid = fs_valid && fs_ready_go && !br_taken;

    always@(posedge clk)begin
        if(reset)begin
            fs_valid <= 1'b0;
        end else if(fs_allowin)begin
            fs_valid <= to_fs_valid;
        end
    end

    always@(posedge clk)begin
        if(reset)begin
            fs_pc <= 32'h1bfffffc;
        end else if(to_fs_valid && fs_allowin)begin
            fs_pc <= next_pc;
        end 
    end

    assign inst_sram_en = to_fs_valid && fs_allowin;
    assign inst_sram_we = 4'h0;
    assign inst_sram_addr = next_pc;
    assign inst_sram_wdata = 32'b0;

    assign fs_inst = inst_sram_rdata;

endmodule
