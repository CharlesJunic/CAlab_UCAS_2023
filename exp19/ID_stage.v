module ID_stage(
    input          clk,
    input          reset,
    input          EXE_allowin,
    output         ID_allowin,
    input          IF_to_ID_valid,
    input  [ 99:0] IF_to_ID_bus,
    output         ID_to_EXE_valid,
    output [245:0] ID_to_EXE_bus,
    output [ 33:0] br_bus,
    input  [ 52:0] WB_to_ID_bus,
    input          out_WB_valid,
    input  [212:0] EXE_to_MEM_bus,
    input          out_EXE_valid,
    input  [206:0] MEM_to_WB_bus,
    input          out_MEM_valid,
    input          exec_flush,
    input          data_sram_data_ok
);

`define CSR_CRMD            14'h0000
`define CSR_PRMD            14'h0001
`define CSR_EUEN            14'h0002
`define CSR_ECFG            14'h0004
`define CSR_ESTAT           14'h0005
`define CSR_ERA             14'h0006
`define CSR_BADV            14'h0007
`define CSR_EENTRY          14'h000c
`define CSR_TLBIDX          14'h0010
`define CSR_TLBEHI          14'h0011
`define CSR_TLBELO0         14'h0012
`define CSR_TLBELO1         14'h0013
`define CSR_ASID            14'h0018
`define CSR_PGDL            14'h0019
`define CSR_PGDH            14'h001A
`define CSR_PGD             14'h001B
`define CSR_CPUID           14'h0020
`define CSR_SAVE0           14'h0030
`define CSR_SAVE1           14'h0031
`define CSR_SAVE2           14'h0032
`define CSR_SAVE3           14'h0033
`define CSR_TID             14'h0040
`define CSR_TCFG            14'h0041
`define CSR_TVAL            14'h0042
`define CSR_TICLR           14'h0044
`define CSR_LLBCTL          14'h0060
`define CSR_TLBRENTRY       14'h0088
`define CSR_CTAG            14'h0098
`define CSR_DMW0            14'h0180
`define CSR_DMW1            14'h0181

reg         ID_valid;
wire        ID_ready_go;
wire        br_taken;
wire        rf_conflict;
wire [31:0] ID_inst;
wire [31:0] ID_pc;
wire [31:0] IF_pc;
wire        ID_ex_adef;
wire        ID_ex_ppi;
wire        ID_ex_pif;
wire        ID_ex_tlbr;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
reg  [99:0] IF_to_ID_bus_rf;
wire        EXE_csr_needwr;
wire        MEM_csr_needwr;
wire        WB_csr_needwr;
wire [13:0] EXE_csr_num;
wire [13:0] MEM_csr_num;
wire [13:0] WB_csr_num;
wire        ID_tlb_blk;
wire        EXE_tlb_blk;
wire        MEM_tlb_blk;
wire        WB_tlb_blk;
wire [31:0] ID_ex_baddr;

assign ID_ready_go = ((rf_conflict | ID_tlb_blk) & ~exec_flush) ? 1'b0 : 1'b1;

always @(posedge clk) begin
    if (reset)
        ID_valid <= 1'b0;
    else if (exec_flush)
        ID_valid <= 1'b0;
    //else if (br_taken & ID_ready_go) begin
    else if (br_taken & ID_ready_go & IF_to_ID_valid) begin
        ID_valid <= 1'b0;
    end
    else if (ID_allowin)
        ID_valid <= IF_to_ID_valid;
end

assign ID_allowin = !ID_valid | ID_ready_go & EXE_allowin;

always @(posedge clk) begin
    if (ID_allowin & IF_to_ID_valid) 
        IF_to_ID_bus_rf <= IF_to_ID_bus;
end

assign IF_pc[31:0] = IF_to_ID_bus[31:0];
assign {
    ID_ex_baddr[31:0],
    ID_ex_ppi,
    ID_ex_pif,
    ID_ex_tlbr,
    ID_ex_adef,
    ID_inst[31:0],
    ID_pc[31:0]
} = IF_to_ID_bus_rf[99:0];

assign {
    WB_csr_needwr,
    WB_csr_num[13:0],
    rf_we,
    rf_waddr[4:0],
    rf_wdata[31:0]
} = WB_to_ID_bus[52:0];

