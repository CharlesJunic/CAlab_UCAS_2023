`ifndef __MYCPU_DEFINE__
`define __MYCPU_DEFINE__
//crmd
    `define CSR_CRMD            14'h0000
    `define CSR_CRMD_PLV        1:0
    `define CSR_CRMD_IE         2
    `define CSR_CRMD_DA         3
    `define CSR_CRMD_PG         4
    `define CSR_CRMD_DATF       6:5
    `define CSR_CRMD_DATM       8:7
//prmd
    `define CSR_PRMD            14'h0001
    `define CSR_PRMD_PPLV       1:0
    `define CSR_PRMD_PIE        2
//euen
    `define CSR_EUEN            14'h0002
    `define CSR_EUEN_FPE        0
//ecfg
    `define CSR_ECFG            14'h0004
    `define CSR_ECFG_LIE        12:0
//estat
    `define CSR_ESTAT           14'h0005
    `define CSR_ESTAT_IS10      1:0
    `define CSR_ESTAT_ECODE     21:16
    `define CSR_ESTAT_ESUBCODE  30:22
//era
    `define CSR_ERA             14'h0006
    `define CSR_ERA_PC          31:0
//badv
    `define CSR_BADV            14'h0007
    `define CSR_BADV_VADDR      31:0
//eentry
    `define CSR_EENTRY          14'h000c
    `define CSR_EENTRY_VA       31:6
//tlbidx
    `define CSR_TLBIDX          14'h0010
    `define CSR_TLBIDX_INDEX    3:0
    `define CSR_TLBIDX_PS       29:24
    `define CSR_TLBIDX_NE       31
//tlbehi
    `define CSR_TLBEHI          14'h0011
    `define CSR_TLBEHI_VPPN     31:13
//tlbelo0/1
    `define CSR_TLBELO0         14'h0012
    `define CSR_TLBELO1         14'h0013
    `define CSR_TLBELO_V        0
    `define CSR_TLBELO_D        1
    `define CSR_TLBELO_PLV      3:2
    `define CSR_TLBELO_MAT      5:4
    `define CSR_TLBELO_G        6
    `define CSR_TLBELO_PPN      27:8
//asid
    `define CSR_ASID            14'h0018
    `define CSR_ASID_ASID       9:0
    `define CSR_ASID_ASIDBITS   23:16
//pgdl/pgdh/pgd
    `define CSR_PGDL            14'h0019
    `define CSR_PGDH            14'h001A
    `define CSR_PGD             14'h001B
    `define CSR_PGD_BASE        31:12
//cpuid
    `define CSR_CPUID           14'h0020
    `define CSR_CPUID_COREID    8:0
//save0/save1/save2/save3
    `define CSR_SAVE0           14'h0030
    `define CSR_SAVE1           14'h0031
    `define CSR_SAVE2           14'h0032
    `define CSR_SAVE3           14'h0033
    `define CSR_SAVE_DATA       31:0
//tid
    `define CSR_TID             14'h0040
    `define CSR_TID_TID         31:0
//tcfg
    `define CSR_TCFG            14'h0041
    `define CSR_TCFG_EN         0
    `define CSR_TCFG_PERIOD     1
    `define CSR_TCFG_INITV      31:2
//tval
    `define CSR_TVAL            14'h0042
    `define CSR_TVAL_TVAL       31:0
//ticlr
    `define CSR_TICLR           14'h0044
    `define CSR_TICLR_CLR       0
//llbctl
    `define CSR_LLBCTL          14'h0060
    `define CSR_LLBCTL_ROLLB    0
    `define CSR_LLBCTL_WCLLB    1
    `define CSR_LLBCTL_KLO      2
//tlbrentry
    `define CSR_TLBRENTRY       14'h0088
    `define CSR_TLBRENTRY_PA    31:6
//ctag
    `define CSR_CTAG            14'h0098
//dmw0/dmw1
    `define CSR_DMW0            14'h0180
    `define CSR_DMW1            14'h0181
    `define CSR_DMW_PLV0        0
    `define CSR_DMW_PLV3        3
    `define CSR_DMW_MAT         5:4
    `define CSR_DMW_PSEG        27:25
    `define CSR_DMW_VSEG        31:29
//exc code
    `define ECODE_INT           6'h00
    `define ECODE_PIL           6'h01
    `define ECODE_PIS           6'h02
    `define ECODE_PIF           6'h03
    `define ECODE_PME           6'h04
    `define ECODE_PPI           6'h07
    `define ECODE_ADE           6'h08
    `define ESUBCODE_ADEF       9'h000
    `define ESUBCODE_ADEM       9'h001
    `define ECODE_ALE           6'h09
    `define ECODE_SYS           6'h0b
    `define ECODE_BRK           6'h0c
    `define ECODE_INE           6'h0d
    `define ECODE_IPE           6'h0e
    `define ECODE_FPD           6'h0f
    `define ECODE_FPE           6'h12
    `define ECODE_TLBR          6'h3f
`endif