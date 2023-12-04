module WB_stage(
    input          clk,
    input          reset,
    output         WB_allowin,
    input          MEM_to_WB_valid,
    input  [217:0] MEM_to_WB_bus,
    input  [ 48:0] EXE_to_WB_bus,
    output [ 37:0] WB_to_rf_bus,
    output [  5:0] WB_to_EXE_bus,
    output         out_WB_valid,
    output [ 31:0] debug_wb_rf_pc,
    output [  3:0] debug_wb_rf_we,
    output [  4:0] debug_wb_rf_wnum,
    output [ 31:0] debug_wb_rf_wdata,
    output         exec_flush,
    output [ 31:0] WB_pc_gen_exec
);

`define CSR_ERA       14'h0006
`define CSR_TID       14'h0040
`define CSR_TVAL      14'h0042
`define ECODE_INT     6'h00
`define ECODE_SYS     6'h0b
`define ECODE_ADEF    6'h08
`define ECODE_ALE     6'h09
`define ECODE_BRK     6'h0c
`define ECODE_INE     6'h0d
`define ECODE_TLBR    6'h3f

reg          WB_valid;
wire         WB_ready_go;
reg  [217:0] MEM_to_WB_bus_rf;
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
wire         WB_wb_ex;
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
} = MEM_to_WB_bus_rf[216:0];

assign {
    tlbsrch_en,
    invtlb_valid,
    invtlb_op[4:0],
    invtlb_rj_value[9:0],
    invtlb_rk_value[31:0]
} = EXE_to_WB_bus[48:0];
assign invtlb_rj_value[31:10] = 22'b0;

assign WB_to_EXE_bus[4:0] = {
    s1_found,               //4
    s1_index[3:0]           //3:0
};

assign WB_rf_we = WB_gr_we & WB_valid & ~WB_wb_ex;

assign WB_to_rf_bus[37:0] = {
    WB_rf_we,               //37:37
    WB_dest[4:0],           //36:32
    WB_rf_wdata[31:0]       //31: 0
};

assign WB_is_priv  = WB_inst_csrrd | WB_inst_csrwr | WB_inst_csrxchg | WB_inst_ertn | WB_inst_syscall |
                    WB_inst_brk | WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w;
assign WB_rf_wdata = WB_is_priv ? WB_csr_rvalue[31:0] : WB_final_result[31:0];
assign WB_csr_re   = (WB_inst_csrrd | WB_inst_csrxchg | WB_inst_csrwr |
                    WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w) & WB_valid;
assign WB_csr_we   = (WB_inst_csrwr | WB_inst_csrxchg) & WB_valid;
assign WB_ecode    = {6{WB_valid & WB_has_int}} & `ECODE_INT |
                     {6{WB_valid & WB_ex_adef}} & `ECODE_ADEF |
                     {6{WB_valid & WB_ex_ale}} & `ECODE_ALE |
                     {6{WB_valid & WB_inst_syscall}} & `ECODE_SYS |
                     {6{WB_valid & WB_inst_brk}} & `ECODE_BRK |
                     {6{WB_valid & WB_ex_ine}} & `ECODE_INE;
assign WB_esubcode = 9'h000;
assign WB_wb_ex    = (WB_inst_syscall | WB_inst_brk | WB_has_int | WB_ex_adef | WB_ex_ine | WB_ex_ale) & WB_valid;
assign WB_csr_num  = {14{WB_inst_ertn}} & `CSR_ERA |
                     {14{WB_inst_rdcntvl_w | WB_inst_rdcntvh_w}} & `CSR_TVAL |
                     {14{WB_inst_rdcntid}} & `CSR_TID |
                     {14{~WB_inst_ertn & ~WB_inst_rdcntvh_w & ~WB_inst_rdcntvl_w & ~WB_inst_rdcntid}} & WB_csr_num_inst;
assign WB_csr_wmask   = WB_inst_csrxchg ? WB_rj_value : 32'hffffffff;
assign exec_flush     = (WB_inst_syscall | WB_inst_ertn | WB_inst_brk | WB_ex_adef | WB_ex_ine | WB_ex_ale | WB_has_int) & WB_valid;
assign WB_pc_gen_exec = {32{WB_inst_ertn}} & WB_csr_rvalue |
                        {32{exec_flush & ~WB_inst_ertn}} & WB_ex_entry;

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
               : 19'b0;
assign s1_va_bit12 = invtlb_valid & (invtlb_op == 5'h05 || invtlb_op == 5'h06) ? invtlb_rk_value[12] : 1'b0;
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
    .wb_ex      (WB_wb_ex     ),
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
    .tlbsrch_index   (s1_index  )
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
