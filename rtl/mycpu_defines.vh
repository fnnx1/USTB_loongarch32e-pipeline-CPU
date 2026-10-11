`ifndef MYCPU_DEFINES_VH
`define MYCPU_DEFINES_VH

    //总线位宽：前递 1+32=33
    `define BR_BUS_WD       33

    //各级总线位宽：FS->DS 1+6+9+32+32=80
    `define FS_TO_DS_BUS_WD 80
    //DS->ES 12+32+1+1+32+1+6+9+1+1+1+1+1+2+15+1+1+1+1+1+1+5+32+32+32+32+1=256
    `define DS_TO_ES_BUS_WD 256
    //ES->MS 12+32+1+1+32+1+6+9+1+2+1+5+1+1+1+32+32+32=202
    `define ES_TO_MS_BUS_WD 202
    //MS->WS 12+32+1+1+32+1+6+9+1+1+5+1+32+32=166
    `define MS_TO_WS_BUS_WD 166
    //WS->RF 1+1+32+1+6+9+1+1+5+32=89
    `define WS_TO_RF_BUS_WD 89
    //WS->CSR 12+32+1+1+32=78
    `define WS_TO_CSR_BUS_WD 78

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