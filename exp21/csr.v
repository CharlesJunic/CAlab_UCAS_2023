module csr (
    input  wire        clk,
    input  wire        reset,
    input  wire        csr_re,               
    input  wire [13:0] csr_num,        
    output wire [31:0] csr_rvalue,     
    input  wire        csr_we,                 
    input  wire [31:0] csr_wmask,    
    input  wire [31:0] csr_wvalue,       
    input  wire [31:0] WB_pc,
    input  wire        wb_ex,                    
    input  wire [ 5:0] wb_ecode,        
    input  wire [ 8:0] wb_esubcode,        
    input  wire [31:0] wb_vaddr,
    input  wire        ertn_flush,             
    output wire        has_int,             
    output wire [31:0] ex_entry,         
    input  wire [ 7:0] hw_int_in,          
    input  wire        ipi_int_in,
    input  wire [31:0] coreid_in,
//tlbrd
    output wire [ 3:0] r_index,
    input  wire        tlbrd_we,
    input  wire        r_e,
    input  wire [18:0] r_vppn,
    input  wire [ 5:0] r_ps,
    input  wire [ 9:0] r_asid,
    input  wire        r_g,
    input  wire [19:0] r_ppn0,
    input  wire [ 1:0] r_plv0,
    input  wire [ 1:0] r_mat0,
    input  wire        r_d0,
    input  wire        r_v0,
    input  wire [19:0] r_ppn1,
    input  wire [ 1:0] r_plv1,
    input  wire [ 1:0] r_mat1,
    input  wire        r_d1,
    input  wire        r_v1,
//tlbwr
    output reg  [ 3:0] csr_tlbidx_index,
    output reg         csr_tlbidx_ne,
    output reg  [18:0] csr_tlbehi_vppn,
    output reg  [ 5:0] csr_tlbidx_ps,
    output reg  [ 9:0] csr_asid_asid,
    output reg         csr_tlbelo0_g,
    output reg  [19:0] csr_tlbelo0_ppn,
    output reg  [ 1:0] csr_tlbelo0_plv,
    output reg  [ 1:0] csr_tlbelo0_mat,
    output reg         csr_tlbelo0_d,
    output reg         csr_tlbelo0_v,
    output reg         csr_tlbelo1_g,
    output reg  [19:0] csr_tlbelo1_ppn,
    output reg  [ 1:0] csr_tlbelo1_plv,
    output reg  [ 1:0] csr_tlbelo1_mat,
    output reg         csr_tlbelo1_d,
    output reg         csr_tlbelo1_v,
//tlbsrch
    input  wire        tlbsrch_en,
    input  wire        tlbsrch_hit,
    input  wire [ 3:0] tlbsrch_index,
//crmd
    output reg  [ 1:0] csr_crmd_plv,
    output reg         csr_crmd_da,
    output reg         csr_crmd_pg,
//dmw0
    output reg         csr_dmw0_plv0,
    output reg         csr_dmw0_plv3,
    output reg  [ 1:0] csr_dmw0_mat,
    output reg  [ 2:0] csr_dmw0_pseg,
    output reg  [ 2:0] csr_dmw0_vseg,
//dmw1
    output reg         csr_dmw1_plv0,
    output reg         csr_dmw1_plv3,
    output reg  [ 1:0] csr_dmw1_mat,
    output reg  [ 2:0] csr_dmw1_pseg,
    output reg  [ 2:0] csr_dmw1_vseg,
    output reg  [ 1:0] csr_crmd_datf,
    output reg  [ 1:0] csr_crmd_datm
);

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

reg         csr_crmd_ie;
// datf/datm remove to output
reg  [ 1:0] csr_prmd_pplv;
reg         csr_prmd_pie;
// reg         csr_euen_fpe;
reg  [12:0] csr_ecfg_lie;
reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
reg  [31:0] csr_era_pc;
reg  [31:0] csr_badv_vaddr;
wire        wb_ex_addr_err;
wire        wb_tlb_addr_err;
reg  [25:0] csr_eentry_va;
// reg [31:12] csr_pgdl_base;
// reg [31:12] csr_pgdh_base;
// reg [31:12] csr_pgd_base;
reg  [31:0] csr_save0_data;
reg  [31:0] csr_save1_data;
reg  [31:0] csr_save2_data;
reg  [31:0] csr_save3_data;
reg  [31:0] csr_tid_tid;
reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
reg  [31:0] timer_cnt;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
wire        csr_ticlr_clr;
// reg         csr_llbctl_rollb;
// reg         csr_llbctl_wcllb;
// reg         csr_llbctl_klo;
reg  [25:0] csr_tlbrentry_pa;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_tlbidx_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_tlbelo0_rvalue;
wire [31:0] csr_tlbelo1_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_ticlr_rvalue;
wire [31:0] csr_tlbrentry_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;

