module EXE_stage(
    input          clk,
    input          reset,
    input          MEM_allowin,
    output         EXE_allowin,
    input          ID_to_EXE_valid,
    input  [246:0] ID_to_EXE_bus,
    input  [ 36:0] WB_to_EXE_bus,
    output         EXE_to_MEM_valid,
    output [230:0] EXE_to_MEM_bus,
    output [ 68:0] EXE_to_WB_bus,
    input  [ 27:0] EXE_crmd_dmw_bus,
    output         data_sram_req,
    output         data_sram_wr,
    output [  1:0] data_sram_size,
    output [  3:0] data_sram_wstrb,
    output [ 31:0] data_sram_addr,
    output [ 31:0] data_sram_wdata,
    input          data_sram_addr_ok,
    output         out_EXE_valid,
    input          exec_flush
);

reg          EXE_valid;
wire         EXE_ready_go;
reg  [246:0] ID_to_EXE_bus_rf;
wire [ 31:0] EXE_alu_src1;
wire [ 31:0] EXE_alu_src2;
wire [ 11:0] EXE_alu_op;
wire [  2:0] EXE_mul_op;
reg          mul_complete;
wire [  4:0] EXE_invtlb_op;
wire [ 31:0] EXE_alu_result;
wire [ 31:0] EXE_mul_result;
wire [ 31:0] EXE_rj_value;
wire [ 31:0] EXE_rkd_value;
wire [ 31:0] EXE_imm;
wire [ 31:0] EXE_pc;
wire [  4:0] EXE_dest;
wire         EXE_src1_is_pc;
wire         EXE_src2_is_imm;
wire         EXE_res_from_mem;
wire         EXE_gr_we;
wire         EXE_mem_we;
wire [ 31:0] EXE_result;
wire [ 63:0] EXE_divu_out;
wire [ 63:0] EXE_div_out;
wire [ 31:0] EXE_div_result;
wire [ 31:0] EXE_mod_result;
wire [  1:0] EXE_vaddr;
wire         EXE_op_unsigned_md;
wire         EXE_op_unsigned_ld;
wire         EXE_op_b;
wire         EXE_op_h;
wire         EXE_op_mul;
wire         EXE_op_mulh;
wire         EXE_op_div;
wire         EXE_op_mod;
wire         EXE_op_divmod_u;
wire         EXE_op_divmod;
wire         EXE_div_in_ready;
wire         EXE_divu_in_ready;
wire         EXE_div_divisor_ready;
wire         EXE_div_dividend_ready;
reg          EXE_div_divisor_valid;
reg          EXE_div_dividend_valid;
wire         EXE_divu_divisor_ready;
wire         EXE_divu_dividend_ready;
reg          EXE_divu_divisor_valid;
reg          EXE_divu_dividend_valid;
wire         EXE_div_out_valid;
wire         EXE_divu_out_valid;
reg          EXE_div_valid;
reg          EXE_divu_valid;
wire         EXE_inst_csrrd;
wire         EXE_inst_csrwr;
wire         EXE_inst_csrxchg;
wire         EXE_inst_syscall;
wire         EXE_inst_ertn;
wire         EXE_inst_cancel;
reg          EXE_ex_flush_r;
wire [ 14:0] EXE_ex_code;
wire [ 13:0] EXE_csr_num;
reg          EXE_pre_ex;
wire         EXE_ex_adef;
wire         ID_ex_ine;
wire         EXE_ex_ale;
wire         EXE_inst_brk;
wire         EXE_inst_rdcntid;
wire         EXE_inst_rdcntvl_w;
wire         EXE_inst_rdcntvh_w;
wire         EXE_inst_tlbsrch;
wire         EXE_inst_tlbrd;
wire         EXE_inst_tlbwr;
wire         EXE_inst_tlbfill;
wire         EXE_inst_invtlb;
wire [ 31:0] ID_ex_baddr;
wire [ 31:0] EXE_ex_baddr;
wire         EXE_ex;
wire         EXE_tlbsrch_en;
wire         EXE_tlbsrch_hit;
wire [  3:0] EXE_tlbsrch_index;
wire         EXE_ex_ine;
wire         EXE_s1_found;
wire [  3:0] EXE_s1_index;
wire [ 19:0] EXE_s1_ppn;
wire [  5:0] EXE_s1_ps;
wire [  1:0] EXE_s1_plv;
wire [  1:0] EXE_s1_mat;
wire         EXE_s1_d;
wire         EXE_s1_v;
wire         EXE_crmd_da;
wire         EXE_crmd_pg;
wire [  1:0] EXE_crmd_plv;
wire         EXE_dmw0_plv0;
wire         EXE_dmw0_plv3;
wire [  1:0] EXE_dmw0_mat;
wire [  2:0] EXE_dmw0_pseg;
wire [  2:0] EXE_dmw0_vseg;
wire         EXE_dmw1_plv0;
wire         EXE_dmw1_plv3;
wire [  1:0] EXE_dmw1_mat;
wire [  2:0] EXE_dmw1_pseg;
wire [  2:0] EXE_dmw1_vseg;
wire [  1:0] EXE_crmd_datf;
wire [  1:0] EXE_crmd_datm;
wire         ID_ex_ppi;
wire         ID_ex_tlbr;
wire         EXE_ex_pif;
wire         EXE_ex_ppi;
wire         EXE_ex_tlbr;
wire         EXE_ex_pil;
wire         EXE_ex_pis;
wire         EXE_ex_pme;
wire         EXE_tlb_hit;
wire         EXE_dmw0_hit;
wire         EXE_dmw1_hit;
wire [ 31:0] EXE_tlb_paddr;
wire         EXE_refetch_flush;
always @(posedge clk) begin
    if (reset)
        EXE_pre_ex <= 1'b0;
    else if (~exec_flush & EXE_ex & EXE_valid)
        EXE_pre_ex <= 1'b1;
    else if (exec_flush)
        EXE_pre_ex <= 1'b0;