wire [31:0] br_target;
wire        ID_br_stall;
wire [11:0] alu_op;
wire [ 2:0] mul_op;
wire [ 4:0] invtlb_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_ltu_rd;
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
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;
wire        op_mulh;
wire        op_mul;
wire        op_div;
wire        op_mod;
wire        op_unsigned_md;     //mul,mulh,div,divu,mod,modu
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
wire        op_unsigned_ld;      //ld_bu,ld_hu
wire        op_b;
wire        op_h;
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_syscall;
wire        inst_ertn;
wire [13:0] csr_num;
wire [14:0] ex_code;
wire        rj_conflict_from_csr;
wire        rkd_conflict_from_csr;
wire        EXE_is_csr_inst;
wire        MEM_is_csr_inst;
wire        ID_ex_ine;
wire        inst_brk;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;
wire        dst_is_rj;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

wire        need_ui5;
wire        need_ui12;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rj_zero;
wire        rkd_zero;
wire        rj_con_EXE;
wire        rj_con_MEM;
wire        rj_con_WB;
wire        rkd_con_EXE;
wire        rkd_con_MEM;
wire        rkd_con_WB;
wire        rj_con_from_mem;
wire        rkd_con_from_mem;

assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];
assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];
assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w    = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w      = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w      = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl      = op_31_26_d[6'h13];
assign inst_b         = op_31_26_d[6'h14];
assign inst_bl        = op_31_26_d[6'h15];
assign inst_beq       = op_31_26_d[6'h16];
assign inst_bne       = op_31_26_d[6'h17];
assign inst_lu12i_w   = op_31_26_d[6'h05] & ~ID_inst[25];
assign inst_slti      = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui     = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi      = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori       = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori      = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e]; 
assign inst_srl_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ID_inst[25];
assign inst_mul_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_blt       = op_31_26_d[6'h18];
assign inst_bge       = op_31_26_d[6'h19];
assign inst_bltu      = op_31_26_d[6'h1a];
assign inst_bgeu      = op_31_26_d[6'h1b];
assign inst_ld_b      = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h      = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu     = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu     = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b      = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h      = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_csrrd     = op_31_26_d[6'h01] & op_25_22_d[4'h0] & rj==5'b0;
assign inst_csrwr     = op_31_26_d[6'h01] & op_25_22_d[4'h0] & rj==5'b1;
assign inst_csrxchg   = op_31_26_d[6'h01] & op_25_22_d[4'h0] & rj[4:1]!=4'b0;
assign inst_syscall   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_ertn      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk==5'h0e;
assign inst_brk       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk==5'h18 & rd==5'h00;
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk==5'h18 & rj==5'h00;
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk==5'h19 & rj==5'h00;
assign inst_tlbsrch   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk==5'h0a;
assign inst_tlbrd     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk==5'h0b;
assign inst_tlbwr     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk==5'h0c;
assign inst_tlbfill   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk==5'h0d;
assign inst_invtlb    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign op_mul         = inst_mul_w;
assign op_mulh        = inst_mulh_w | inst_mulh_wu;
assign op_div         = inst_div_w | inst_div_wu;
assign op_mod         = inst_mod_w | inst_mod_wu;
assign op_unsigned_md = inst_mulh_wu | inst_div_wu | inst_mod_wu;
assign op_b           = inst_ld_b | inst_ld_bu | inst_st_b;
assign op_h           = inst_ld_h | inst_ld_hu | inst_st_h;
assign op_unsigned_ld = inst_ld_bu | inst_ld_hu;

assign csr_num        = ID_inst[23:10];
assign ex_code[14: 9] = 5'h0b;
assign ex_code[ 8: 0] = 9'h000;

assign ID_ex_ine = (alu_op == 12'b0) 
                 & ~need_si16 & ~need_si26 & ~need_si20 & ~op_mul & ~op_mulh & ~op_div & ~op_mod
                 & ~inst_csrrd & ~inst_csrwr & ~inst_csrxchg & ~inst_syscall & ~inst_ertn
                 & ~inst_brk & ~inst_rdcntid & ~inst_rdcntvl_w & ~inst_rdcntvh_w & ~ID_ex_adef 
                 & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w |
                    inst_jirl | inst_bl | inst_pcaddu12i |
                    inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign mul_op[ 0] = inst_mul_w;
assign mul_op[ 1] = inst_mulh_w;
assign mul_op[ 2] = inst_mulh_wu;
assign invtlb_op  = rd;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui |
                     inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu |
                     inst_st_b | inst_st_h;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bgeu | inst_bltu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4               :
             need_si20 ? {i20[19:0], 12'b0}  :
             need_ui12 ? {20'b0, i12[11:0]}  :
/*need_ui5 | need_si12*/{{20{i12[11]}}, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | 
                       inst_blt | inst_bge | inst_bltu | inst_bgeu |
                       inst_st_h | inst_st_b |
                       inst_csrrd | inst_csrwr | inst_csrxchg |
                       inst_rdcntvl_w | inst_rdcntvh_w;
assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
assign src2_is_imm   =  inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   |
                        inst_st_w   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     |
                        inst_slti   |
                        inst_sltui  |
                        inst_andi   |
                        inst_ori    |
                        inst_xori   |
                        inst_pcaddu12i |
                        inst_ld_b   |
                        inst_ld_bu  |
                        inst_ld_h   |
                        inst_ld_hu  |
                        inst_st_b   |
                        inst_st_h;

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b &
                           ~inst_st_b & ~inst_st_h & ~inst_blt & ~inst_bge & ~inst_bgeu & ~inst_bltu &
                           ~inst_syscall & ~inst_ertn & ~inst_brk & ~ID_ex_ine & ~inst_tlbsrch & 
                           ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb;
assign dst_is_rj     = inst_rdcntid;
assign dest          = dst_is_r1 ? 5'd1 :
                           dst_is_rj ? rj : rd;

assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign rj_eq_rd      = rj_value == rkd_value;
    
assign rj_lt_rd  = $signed(rj_value) < $signed(rkd_value);
assign rj_ltu_rd = rj_value < rkd_value;

assign br_taken = (inst_beq  &&  rj_eq_rd
                || inst_bne  && !rj_eq_rd
                || inst_blt  &&  rj_lt_rd
                || inst_bge  && !rj_lt_rd
                || inst_bltu &&  rj_ltu_rd
                || inst_bgeu && !rj_ltu_rd
                || inst_jirl
                || inst_bl
                || inst_b  ) && ID_valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b ||
                    inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ID_pc + br_offs) :
                                                        /*inst_jirl*/ (rj_value + jirl_offs);

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;
regfile u_regfile(
    .clk (clk),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);

assign rj_zero         = rf_raddr1 == 5'b0;
assign rj_con_EXE      = out_EXE_valid & (EXE_to_MEM_bus[4:0] == rf_raddr1) & EXE_to_MEM_bus[5];
assign rj_con_from_mem = (rj_con_EXE & EXE_to_MEM_bus[6]) | (rj_con_MEM & ~data_sram_data_ok);
assign rj_con_MEM      = ~rj_con_EXE & out_MEM_valid & (MEM_to_WB_bus[36:32] == rf_raddr1) & MEM_to_WB_bus[37];
assign rj_con_WB       = ~rj_con_MEM & ~rj_con_EXE & out_WB_valid & WB_to_ID_bus[37] & (WB_to_ID_bus[36:32] == rf_raddr1);

assign rj_value  = {32{~rj_zero & rj_con_EXE}} & EXE_to_MEM_bus[38:7] |
                   {32{~rj_zero & rj_con_MEM}} & MEM_to_WB_bus[31:0] |
                   {32{~rj_zero & rj_con_WB}} & WB_to_ID_bus[31:0] |
                   {32{~rj_con_EXE & ~rj_con_MEM & ~rj_con_WB}} & rf_rdata1[31:0];

assign rkd_zero         = rf_raddr2 == 5'b0;
assign rkd_con_EXE      = out_EXE_valid & (EXE_to_MEM_bus[4:0] == rf_raddr2) & EXE_to_MEM_bus[5];
assign rkd_con_from_mem = (rkd_con_EXE & EXE_to_MEM_bus[6]) | (rkd_con_MEM & ~data_sram_data_ok);
assign rkd_con_MEM      = ~rkd_con_EXE & out_MEM_valid && (MEM_to_WB_bus[36:32] == rf_raddr2) & MEM_to_WB_bus[37];
assign rkd_con_WB       = ~rkd_con_EXE & ~rkd_con_MEM & out_WB_valid & WB_to_ID_bus[37] & (WB_to_ID_bus[36:32] == rf_raddr2);

assign rkd_value = {32{~rkd_zero & rkd_con_EXE}} & EXE_to_MEM_bus[38:7] |
                   {32{~rkd_zero & rkd_con_MEM}} & MEM_to_WB_bus[31:0] |
                   {32{~rkd_zero & rkd_con_WB }} & WB_to_ID_bus[31:0] |
                   {32{~rkd_con_EXE & ~rkd_con_MEM & ~rkd_con_WB}} & rf_rdata2[31:0];

assign EXE_is_csr_inst = EXE_to_MEM_bus[ 90] | EXE_to_MEM_bus[ 91] | EXE_to_MEM_bus[ 92]
                       | EXE_to_MEM_bus[174] | EXE_to_MEM_bus[175] | EXE_to_MEM_bus[176];
assign MEM_is_csr_inst = MEM_to_WB_bus[ 84] | MEM_to_WB_bus[ 85] | MEM_to_WB_bus[ 86]
                       | MEM_to_WB_bus[168] | MEM_to_WB_bus[169] | MEM_to_WB_bus[170];
assign rj_conflict_from_csr  = ( rj_con_EXE & EXE_is_csr_inst) | ( rj_con_MEM & MEM_is_csr_inst);
assign rkd_conflict_from_csr = (rkd_con_EXE & EXE_is_csr_inst) | (rkd_con_MEM & MEM_is_csr_inst);

assign rf_conflict = (~rj_zero  & (rj_con_from_mem  | rj_conflict_from_csr ))
                   | (~rkd_zero & (rkd_con_from_mem | rkd_conflict_from_csr));

assign ID_to_EXE_valid = ID_valid && ID_ready_go;
assign ID_to_EXE_bus[245:0] = {
    ID_ex_baddr[31:0],  //245:214
    ID_ex_pif,          //213
    ID_ex_ppi,          //212
    ID_ex_tlbr,         //211
    invtlb_op[4:0],     //210:206
    inst_tlbsrch,       //205
    inst_tlbrd,         //204
    inst_tlbwr,         //203
    inst_tlbfill,       //202
    inst_invtlb,        //201
	mul_op,             //200:198
	ID_ex_adef,         //197
	ID_ex_ine,          //196
	inst_brk,           //195
	inst_rdcntid,       //194
	inst_rdcntvl_w,     //193
	inst_rdcntvh_w,     //192
	ex_code[14:0],      //191:177
	inst_syscall,       //176
	inst_ertn,          //175
	inst_csrrd,         //174
	inst_csrwr,         //173
	inst_csrxchg,       //172
	csr_num[13:0],      //171:158
	op_unsigned_ld,     //157:157
	op_b,               //156:156
	op_h,               //155:155
	op_unsigned_md,     //154:154
	op_mul,             //153:153
	op_mulh,            //152:152
	op_div,             //151:151
	op_mod,             //150:150
	ID_pc[31:0],        //149:118
	rj_value[31:0],     //117:86
	rkd_value[31:0],    //85:54
	imm[31:0],          //53:22
	src1_is_pc,         //21:21
	src2_is_imm,        //20:20     
	res_from_mem,       //19:19
	gr_we,              //18:18
	mem_we,             //17:17
	dest[4:0],          //16:12
	alu_op[11:0]        //11:0
};

assign ID_br_stall  = ~ID_ready_go & ID_valid;
assign br_bus[33:0] = {ID_br_stall, br_taken, br_target[31:0]};

assign EXE_csr_needwr = EXE_to_MEM_bus[90] | EXE_to_MEM_bus[91];
assign MEM_csr_needwr = MEM_to_WB_bus[85] | MEM_to_WB_bus[84];
assign EXE_csr_num    = EXE_to_MEM_bus[89:76];
assign MEM_csr_num    = MEM_to_WB_bus[83:70];

assign ID_tlb_blk  = (EXE_tlb_blk & out_EXE_valid) 
                   | (MEM_tlb_blk & out_MEM_valid)
                   | (WB_tlb_blk  & out_WB_valid );
assign EXE_tlb_blk = (inst_tlbsrch | inst_invtlb)
                   & ((EXE_csr_needwr & (EXE_csr_num == `CSR_ASID | EXE_csr_num == `CSR_TLBEHI))
                    | (EXE_to_MEM_bus[92] & EXE_csr_num == `CSR_TLBIDX)
                    | EXE_to_MEM_bus[217] | EXE_to_MEM_bus[216] | EXE_to_MEM_bus[215]);
assign MEM_tlb_blk = (inst_tlbsrch | inst_invtlb)
                   & ((MEM_csr_needwr & (MEM_csr_num == `CSR_ASID | MEM_csr_num == `CSR_TLBEHI))
                    | (MEM_to_WB_bus[86] & MEM_csr_num == `CSR_TLBIDX)
                    |  MEM_to_WB_bus[210] | MEM_to_WB_bus[209] | MEM_to_WB_bus[208]);
assign WB_tlb_blk = (WB_csr_needwr & WB_csr_num == `CSR_TLBIDX) & inst_tlbsrch;
endmodule
