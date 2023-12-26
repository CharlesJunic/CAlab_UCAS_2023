module WB_stage(
    input          clk,
    input          reset,
    output         WB_allowin,
    input          MEM_to_WB_valid,
    input  [223:0] MEM_to_WB_bus,
    input  [ 68:0] EXE_to_WB_bus,
    input  [ 19:0] IF_to_WB_bus,
    output [ 52:0] WB_to_ID_bus,
    output [ 36:0] WB_to_EXE_bus,
    output [ 36:0] WB_to_IF_bus,
    output         out_WB_valid,
    output [ 31:0] debug_wb_rf_pc,
    output [  3:0] debug_wb_rf_we,
    output [  4:0] debug_wb_rf_wnum,
    output [ 31:0] debug_wb_rf_wdata,
    output         exec_flush,
    output [ 31:0] WB_pc_gen_exec,
    output [ 27:0] WB_crmd_dmw_bus
);

`define CSR_ERA       14'h0006
`define CSR_TID       14'h0040
`define CSR_TVAL      14'h0042
`define ECODE_INT     6'h00
`define ECODE_PIL     6'h01
`define ECODE_PIS     6'h02
`define ECODE_PIF     6'h03
`define ECODE_PME     6'h04
`define ECODE_PPI     6'h07
`define ECODE_ADE     6'h08
`define ESUBCODE_ADEF 9'h000
`define ESUBCODE_ADEM 9'h001
`define ECODE_ALE     6'h09
`define ECODE_SYS     6'h0b
`define ECODE_BRK     6'h0c
`define ECODE_INE     6'h0d
`define ECODE_IPE     6'h0e
`define ECODE_FPD     6'h0f
`define ECODE_FPE     6'h12
`define ECODE_TLBR    6'h3f

reg          WB_valid;
wire         WB_ready_go;
reg  [223:0] MEM_to_WB_bus_rf;
wire [ 31:0] WB_pc;
wire [ 31:0] WB_final_result;
wire [  4:0] WB_dest;
wire         WB_gr_we;
wire         WB_rf_we;
wire [ 31:0] WB_rf_wdata;
wire         WB_is_priv;
wire         WB_inst_csrrd;
wire         WB_inst_csrwr;
wire         WB_inst_csrxchg;
wire         WB_inst_syscall;
wire         WB_inst_ertn;
wire         WB_ex;
wire         WB_csr_re;
wire         WB_csr_we;
wire [ 14:0] WB_ex_code;
wire [ 13:0] WB_csr_num_inst;
wire [ 13:0] WB_csr_num;
wire [ 31:0] WB_rj_value;
wire [ 31:0] WB_csr_wmask;
wire [ 31:0] WB_csr_rvalue;
wire [ 31:0] WB_csr_wdata;
wire [ 31:0] WB_ex_entry;
wire [  5:0] WB_ecode;
wire [  8:0] WB_esubcode;
wire         WB_ex_adef;
wire         WB_ex_ine;
wire         WB_ex_ale;
wire [ 31:0] WB_ex_baddr;
wire         WB_inst_brk;
wire         WB_inst_rdcntid;
wire         WB_inst_rdcntvl_w;
wire         WB_inst_rdcntvh_w;
wire         WB_has_int;
reg          WB_has_int_rf;
wire         WB_inst_tlbsrch;
wire         WB_tlbsrch_hit;
wire [  3:0] WB_tlbsrch_index;
wire         WB_inst_tlbrd;
wire         WB_inst_tlbwr;
wire         WB_inst_tlbfill;
wire         WB_inst_invtlb;
wire         WB_ex_pif;
wire         WB_ex_pil;
wire         WB_ex_pis;
wire         WB_ex_ppi;
wire         WB_ex_pme;
wire         WB_ex_tlbr;
wire         WB_refetch_flush;

