`ifndef MYCPU_DEFINES_VH
`define MYCPU_DEFINES_VH

    //前递宽度
    `define BR_BUS_WD       33

    //各阶段总线宽度定义
    `define FS_TO_DS_BUS_WD 80
    `define DS_TO_ES_BUS_WD 178
    `define ES_TO_MS_BUS_WD 124
    `define MS_TO_WS_BUS_WD 88
    `define WS_TO_RF_BUS_WD 55

    //访存字节数
    `define B 2'b01
    `define H 2'b10
    `define W 2'b11

    //异常类型
    `define ECODE_INT 6'h00
    `define ECODE_PIL 6'h01
    `define ECODE_PIS 6'h02
    `define ECODE_PIF 6'h03
    `define ECODE_PME 6'h04


    `define ECODE_PPI 6'h07
    `define ECODE_ADE 6'h08
    `define ECODE_ALE 6'h09
    `define ECODE_BCE 6'h0A
    `define ECODE_SYS 6'h0B
    `define ECODE_BRK 6'h0C
    `define ECODE_INE 6'h0D
    `define ECODE_IPE 6'h0E
    `define ECODE_FPE 6'h0F
    `define ECODE_TLBR 6'h3F

    `define ESUBCODE_ADEF 9'h000
    `define ESUBCODE_ADEM 9'h001
`endif