end
assign EXE_ex_baddr = (ID_ex_ppi | EXE_ex_pif | ID_ex_tlbr) ? ID_ex_baddr : EXE_alu_result;
assign EXE_ex       = EXE_ex_adef | EXE_ex_ine | EXE_ex_ale | EXE_inst_syscall | EXE_inst_brk | EXE_inst_ertn
                    | EXE_ex_pif | EXE_ex_ppi | EXE_ex_tlbr | EXE_ex_pil | EXE_ex_pis | EXE_ex_pme;
assign EXE_ex_ine   = ID_ex_ine | (EXE_invtlb_en & (EXE_invtlb_op[3] | EXE_invtlb_op[4] | EXE_invtlb_op == 5'h07));

always @(posedge clk) begin
    if (reset) begin
        EXE_divu_valid <= 1'b0;
        EXE_divu_divisor_valid <= 1'b0;
        EXE_divu_dividend_valid <= 1'b0;
    end
    else if (EXE_op_divmod_u & ~EXE_divu_valid & EXE_valid) begin
        EXE_divu_valid <= 1'b1;
        EXE_divu_divisor_valid <= 1'b1;
        EXE_divu_dividend_valid <= 1'b1;
    end
    else if (EXE_divu_valid & EXE_divu_in_ready) begin
        EXE_divu_divisor_valid <= 1'b0;
        EXE_divu_dividend_valid <= 1'b0;
    end
    else if (EXE_divu_valid & EXE_divu_out_valid) begin
        EXE_divu_valid <= 1'b0;
    end
end

assign EXE_ready_go = ((EXE_op_mul | EXE_op_mulh) & mul_complete)
                    | (EXE_op_divmod & EXE_div_out_valid)
                    | (EXE_op_divmod_u & EXE_divu_out_valid)
                    | ((EXE_mem_we | EXE_res_from_mem) & (data_sram_req & data_sram_addr_ok | EXE_ex | exec_flush))
                    | (~EXE_op_div & ~EXE_op_mod & ~EXE_mem_we & ~EXE_res_from_mem & ~EXE_op_mul & ~EXE_op_mulh);
assign EXE_allowin      = !EXE_valid || EXE_ready_go && MEM_allowin;
assign EXE_to_MEM_valid = EXE_valid && EXE_ready_go;
assign out_EXE_valid    = EXE_valid;

always @(posedge clk) begin
    if (reset) 
        EXE_valid <= 1'b0;
    else if (exec_flush)
        EXE_valid <= 1'b0;
    else if (EXE_allowin)
        EXE_valid <= ID_to_EXE_valid;
end

assign EXE_to_MEM_bus[230:0] = {
    EXE_refetch_flush,       //230
    EXE_ex_pif,              //229
    EXE_ex_pil,              //228
    EXE_ex_pis,              //227
    EXE_ex_ppi,              //226
    EXE_ex_pme,              //225
    EXE_ex_tlbr,             //224
    EXE_inst_tlbsrch,        //223
    EXE_tlbsrch_hit,         //222
    EXE_tlbsrch_index[3:0],  //221:218
    EXE_inst_tlbrd,          //217
    EXE_inst_tlbwr,          //216
    EXE_inst_tlbfill,        //215
    EXE_inst_invtlb,         //214
    EXE_mem_we,              //213
    EXE_ex_adef,             //212
    EXE_ex_ine,              //211
    EXE_ex_ale,              //210
    EXE_ex_baddr[31:0],      //209:178
    EXE_inst_brk,            //177
    EXE_inst_rdcntid,        //176
    EXE_inst_rdcntvl_w,      //175
    EXE_inst_rdcntvh_w,      //174
    EXE_ex_code[14:0],       //173:159
    EXE_rj_value[31:0],      //158:127
    EXE_rkd_value[31:0],     //126: 95
    EXE_inst_syscall,        // 94
    EXE_inst_ertn,           // 93
    EXE_inst_csrrd,          // 92
    EXE_inst_csrwr,          // 91
    EXE_inst_csrxchg,        // 90
    EXE_csr_num[13:0],       // 89: 76
    EXE_vaddr[1:0],          // 75: 74
    EXE_op_unsigned_ld,      // 73: 73
    EXE_op_b,                // 72: 72
    EXE_op_h,                // 71: 71
    EXE_pc[31:0],            // 70: 39
    EXE_result[31:0],        // 38:  7
    EXE_res_from_mem,        //  6:  6
    EXE_gr_we,               //  5:  5
    EXE_dest[4:0]            //  4:  0
};

assign EXE_tlbsrch_en = EXE_valid & EXE_inst_tlbsrch & ~EXE_pre_ex & ~exec_flush;
assign EXE_invtlb_en  = EXE_valid & EXE_inst_invtlb  & ~EXE_pre_ex & ~exec_flush;
assign EXE_to_WB_bus[68:0] = {
    EXE_alu_result[31:12],  //68:49
    EXE_tlbsrch_en,         //48
    EXE_invtlb_en,          //47
    EXE_invtlb_op[4:0],     //46:42
    EXE_rj_value[9:0],      //41:32
    EXE_rkd_value[31:0]     //31: 0
};

assign {
    EXE_s1_ppn[19:0],       //36:17
    EXE_s1_ps[5:0],         //16:11
    EXE_s1_plv[1:0],        //10: 9
    EXE_s1_mat[1:0],        // 8: 7
    EXE_s1_d,               // 6
    EXE_s1_v,               // 5
    EXE_tlbsrch_hit,        // 4
    EXE_tlbsrch_index[3:0]  // 3: 0
} = WB_to_EXE_bus[36:0];

assign {
    EXE_crmd_datf,
    EXE_crmd_datm,
    EXE_crmd_da,
    EXE_crmd_pg,
    EXE_crmd_plv[1:0],
    EXE_dmw0_plv0,
    EXE_dmw0_plv3,
    EXE_dmw0_mat[1:0],
    EXE_dmw0_pseg[2:0],
    EXE_dmw0_vseg[2:0],
    EXE_dmw1_plv0,
    EXE_dmw1_plv3,
    EXE_dmw1_mat[1:0],
    EXE_dmw1_pseg[2:0],
    EXE_dmw1_vseg[2:0]
} = EXE_crmd_dmw_bus[27:0];

always @(posedge clk) begin
    if (EXE_allowin && ID_to_EXE_valid)
        ID_to_EXE_bus_rf <= ID_to_EXE_bus;
end
assign {
    EXE_refetch_flush,      //246
    ID_ex_baddr[31:0],      //245:214
    EXE_ex_pif,             //213
    ID_ex_ppi,              //212
    ID_ex_tlbr,             //211
    EXE_invtlb_op[4:0],     //210:206
    EXE_inst_tlbsrch,       //205
    EXE_inst_tlbrd,         //204
    EXE_inst_tlbwr,         //203
    EXE_inst_tlbfill,       //202
    EXE_inst_invtlb,        //201
    EXE_mul_op[2:0],        //200:198
    EXE_ex_adef,            //197
    ID_ex_ine,              //196
    EXE_inst_brk,           //195
    EXE_inst_rdcntid,       //194
    EXE_inst_rdcntvl_w,     //193
    EXE_inst_rdcntvh_w,     //192
    EXE_ex_code[14:0],      //191:177
    EXE_inst_syscall,       //176
    EXE_inst_ertn,          //175
    EXE_inst_csrrd,         //174
    EXE_inst_csrwr,         //173
    EXE_inst_csrxchg,       //172
    EXE_csr_num[13:0],      //171:158
    EXE_op_unsigned_ld,     //157
    EXE_op_b,               //156
    EXE_op_h,               //155
    EXE_op_unsigned_md,     //154
    EXE_op_mul,             //153
    EXE_op_mulh,            //152
    EXE_op_div,             //151
    EXE_op_mod,             //150
    EXE_pc[31:0],           //149:118
    EXE_rj_value[31:0],     //117: 86
    EXE_rkd_value[31:0],    // 85: 54
    EXE_imm[31:0],          // 53: 22
    EXE_src1_is_pc,         // 21
    EXE_src2_is_imm,        // 20
    EXE_res_from_mem,       // 19
    EXE_gr_we,              // 18
    EXE_mem_we,             // 17
    EXE_dest[4:0],          // 16: 12
    EXE_alu_op[11:0]        // 11:  0
} = ID_to_EXE_bus_rf[246:0];

assign EXE_alu_src1      = EXE_src1_is_pc  ? EXE_pc[31:0] : EXE_rj_value;
assign EXE_alu_src2      = EXE_src2_is_imm ? EXE_imm : EXE_rkd_value;
assign EXE_op_divmod     = (EXE_op_div | EXE_op_mod) & ~EXE_op_unsigned_md;
assign EXE_op_divmod_u   = (EXE_op_div | EXE_op_mod) &  EXE_op_unsigned_md;
assign EXE_div_result    =  EXE_op_unsigned_md ? EXE_divu_out[63:32] : EXE_div_out[63:32];
assign EXE_mod_result    =  EXE_op_unsigned_md ? EXE_divu_out[31: 0] : EXE_div_out[31: 0];
assign EXE_div_in_ready  = ~EXE_op_unsigned_md & (EXE_div_divisor_ready  & EXE_div_dividend_ready );
assign EXE_divu_in_ready =  EXE_op_unsigned_md & (EXE_divu_divisor_ready & EXE_divu_dividend_ready);

always @(posedge clk) begin
    if (reset) begin
        EXE_div_valid <= 1'b0;
        EXE_div_divisor_valid <= 1'b0;
        EXE_div_dividend_valid <= 1'b0;
    end
    else if (EXE_op_divmod & ~EXE_div_valid & EXE_valid) begin
        EXE_div_valid <= 1'b1;
        EXE_div_divisor_valid <= 1'b1;
        EXE_div_dividend_valid <= 1'b1;
    end
    else if (EXE_div_valid & EXE_div_in_ready) begin
        EXE_div_divisor_valid <= 1'b0;
        EXE_div_dividend_valid <= 1'b0;
    end
    else if (EXE_div_valid & EXE_div_out_valid) begin
        EXE_div_valid <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        mul_complete <= 1'b0;
    end
    else if ((EXE_op_mul | EXE_op_mulh) & ~mul_complete) begin
        mul_complete <= 1'b1;
    end
    else begin
        mul_complete <= 1'b0;
    end
end

assign EXE_result = {32{EXE_op_mul | EXE_op_mulh}} & EXE_mul_result[31:0]
                  | {32{EXE_op_mod}} & EXE_mod_result[31:0]
                  | {32{EXE_op_div}} & EXE_div_result[31:0]
                  | {32{~EXE_op_mul & ~EXE_op_mulh & ~EXE_op_div & ~EXE_op_mod}} & EXE_alu_result[31:0];
assign EXE_vaddr  = EXE_alu_result[1:0];

wire   EXE_op_w;
assign EXE_op_w = !EXE_op_b & !EXE_op_h;

wire   EXE_is_ls;
wire   EXE_ex_ls_w;
wire   EXE_ex_ls_h;
assign EXE_is_ls   = EXE_mem_we | EXE_res_from_mem;
assign EXE_ex_ls_w = EXE_is_ls & EXE_op_w & (EXE_vaddr[1] | EXE_vaddr[0]);
assign EXE_ex_ls_h = EXE_is_ls & EXE_op_h & EXE_vaddr[0];
assign EXE_ex_ale  = (EXE_ex_ls_h | EXE_ex_ls_w) & ~EXE_ex_adef & ~EXE_ex_ine;
assign EXE_ex_ppi  = ID_ex_ppi | (EXE_tlb_hit & EXE_s1_found & EXE_s1_v & (EXE_crmd_plv > EXE_s1_plv) & EXE_is_ls & EXE_valid);
assign EXE_ex_tlbr = ID_ex_tlbr | (EXE_tlb_hit & ~EXE_s1_found & EXE_is_ls & EXE_valid);
assign EXE_ex_pil  = EXE_res_from_mem & EXE_tlb_hit & EXE_s1_found & ~EXE_s1_v & EXE_valid;
assign EXE_ex_pis  = EXE_mem_we & EXE_tlb_hit & EXE_s1_found & ~EXE_s1_v & EXE_valid;
assign EXE_ex_pme  = EXE_tlb_hit & EXE_s1_found & EXE_s1_v & ~(EXE_crmd_plv > EXE_s1_plv) & ~EXE_s1_d & EXE_is_ls;

assign EXE_s1_found    = EXE_tlbsrch_hit;
assign EXE_s1_index    = EXE_tlbsrch_index;
assign EXE_dmw0_hit = (EXE_alu_result[31:29] == EXE_dmw0_vseg) &
                      ((EXE_crmd_plv == 2'b00 && EXE_dmw0_plv0) | (EXE_crmd_plv == 2'b11 && EXE_dmw0_plv3)) &
                      ~EXE_crmd_da;
assign EXE_dmw1_hit = (EXE_alu_result[31:29] == EXE_dmw1_vseg) & 
                      ((EXE_crmd_plv == 2'b00 && EXE_dmw1_plv0) | (EXE_crmd_plv == 2'b11 && EXE_dmw1_plv3)) &
                      ~EXE_crmd_da;
assign EXE_tlb_hit     = ~EXE_dmw0_hit & ~EXE_dmw1_hit & ~EXE_crmd_da;
assign EXE_inst_cancel = exec_flush | EXE_ex_flush_r;
assign EXE_tlb_paddr = EXE_s1_ps == 6'd21 ? {EXE_s1_ppn[19:9], EXE_alu_result[20:0]} :
                                            {EXE_s1_ppn[19:0], EXE_alu_result[11:0]};
always @(posedge clk) begin
    if (reset)
        EXE_ex_flush_r <= 1'b0;
    else if (exec_flush)
        EXE_ex_flush_r <= 1'b1;
    else if (ID_to_EXE_valid & EXE_allowin)
        EXE_ex_flush_r <= 1'b0;
end

assign data_sram_req      = (EXE_mem_we | EXE_res_from_mem) & EXE_valid & ~EXE_inst_cancel & ~EXE_pre_ex & ~EXE_ex & MEM_allowin;
assign data_sram_wr       = EXE_mem_we & ~EXE_res_from_mem;
assign data_sram_wstrb[0] = data_sram_req & ((EXE_vaddr == 2'b00 & !EXE_op_w) | EXE_op_w);
assign data_sram_wstrb[1] = data_sram_req & ((EXE_vaddr == 2'b00 & EXE_op_h) |
                                             (EXE_vaddr == 2'b01 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_wstrb[2] = data_sram_req & ((EXE_vaddr == 2'b10 & EXE_op_h) |
                                             (EXE_vaddr == 2'b10 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_wstrb[3] = data_sram_req & ((EXE_vaddr == 2'b10 & EXE_op_h) |
                                             (EXE_vaddr == 2'b11 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_addr[28:0] = EXE_tlb_hit ? EXE_tlb_paddr[28:0] : EXE_alu_result[28:0];
assign data_sram_addr[31:29]= {{3{EXE_crmd_da}} & EXE_alu_result[31:29]}
                            | {{3{EXE_dmw0_hit & ~EXE_dmw1_hit}} & EXE_dmw0_pseg}
                            | {{3{EXE_dmw1_hit & ~EXE_dmw0_hit}} & EXE_dmw1_pseg}
                            | {{3{EXE_tlb_hit}} & EXE_tlb_paddr[31:29]};
assign data_sram_wdata    = EXE_op_b ? {4{EXE_rkd_value[ 7:0]}} :
                            EXE_op_h ? {2{EXE_rkd_value[15:0]}} :
                            EXE_rkd_value[31:0];
assign data_sram_size[0]  = EXE_op_h;
assign data_sram_size[1]  = EXE_op_w; 

alu alu(
    .alu_op     (EXE_alu_op    ),
    .alu_src1   (EXE_alu_src1  ),
    .alu_src2   (EXE_alu_src2  ),
    .alu_result (EXE_alu_result)
);
Booth_Wallace_Mux u_mux (
    .mul_clk(clk           ),
    .reset  (reset         ),
    .mul_op (EXE_mul_op    ),
    .X      (EXE_alu_src1  ),
    .Y      (EXE_alu_src2  ),
    .result (EXE_mul_result)
);
mydiv my_signed_div(
    .aclk(clk),
    .s_axis_divisor_tdata(EXE_rkd_value),
    .s_axis_divisor_tready(EXE_div_divisor_ready),
    .s_axis_divisor_tvalid(EXE_div_divisor_valid),
    .s_axis_dividend_tdata(EXE_rj_value),
    .s_axis_dividend_tready(EXE_div_dividend_ready),
    .s_axis_dividend_tvalid(EXE_div_dividend_valid),
    .m_axis_dout_tdata(EXE_div_out),
    .m_axis_dout_tvalid(EXE_div_out_valid)
);
mydivu my_signed_divu(
    .aclk(clk),
    .s_axis_divisor_tdata(EXE_rkd_value),
    .s_axis_divisor_tready(EXE_divu_divisor_ready),
    .s_axis_divisor_tvalid(EXE_divu_divisor_valid),
    .s_axis_dividend_tdata(EXE_rj_value),
    .s_axis_dividend_tready(EXE_divu_dividend_ready),
    .s_axis_dividend_tvalid(EXE_divu_dividend_valid),
    .m_axis_dout_tdata(EXE_divu_out),
    .m_axis_dout_tvalid(EXE_divu_out_valid)
);

endmodule