wire [ 18:0] s0_vppn;
wire         s0_va_bit12;
wire [  9:0] s0_asid;
wire         s0_found;
wire [  3:0] s0_index;
wire [ 19:0] s0_ppn;
wire [  5:0] s0_ps;
wire [  1:0] s0_plv;
wire [  1:0] s0_mat;
wire         s0_d;
wire         s0_v;
wire [ 18:0] s1_vppn;
wire         s1_va_bit12;
wire [  9:0] s1_asid;
wire         s1_found;
wire [  3:0] s1_index;
wire [ 19:0] s1_ppn;
wire [  5:0] s1_ps;
wire [  1:0] s1_plv;
wire [  1:0] s1_mat;
wire         s1_d;
wire         s1_v;
wire         invtlb_valid;
wire [  4:0] invtlb_op;
wire         we;
wire [  3:0] w_index;
wire         w_e;
wire         w_ne;
wire [ 18:0] w_vppn;
wire [  5:0] w_ps;
wire [  9:0] w_asid;
wire         w_g;
wire [ 19:0] w_ppn0;
wire [  1:0] w_plv0;
wire [  1:0] w_mat0;
wire         w_d0;
wire         w_v0;
wire [ 19:0] w_ppn1;
wire [  1:0] w_plv1;
wire [  1:0] w_mat1;
wire         w_d1;
wire         w_v1;
wire [  3:0] r_index;
wire         r_e;
wire [ 18:0] r_vppn;
wire [  5:0] r_ps;
wire [  9:0] r_asid;
wire         r_g;
wire [ 19:0] r_ppn0;
wire [  1:0] r_plv0;
wire [  1:0] r_mat0;
wire         r_d0;
wire         r_v0;
wire [ 19:0] r_ppn1;
wire [  1:0] r_plv1;
wire [  1:0] r_mat1;
wire         r_d1;
wire         r_v1;

wire         tlbsrch_en;
wire         tlbrd_we;
wire [  3:0] csr_tlb_index;
wire         w_g0;
wire         w_g1;
reg  [  3:0] rand;
wire [ 31:0] invtlb_rj_value;
wire [ 31:0] invtlb_rk_value;
wire         csr_crmd_da;
wire         csr_crmd_pg;
wire [  1:0] csr_crmd_plv;
wire         csr_dmw0_plv0;
wire         csr_dmw0_plv3;
wire [  1:0] csr_dmw0_mat;
wire [  2:0] csr_dmw0_pseg;
wire [  2:0] csr_dmw0_vseg;
wire         csr_dmw1_plv0;
wire         csr_dmw1_plv3;
wire [  1:0] csr_dmw1_mat;
wire [  2:0] csr_dmw1_pseg;
wire [  2:0] csr_dmw1_vseg;
wire [  1:0] csr_crmd_datf;
wire [  1:0] csr_crmd_datm;
wire [ 18:0] EXE_vppn;
wire         EXE_va_bit12;

assign WB_ready_go  = 1'b1;
assign WB_allowin   = !WB_valid || WB_ready_go;
assign out_WB_valid = WB_valid;

always @(posedge clk) begin
    if (reset)
        WB_valid <= 1'b0;
    else if (exec_flush)
        WB_valid <= 1'b0;
    else if (WB_allowin)
        WB_valid <= MEM_to_WB_valid;
end

always @(posedge clk) begin
    if (WB_allowin && MEM_to_WB_valid) 
        MEM_to_WB_bus_rf <= MEM_to_WB_bus;
end

assign {
    WB_refetch_flush,
    WB_ex_pif,
    WB_ex_pil,
    WB_ex_pis,
    WB_ex_ppi,
    WB_ex_pme,
    WB_ex_tlbr,
    WB_inst_tlbsrch,
    WB_tlbsrch_hit,
    WB_tlbsrch_index[3:0],
    WB_inst_tlbrd,
    WB_inst_tlbwr,
    WB_inst_tlbfill,
    WB_inst_invtlb,
    WB_ex_adef,
    WB_ex_ine,
    WB_ex_ale,
    WB_ex_baddr[31:0],
    WB_inst_brk,
    WB_inst_rdcntid,
    WB_inst_rdcntvl_w,
    WB_inst_rdcntvh_w,
    WB_ex_code[14:0],
    WB_rj_value[31:0],
    WB_csr_wdata[31:0],
    WB_inst_syscall,
    WB_inst_ertn,
    WB_inst_csrrd,
    WB_inst_csrwr,
    WB_inst_csrxchg,
    WB_csr_num_inst[13:0],
    WB_pc[31:0],
    WB_gr_we,
    WB_dest[4:0],
    WB_final_result[31:0]
} = MEM_to_WB_bus_rf[223:0];