wire [12:0] int_vec;

//CRMD
    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    //PLV
    always @(posedge clk) begin
        if(reset)
            csr_crmd_plv <= 2'b0;
        else if(wb_ex)
            csr_crmd_plv <= 2'b0;
        else if(ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                        |  ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
    end
    //IE
    always @(posedge clk) begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end
    //DA
    always @(posedge clk)begin
        if(reset)
            csr_crmd_da <= 1'b1;
        else if(wb_ex && (wb_ecode == `ECODE_TLBR))
            csr_crmd_da <= 1'b1;
        else if(ertn_flush && (csr_estat_ecode == 6'h3f))
            csr_crmd_da <= 1'b0;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                        | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
    end
    //PG
    always @(posedge clk)begin
        if(reset)
            csr_crmd_pg <= 1'b0;
        else if(wb_ex && (wb_ecode == `ECODE_TLBR))
            csr_crmd_pg <= 1'b0;
        else if(ertn_flush && (csr_estat_ecode == 6'h3f))
            csr_crmd_pg <= 1'b1;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                        | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
    end
    //DATF & DATM
    always @(posedge clk)begin
        if(reset) begin
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if(csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                        | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                        | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
        end
    end

//PRMD
    assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    //PPLV & PIE
    always @(posedge clk) begin
        if(wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if(csr_we && csr_num == `CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                        |  ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                        |  ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
    end

//EUEN
    //FPE

//ECFG
    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie[12:11], 1'b0, csr_ecfg_lie[9:0]};
    //LIE
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we & csr_num == `CSR_ECFG) 
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                        |  ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end

//ESTAT
    assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    //IS
    always @(posedge clk) begin
        if(reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                            |   ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[`CSR_ESTAT_IS10];
        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;
        csr_estat_is[12] <= ipi_int_in;
    end      
    //ECODE & ESUBCODE
    always @(posedge clk) begin
        if(wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end      

//ERA
    assign csr_era_rvalue = csr_era_pc;
    //PC
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_pc <= WB_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end    

//BADV
    assign csr_badv_rvalue = csr_badv_vaddr;
    assign wb_ex_addr_err = wb_ecode == `ECODE_ALE || wb_ecode == `ECODE_ADE || wb_tlb_addr_err;
    //VADDR
    always @(posedge clk) begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE &&
                               wb_esubcode == `ESUBCODE_ADEF) ? WB_pc : wb_vaddr;
    end

//EENTRY
    assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};
    //VA
    always @(posedge clk) begin
        if(csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end

//TLBIDX
    assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
    assign r_index           = csr_tlbidx_index;
    //INDEX
    always @(posedge clk)begin
        if (reset)
            csr_tlbidx_index <= 4'b0;
        else if (tlbrd_we & r_e)
            csr_tlbidx_index <= r_index;
        else if (tlbsrch_en & tlbsrch_hit)
            csr_tlbidx_index <= tlbsrch_index;
        else if (csr_we && csr_num == `CSR_TLBIDX)
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX] |
                               ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
    end
    //PS
    always @(posedge clk)begin
        if (reset | (tlbrd_we & ~r_e))
            csr_tlbidx_ps <= 6'b0;
        else if (tlbrd_we & r_e)
            csr_tlbidx_ps <= r_ps;
        else if (csr_we && csr_num == `CSR_TLBIDX)
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS] |
                            ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
    end
    //NE
    always @(posedge clk)begin
        if (reset)
            csr_tlbidx_ne <= 1'b1;
        else if (tlbrd_we)
            csr_tlbidx_ne <= ~r_e;
        else if (tlbsrch_en)
            csr_tlbidx_ne <= ~tlbsrch_hit;
        else if (csr_we && csr_num == `CSR_TLBIDX)
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE] |
                            ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
    end

//TLBEHI
    assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
    assign wb_tlb_addr_err = wb_ecode == `ECODE_PIL || wb_ecode == `ECODE_PIS
                          || wb_ecode == `ECODE_PIF || wb_ecode == `ECODE_PPI
                          || wb_ecode == `ECODE_PME || wb_ecode == `ECODE_TLBR;
    //VPPN
    always @(posedge clk) begin
        if (reset | (tlbrd_we & ~r_e))
            csr_tlbehi_vppn <= 19'b0;
        else if (tlbrd_we & r_e)
            csr_tlbehi_vppn <= r_vppn;
        else if (wb_ex & wb_tlb_addr_err)
            csr_tlbehi_vppn <= wb_vaddr[31:13];
        else if (csr_we & csr_num == `CSR_TLBEHI)
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN] |
                              ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
    end

//TLBELO0
    assign csr_tlbelo0_rvalue = {4'b0, csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, 
                                csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    //V, D, PLV, MAT, G, PPN
    always @(posedge clk) begin
        if (reset | (tlbrd_we & ~r_e)) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 20'b0;
        end
        else if (tlbrd_we & r_e) begin
            csr_tlbelo0_v   <= r_v0;
            csr_tlbelo0_d   <= r_d0;
            csr_tlbelo0_plv <= r_plv0;
            csr_tlbelo0_mat <= r_mat0;
            csr_tlbelo0_g   <= r_g;
            csr_tlbelo0_ppn <= r_ppn0;
        end
        else if (csr_we & csr_num == `CSR_TLBELO0) begin
            csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V  ] & csr_wvalue[`CSR_TLBELO_V  ] |
                              ~csr_wmask[`CSR_TLBELO_V  ] & csr_tlbelo0_v;
            csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D  ] & csr_wvalue[`CSR_TLBELO_D  ] |
                              ~csr_wmask[`CSR_TLBELO_D  ] & csr_tlbelo0_d;
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                              ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                              ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
            csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G  ] & csr_wvalue[`CSR_TLBELO_G  ] |
                              ~csr_wmask[`CSR_TLBELO_G  ] & csr_tlbelo0_g;
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                              ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        end
    end

//TLBELO1
    assign csr_tlbelo1_rvalue = {4'b0, csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, 
                                csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    //V, D, PLV, MAT, G, PPN
    always @(posedge clk) begin
        if (reset | (tlbrd_we & ~r_e)) begin
            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 20'b0;
        end
        else if (tlbrd_we & r_e) begin
            csr_tlbelo1_v   <= r_v1;
            csr_tlbelo1_d   <= r_d1;
            csr_tlbelo1_plv <= r_plv1;
            csr_tlbelo1_mat <= r_mat1;
            csr_tlbelo1_g   <= r_g;
            csr_tlbelo1_ppn <= r_ppn1;
        end
        else if (csr_we & csr_num == `CSR_TLBELO1) begin
            csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V  ] & csr_wvalue[`CSR_TLBELO_V  ] |
                              ~csr_wmask[`CSR_TLBELO_V  ] & csr_tlbelo1_v;
            csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D  ] & csr_wvalue[`CSR_TLBELO_D  ] |
                              ~csr_wmask[`CSR_TLBELO_D  ] & csr_tlbelo1_d;
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                              ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                              ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
            csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G  ] & csr_wvalue[`CSR_TLBELO_G  ] |
                              ~csr_wmask[`CSR_TLBELO_G  ] & csr_tlbelo1_g;
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                              ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        end
    end

//ASID
    assign csr_asid_rvalue = {8'd0, 8'd10, 6'd0, csr_asid_asid};
    //ASID
    always @(posedge clk) begin
        if (reset | (tlbrd_we & ~r_e)) begin
            csr_asid_asid <= 10'd0;
        end
        else if (tlbrd_we & r_e) begin
            csr_asid_asid <= r_asid;
        end
        else if (csr_we & csr_num == `CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID] |
                            ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
    end
    //ASIDBITS

//PGDL
    //BASE

//PGDH
    //BASE

//PGD
    //BASE

//CPUID
    //CoreID

//SAVE0~3
    assign csr_save0_rvalue = csr_save0_data;
    assign csr_save1_rvalue = csr_save1_data;
    assign csr_save2_rvalue = csr_save2_data;
    assign csr_save3_rvalue = csr_save3_data;
    //DATA
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

//TID
    assign csr_tid_rvalue = csr_tid_tid;
    //TID
    always @(posedge clk)begin
        if(reset)
            csr_tid_tid <= coreid_in;
        else if(csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

//TCFG
    assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    //EN, Periodic, InitVal
    always @(posedge clk) begin
        if(reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV ] & csr_wvalue[`CSR_TCFG_INITV ]
                              | ~csr_wmask[`CSR_TCFG_INITV ] & csr_tcfg_initval;
        end
    end

//TVAL
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                          | ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    //TimeVal
    always @(posedge clk) begin
        if(reset)
            timer_cnt <= 32'hffffffff;
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end
    assign csr_tval = timer_cnt[31:0];

//TICLR
    assign csr_ticlr_rvalue = {30'b0, csr_ticlr_clr};
    //CLR
    assign csr_ticlr_clr = 1'b0;

//LLBCTL
    //ROLLB
    //WCLLB
    //KLO

//TLBRENTRY
    assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0};
    //PA
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbrentry_pa <= 26'b0;
        end
        else if (csr_we & csr_num == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                             | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;  
        end
    end

//CTAG

//DMW0
    assign csr_dmw0_rvalue = {csr_dmw0_pseg[2:0], 1'b0, csr_dmw0_vseg[2:0], 19'b0, csr_dmw0_mat[1:0],
                              csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    //PLV0, PLV3, MAT, PSEG, VSEG
    always @(posedge clk) begin
        if(reset) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
            csr_dmw0_mat  <= 2'b0;
            csr_dmw0_pseg <= 3'b0;
            csr_dmw0_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                          | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                          | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3;
            csr_dmw0_mat  <= csr_wmask[`CSR_DMW_MAT ] & csr_wvalue[`CSR_DMW_MAT ]
                          | ~csr_wmask[`CSR_DMW_MAT ] & csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                          | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                          | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;
        end
    end
//DMW1
    assign csr_dmw1_rvalue = {csr_dmw1_pseg[2:0], 1'b0, csr_dmw1_vseg[2:0], 19'b0, csr_dmw1_mat[1:0],
                              csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    //PLV0, PLV3, MAT, PSEG, VSEG
    always @(posedge clk) begin
        if(reset) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
            csr_dmw1_mat  <= 2'b0;
            csr_dmw1_pseg <= 3'b0;
            csr_dmw1_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                          | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                          | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3;
            csr_dmw1_mat  <= csr_wmask[`CSR_DMW_MAT ] & csr_wvalue[`CSR_DMW_MAT ]
                          | ~csr_wmask[`CSR_DMW_MAT ] & csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                          | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                          | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;
        end
    end

//rvalue
    assign csr_rvalue = {32{csr_num == `CSR_CRMD     }} & csr_crmd_rvalue
                      | {32{csr_num == `CSR_PRMD     }} & csr_prmd_rvalue
                      | {32{csr_num == `CSR_ECFG     }} & csr_ecfg_rvalue
                      | {32{csr_num == `CSR_ESTAT    }} & csr_estat_rvalue
                      | {32{csr_num == `CSR_ERA      }} & csr_era_rvalue
                      | {32{csr_num == `CSR_BADV     }} & csr_badv_rvalue
                      | {32{csr_num == `CSR_EENTRY   }} & csr_eentry_rvalue
                      | {32{csr_num == `CSR_TLBIDX   }} & csr_tlbidx_rvalue
                      | {32{csr_num == `CSR_TLBEHI   }} & csr_tlbehi_rvalue
                      | {32{csr_num == `CSR_TLBELO0  }} & csr_tlbelo0_rvalue
                      | {32{csr_num == `CSR_TLBELO1  }} & csr_tlbelo1_rvalue
                      | {32{csr_num == `CSR_ASID     }} & csr_asid_rvalue
                      | {32{csr_num == `CSR_SAVE0    }} & csr_save0_rvalue
                      | {32{csr_num == `CSR_SAVE1    }} & csr_save1_rvalue
                      | {32{csr_num == `CSR_SAVE2    }} & csr_save2_rvalue
                      | {32{csr_num == `CSR_SAVE3    }} & csr_save3_rvalue
                      | {32{csr_num == `CSR_TID      }} & csr_tid_rvalue
                      | {32{csr_num == `CSR_TCFG     }} & csr_tcfg_rvalue
                      | {32{csr_num == `CSR_TVAL     }} & csr_tval
                      | {32{csr_num == `CSR_TICLR    }} & csr_ticlr_rvalue
                      | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                      | {32{csr_num == `CSR_DMW0     }} & csr_dmw0_rvalue
                      | {32{csr_num == `CSR_DMW1     }} & csr_dmw1_rvalue;
                    
//ex_entry
    assign ex_entry = wb_ecode == `ECODE_TLBR ? csr_tlbrentry_rvalue : csr_eentry_rvalue;

//has_int
    assign int_vec[12:0] = { csr_ecfg_lie[12] & csr_estat_is[12],
                             csr_ecfg_lie[11] & csr_estat_is[11],
                             csr_ecfg_lie[10] & csr_estat_is[10],
                             csr_ecfg_lie[ 9] & csr_estat_is[ 9],
                             csr_ecfg_lie[ 8] & csr_estat_is[ 8],
                             csr_ecfg_lie[ 7] & csr_estat_is[ 7],
                             csr_ecfg_lie[ 6] & csr_estat_is[ 6],
                             csr_ecfg_lie[ 5] & csr_estat_is[ 5],
                             csr_ecfg_lie[ 4] & csr_estat_is[ 4],
                             csr_ecfg_lie[ 3] & csr_estat_is[ 3],
                             csr_ecfg_lie[ 2] & csr_estat_is[ 2],
                             csr_ecfg_lie[ 1] & csr_estat_is[ 1],
                             csr_ecfg_lie[ 0] & csr_estat_is[ 0]
                           };
    assign has_int = ~(int_vec == 13'b0) & csr_crmd_ie;

endmodule