assign {
    EXE_vppn[18:0],
    EXE_va_bit12,
    tlbsrch_en,
    invtlb_valid,
    invtlb_op[4:0],
    invtlb_rj_value[9:0],
    invtlb_rk_value[31:0]
} = EXE_to_WB_bus[68:0];
assign invtlb_rj_value[31:10] = 22'b0;

assign WB_to_EXE_bus[36:0] = {
    s1_ppn[19:0],       //36:17
    s1_ps[5:0],         //16:11
    s1_plv[1:0],        //10: 9
    s1_mat[1:0],        // 8: 7
    s1_d,               // 6
    s1_v,               // 5
    s1_found,           // 4
    s1_index[3:0]       // 3: 0
};

assign WB_rf_we = WB_gr_we & WB_valid & ~WB_ex;

assign WB_to_ID_bus[52:0] = {
    WB_inst_csrxchg | WB_inst_csrwr,//52
    WB_csr_num[13:0],               //51:38
    WB_rf_we,                       //37
    WB_dest[4:0],                   //36:32
    WB_rf_wdata[31:0]               //31: 0
};

assign WB_crmd_dmw_bus[27:0] = {
    csr_crmd_datf[1:0],     //27:26
    csr_crmd_datm[1:0],     //25:24
    csr_crmd_da,            //23
    csr_crmd_pg,            //22
    csr_crmd_plv[1:0],      //21:20
    csr_dmw0_plv0,          //19
    csr_dmw0_plv3,          //18
    csr_dmw0_mat[1:0],      //17:16
    csr_dmw0_pseg[2:0],     //15:13
    csr_dmw0_vseg[2:0],     //12:10
    csr_dmw1_plv0,          // 9
    csr_dmw1_plv3,          // 8
    csr_dmw1_mat[1:0],      // 7: 6
    csr_dmw1_pseg[2:0],     // 5: 3
    csr_dmw1_vseg[2:0]      // 2: 0
};

assign {
    s0_vppn[18:0],
    s0_va_bit12
} = IF_to_WB_bus[19:0];

assign WB_to_IF_bus[36:0] = {
    s0_found,       //36
    s0_index[3:0],  //35:32
    s0_ppn[19:0],   //31:12
    s0_ps[5:0],     //11: 6
    s0_plv[1:0],    // 5: 4
    s0_mat[1:0],    // 3: 2
    s0_d,           // 1
    s0_v            // 0
}; 

assign WB_is_priv  = WB_inst_csrrd | WB_inst_csrwr | WB_inst_csrxchg | WB_inst_ertn | WB_inst_syscall |
                    WB_inst_brk | WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w;
assign WB_rf_wdata = WB_is_priv ? WB_csr_rvalue[31:0] : WB_final_result[31:0];
assign WB_csr_re   = (WB_inst_csrrd | WB_inst_csrxchg | WB_inst_csrwr |
                    WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w) & WB_valid;
assign WB_csr_we   = (WB_inst_csrwr | WB_inst_csrxchg) & WB_valid;
assign WB_ecode    = {6{WB_valid & WB_has_int     }} & `ECODE_INT
                   | {6{WB_valid & WB_ex_adef     }} & `ECODE_ADE
                   | {6{WB_valid & WB_ex_ale      }} & `ECODE_ALE
                   | {6{WB_valid & WB_inst_syscall}} & `ECODE_SYS
                   | {6{WB_valid & WB_inst_brk    }} & `ECODE_BRK
                   | {6{WB_valid & WB_ex_ine      }} & `ECODE_INE
                   | {6{WB_valid & WB_ex_tlbr     }} & `ECODE_TLBR
                   | {6{WB_valid & WB_ex_pil      }} & `ECODE_PIL
                   | {6{WB_valid & WB_ex_pis      }} & `ECODE_PIS
                   | {6{WB_valid & WB_ex_pif      }} & `ECODE_PIF
                   | {6{WB_valid & WB_ex_ppi      }} & `ECODE_PPI
                   | {6{WB_valid & WB_ex_pme      }} & `ECODE_PME;
assign WB_esubcode = 9'h000;
assign WB_ex    = (WB_inst_syscall | WB_inst_brk | WB_has_int | WB_ex_adef | WB_ex_ine | WB_ex_ale
                   | WB_ex_pif | WB_ex_pil | WB_ex_pis | WB_ex_ppi | WB_ex_pme | WB_ex_tlbr) & WB_valid;
assign WB_csr_num  = {14{WB_inst_ertn}} & `CSR_ERA |
                     {14{WB_inst_rdcntvl_w | WB_inst_rdcntvh_w}} & `CSR_TVAL |
                     {14{WB_inst_rdcntid}} & `CSR_TID |
                     {14{~WB_inst_ertn & ~WB_inst_rdcntvh_w & ~WB_inst_rdcntvl_w & ~WB_inst_rdcntid}} & WB_csr_num_inst;
assign WB_csr_wmask   = WB_inst_csrxchg ? WB_rj_value : 32'hffffffff;
assign exec_flush     = (WB_inst_syscall | WB_inst_ertn | WB_inst_brk | WB_ex_adef | WB_ex_ine | WB_ex_ale 
                      | WB_has_int | WB_ex_pif | WB_ex_pil | WB_ex_pis | WB_ex_ppi | WB_ex_pme | WB_ex_tlbr | WB_refetch_flush) & WB_valid;
assign WB_pc_gen_exec = {32{WB_inst_ertn}} & WB_csr_rvalue |
                        {32{exec_flush & ~WB_inst_ertn & ~WB_refetch_flush}} & WB_ex_entry |
                        {32{WB_refetch_flush}} & (WB_pc + 32'd4);

assign tlbrd_we = WB_inst_tlbrd & WB_valid;
assign we       = (WB_inst_tlbwr | WB_inst_tlbfill) & WB_valid;
assign w_index  = (WB_inst_tlbfill) ? rand : csr_tlb_index;
assign w_e      = WB_ecode == `ECODE_TLBR ? 1'b1 : ~w_ne;
assign w_g      = w_g0 & w_g1;

reg seed;
always @(posedge clk) begin
    seed <= seed + 1;
    rand <= {$random(seed)} % 16;
end

assign s1_vppn = tlbsrch_en ? w_vppn
               : invtlb_valid & (invtlb_op == 5'h05 || invtlb_op == 5'h06) ? invtlb_rk_value[31:13]
               : EXE_vppn;
assign s1_va_bit12 = invtlb_valid & (invtlb_op == 5'h05 || invtlb_op == 5'h06) ? invtlb_rk_value[12] : EXE_va_bit12;
assign s1_asid = (invtlb_valid & (invtlb_op == 5'h04 || invtlb_op == 5'h05 || invtlb_op == 5'h06)) 
               ? invtlb_rj_value[9:0] : w_asid;

csr u_csr(
    .clk        (clk          ),
    .reset      (reset        ),
    .csr_re     (WB_csr_re    ),
    .csr_we     (WB_csr_we    ),
    .csr_num    (WB_csr_num   ),
    .csr_rvalue (WB_csr_rvalue),
    .csr_wmask  (WB_csr_wmask ),
    .csr_wvalue (WB_csr_wdata ),
    .wb_ex      (WB_ex        ),
    .WB_pc      (WB_pc        ),
    .wb_ecode   (WB_ecode     ),
    .wb_esubcode(WB_esubcode  ),
    .wb_vaddr   (WB_ex_baddr  ),
    .ertn_flush (WB_inst_ertn ),
    .has_int    (WB_has_int   ),
    .ex_entry   (WB_ex_entry  ),
    .hw_int_in  (8'b0         ),
    .ipi_int_in (1'b0         ),
    .coreid_in  (32'b0        ),

    .r_index    (r_index ),
    .tlbrd_we   (tlbrd_we),
    .r_e        (r_e     ),
    .r_vppn     (r_vppn  ),
    .r_ps       (r_ps    ),
    .r_asid     (r_asid  ),
    .r_g        (r_g     ),
    .r_ppn0     (r_ppn0  ),
    .r_plv0     (r_plv0  ),
    .r_mat0     (r_mat0  ),
    .r_d0       (r_d0    ),
    .r_v0       (r_v0    ),
    .r_ppn1     (r_ppn1  ),
    .r_plv1     (r_plv1  ),
    .r_mat1     (r_mat1  ),
    .r_d1       (r_d1    ),
    .r_v1       (r_v1    ),

    .csr_tlbidx_index(csr_tlb_index),
    .csr_tlbidx_ne   (w_ne         ),
    .csr_tlbehi_vppn (w_vppn       ),
    .csr_tlbidx_ps   (w_ps         ),
    .csr_asid_asid   (w_asid       ),
    .csr_tlbelo0_g   (w_g0         ),
    .csr_tlbelo0_ppn (w_ppn0       ),
    .csr_tlbelo0_plv (w_plv0       ),
    .csr_tlbelo0_mat (w_mat0       ),
    .csr_tlbelo0_d   (w_d0         ),
    .csr_tlbelo0_v   (w_v0         ),
    .csr_tlbelo1_g   (w_g1         ),
    .csr_tlbelo1_ppn (w_ppn1       ),
    .csr_tlbelo1_plv (w_plv1       ),
    .csr_tlbelo1_mat (w_mat1       ),
    .csr_tlbelo1_d   (w_d1         ),
    .csr_tlbelo1_v   (w_v1         ),

    .tlbsrch_en      (tlbsrch_en),
    .tlbsrch_hit     (s1_found  ),
    .tlbsrch_index   (s1_index  ),

    .csr_crmd_da  (csr_crmd_da  ),
    .csr_crmd_pg  (csr_crmd_pg  ),
    .csr_crmd_plv (csr_crmd_plv ),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw0_mat (csr_dmw0_mat ),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_dmw1_mat (csr_dmw1_mat ),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_crmd_datf(csr_crmd_datf),
    .csr_crmd_datm(csr_crmd_datm)
);

tlb u_tlb(
    .clk         (clk         ),
    .s0_vppn     (s0_vppn     ),
    .s0_va_bit12 (s0_va_bit12 ),
    .s0_asid     (s0_asid     ),
    .s0_found    (s0_found    ),
    .s0_index    (s0_index    ),
    .s0_ppn      (s0_ppn      ),
    .s0_ps       (s0_ps       ),
    .s0_plv      (s0_plv      ),
    .s0_mat      (s0_mat      ),
    .s0_d        (s0_d        ),
    .s0_v        (s0_v        ),
    .s1_vppn     (s1_vppn     ),
    .s1_va_bit12 (s1_va_bit12 ),
    .s1_asid     (s1_asid     ),
    .s1_found    (s1_found    ),
    .s1_index    (s1_index    ),
    .s1_ppn      (s1_ppn      ),
    .s1_ps       (s1_ps       ),
    .s1_plv      (s1_plv      ),
    .s1_mat      (s1_mat      ),
    .s1_d        (s1_d        ),
    .s1_v        (s1_v        ),
    .invtlb_valid(invtlb_valid),
    .invtlb_op   (invtlb_op   ),
    .we          (we          ),
    .w_index     (w_index     ),
    .w_e         (w_e         ),
    .w_vppn      (w_vppn      ),
    .w_ps        (w_ps        ),
    .w_asid      (w_asid      ),
    .w_g         (w_g         ),
    .w_ppn0      (w_ppn0      ),
    .w_plv0      (w_plv0      ),
    .w_mat0      (w_mat0      ),
    .w_d0        (w_d0        ),
    .w_v0        (w_v0        ),
    .w_ppn1      (w_ppn1      ),
    .w_plv1      (w_plv1      ),
    .w_mat1      (w_mat1      ),
    .w_d1        (w_d1        ),
    .w_v1        (w_v1        ),
    .r_index     (r_index     ),
    .r_e         (r_e         ),
    .r_vppn      (r_vppn      ),
    .r_ps        (r_ps        ),
    .r_asid      (r_asid      ),
    .r_g         (r_g         ),
    .r_ppn0      (r_ppn0      ),
    .r_plv0      (r_plv0      ),
    .r_mat0      (r_mat0      ),
    .r_d0        (r_d0        ),
    .r_v0        (r_v0        ),
    .r_ppn1      (r_ppn1      ),
    .r_plv1      (r_plv1      ),
    .r_mat1      (r_mat1      ),
    .r_d1        (r_d1        ),
    .r_v1        (r_v1        )
);

assign debug_wb_rf_pc    = WB_pc;
assign debug_wb_rf_we    = {4{WB_rf_we}};
assign debug_wb_rf_wnum  = WB_dest;
assign debug_wb_rf_wdata = WB_rf_wdata;

endmodule
