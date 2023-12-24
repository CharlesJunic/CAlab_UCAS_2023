module EXE_stage(
    input clk,
    input reset,
    input MEM_allowin,
    output EXE_allowin,
    input ID_to_EXE_valid,
    input [197:0] ID_to_EXE_bus,
    output EXE_to_MEM_valid,
    output [212:0] EXE_to_MEM_bus,
    output data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    output out_EXE_valid,
    input exec_flush
);

reg EXE_valid;
wire EXE_ready_go;
reg [197:0] ID_to_EXE_bus_rf;
wire [31:0] EXE_alu_src1;
wire [31:0] EXE_alu_src2;
wire [11:0] EXE_alu_op;
wire [31:0] EXE_alu_result;
wire [31:0] EXE_rj_value;
wire [31:0] EXE_rkd_value;
wire [31:0] EXE_imm;
wire [31:0] EXE_pc;
wire [4:0] EXE_dest;
wire EXE_src1_is_pc;
wire EXE_src2_is_imm;
wire EXE_res_from_mem;
wire EXE_gr_we;
wire EXE_mem_we;
wire [31:0] EXE_result;
wire [32:0] EXE_mult_src1;
wire [32:0] EXE_mult_src2;
wire [65:0] EXE_mult_result_all;
wire [31:0] EXE_mult_result;
wire [63:0] EXE_divu_out;
wire [63:0] EXE_div_out;
wire [31:0] EXE_div_result;
wire [31:0] EXE_mod_result;
wire [ 1:0] EXE_vaddr;
wire EXE_op_unsigned_md;
wire EXE_op_unsigned_ld;
wire EXE_op_b;
wire EXE_op_h;
wire EXE_op_mul;
wire EXE_op_mulh;
wire EXE_op_div;
wire EXE_op_mod;
wire EXE_op_divmod_u;
wire EXE_op_divmod;
wire EXE_div_in_ready;
wire EXE_divu_in_ready;
wire EXE_div_divisor_ready;
wire EXE_div_dividend_ready;
reg EXE_div_divisor_valid;
reg EXE_div_dividend_valid;
wire EXE_divu_divisor_ready;
wire EXE_divu_dividend_ready;
reg EXE_divu_divisor_valid;
reg EXE_divu_dividend_valid;
wire EXE_div_out_valid;
wire EXE_divu_out_valid;
reg EXE_div_valid;
reg EXE_divu_valid;
wire EXE_inst_csrrd;
wire EXE_inst_csrwr;
wire EXE_inst_csrxchg;
wire EXE_inst_syscall;
wire EXE_inst_ertn;
wire [14:0] EXE_ex_code;
wire [13:0] EXE_csr_num;
reg EXE_pre_ex;
wire EXE_ex_adef;
wire EXE_ex_ine;
wire EXE_ex_ale;
wire EXE_inst_brk;
wire EXE_inst_rdcntid;
wire EXE_inst_rdcntvl_w;
wire EXE_inst_rdcntvh_w;
wire [31:0] EXE_ex_baddr;
wire EXE_ex;

always@(posedge clk) begin
    if(reset)
        EXE_pre_ex <= 1'b0;
    else if(~exec_flush & EXE_ex & EXE_valid)
        EXE_pre_ex <= 1'b1;
    else if(exec_flush)
        EXE_pre_ex <= 1'b0;
end

assign EXE_ex_baddr = data_sram_addr;
assign EXE_ex = EXE_ex_adef | EXE_ex_ine | EXE_ex_ale | EXE_inst_syscall | EXE_inst_brk | EXE_inst_ertn;

assign EXE_op_divmod = (EXE_op_div | EXE_op_mod) & ~EXE_op_unsigned_md;
assign EXE_op_divmod_u = (EXE_op_div | EXE_op_mod) & EXE_op_unsigned_md;
assign EXE_mult_src1 = {~EXE_op_unsigned_md & EXE_rj_value[31], EXE_rj_value[31:0]};
assign EXE_mult_src2 = {~EXE_op_unsigned_md & EXE_rkd_value[31], EXE_rkd_value[31:0]};
assign EXE_mult_result_all = $signed(EXE_mult_src1) * $signed(EXE_mult_src2);
assign EXE_mult_result = EXE_op_mul ? EXE_mult_result_all[31:0] : EXE_mult_result_all[63:32];
assign EXE_div_result = EXE_op_unsigned_md ? EXE_divu_out[63:32] : EXE_div_out[63:32];
assign EXE_mod_result = EXE_op_unsigned_md ? EXE_divu_out[31:0] : EXE_div_out[31:0];
assign EXE_div_in_ready = ~EXE_op_unsigned_md & (EXE_div_divisor_ready & EXE_div_dividend_ready);
assign EXE_divu_in_ready = EXE_op_unsigned_md & (EXE_divu_divisor_ready & EXE_divu_dividend_ready);

always @(posedge clk) begin
    if(reset) begin
        EXE_div_valid <= 1'b0;
        EXE_div_divisor_valid <= 1'b0;
        EXE_div_dividend_valid <= 1'b0;
    end
    else if(EXE_op_divmod & ~EXE_div_valid) begin
        EXE_div_valid <= 1'b1;
        EXE_div_divisor_valid <= 1'b1;
        EXE_div_dividend_valid <= 1'b1;
    end
    else if(EXE_div_valid & EXE_div_in_ready) begin
        EXE_div_divisor_valid <= 1'b0;
        EXE_div_dividend_valid <= 1'b0;
    end
    else if(EXE_div_valid & EXE_div_out_valid) begin
        EXE_div_valid <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        EXE_divu_valid <= 1'b0;
        EXE_divu_divisor_valid <= 1'b0;
        EXE_divu_dividend_valid <= 1'b0;
    end
    else if(EXE_op_divmod_u & ~EXE_divu_valid) begin
        EXE_divu_valid <= 1'b1;
        EXE_divu_divisor_valid <= 1'b1;
        EXE_divu_dividend_valid <= 1'b1;
    end
    else if(EXE_divu_valid & EXE_divu_in_ready) begin
        EXE_divu_divisor_valid <= 1'b0;
        EXE_divu_dividend_valid <= 1'b0;
    end
    else if(EXE_divu_valid & EXE_divu_out_valid) begin
        EXE_divu_valid <= 1'b0;
    end
end

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

assign EXE_ready_go = (EXE_op_divmod & EXE_div_out_valid) |
                     (EXE_op_divmod_u & EXE_divu_out_valid) |
                     (~EXE_op_div & ~EXE_op_mod);
assign EXE_allowin = !EXE_valid || EXE_ready_go && MEM_allowin;
assign EXE_to_MEM_valid = EXE_valid && EXE_ready_go;
assign out_EXE_valid = EXE_valid;

assign EXE_to_MEM_bus[212:0] = {
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
    EXE_rkd_value[31:0],     //126:95
    EXE_inst_syscall,        //94
    EXE_inst_ertn,           //93
    EXE_inst_csrrd,          //92
    EXE_inst_csrwr,          //91
    EXE_inst_csrxchg,        //90
    EXE_csr_num[13:0],       //89:76
    EXE_vaddr[1:0],          //75:74
    EXE_op_unsigned_ld,      //73:73
    EXE_op_b,                //72:72
    EXE_op_h,                //71:71
    EXE_pc[31:0],            //70:39
    EXE_result[31:0],        //38:7
    EXE_res_from_mem,        //6:6
    EXE_gr_we,               //5:5
    EXE_dest[4:0]            //4:0
};

always @(posedge clk) begin
    if(reset) 
        EXE_valid <= 1'b0;
    else if(exec_flush)
        EXE_valid <= 1'b0;
    else if(EXE_allowin)
        EXE_valid <= ID_to_EXE_valid;
end

always @(posedge clk) begin
    if(EXE_allowin && ID_to_EXE_valid)
        ID_to_EXE_bus_rf <= ID_to_EXE_bus;
end

assign {
    EXE_ex_adef,
    EXE_ex_ine,
    EXE_inst_brk,
    EXE_inst_rdcntid,
    EXE_inst_rdcntvl_w,
    EXE_inst_rdcntvh_w,
    EXE_ex_code[14:0],     
    EXE_inst_syscall,      
    EXE_inst_ertn,         
    EXE_inst_csrrd,        
    EXE_inst_csrwr,       
    EXE_inst_csrxchg,     
    EXE_csr_num[13:0],     
    EXE_op_unsigned_ld,
    EXE_op_b,
    EXE_op_h,
    EXE_op_unsigned_md,
    EXE_op_mul,
    EXE_op_mulh,
    EXE_op_div,
    EXE_op_mod,
    EXE_pc[31:0],
    EXE_rj_value[31:0],
    EXE_rkd_value[31:0],
    EXE_imm[31:0],
    EXE_src1_is_pc,
    EXE_src2_is_imm,
    EXE_res_from_mem,
    EXE_gr_we,
    EXE_mem_we,
    EXE_dest[4:0],
    EXE_alu_op[11:0] } = ID_to_EXE_bus_rf[197:0];

assign EXE_alu_src1 = EXE_src1_is_pc  ? EXE_pc[31:0] : EXE_rj_value;
assign EXE_alu_src2 = EXE_src2_is_imm ? EXE_imm : EXE_rkd_value;

alu alu(
    .alu_op     (EXE_alu_op    ),
    .alu_src1   (EXE_alu_src1  ),
    .alu_src2   (EXE_alu_src2  ),
    .alu_result (EXE_alu_result)
);

assign EXE_result = {32{EXE_op_mul | EXE_op_mulh}} & EXE_mult_result[31:0] |
                   {32{EXE_op_mod}} & EXE_mod_result[31:0] |
                   {32{EXE_op_div}} & EXE_div_result[31:0] |
                   {32{~EXE_op_mul & ~EXE_op_mulh & ~EXE_op_div & ~EXE_op_mod}} & EXE_alu_result[31:0];
assign EXE_vaddr = EXE_alu_result[1:0];

wire data_sram_valid;
wire EXE_op_w;

assign data_sram_valid = EXE_mem_we & EXE_valid & ~exec_flush & ~EXE_pre_ex & ~EXE_ex;
//assign data_sram_valid = EXE_mem_we & EXE_valid & ~exec_flush & ~EXE_pre_ex;
assign EXE_op_w = !EXE_op_b & !EXE_op_h;
//assign data_sram_en = 1'b1;
assign data_sram_en = ~exec_flush;

wire EXE_is_ls;
wire EXE_ex_ls_w;
wire EXE_ex_ls_h;
assign EXE_is_ls = EXE_mem_we | EXE_res_from_mem;
assign EXE_ex_ls_w = EXE_is_ls & EXE_op_w & (EXE_vaddr[1] | EXE_vaddr[0]);
assign EXE_ex_ls_h = EXE_is_ls & EXE_op_h & EXE_vaddr[0];
assign EXE_ex_ale = (EXE_ex_ls_h | EXE_ex_ls_w) & ~EXE_ex_adef & ~EXE_ex_ine;

assign data_sram_wen[0] = data_sram_valid & ((EXE_vaddr == 2'b00 & !EXE_op_w) | EXE_op_w);
assign data_sram_wen[1] = data_sram_valid & ((EXE_vaddr == 2'b00 & EXE_op_h) |
                                             (EXE_vaddr == 2'b01 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_wen[2] = data_sram_valid & ((EXE_vaddr == 2'b10 & EXE_op_h) |
                                             (EXE_vaddr == 2'b10 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_wen[3] = data_sram_valid & ((EXE_vaddr == 2'b10 & EXE_op_h) |
                                             (EXE_vaddr == 2'b11 & EXE_op_b) |
                                              EXE_op_w);
assign data_sram_addr = EXE_alu_result;
assign data_sram_wdata = EXE_op_b ? {4{EXE_rkd_value[ 7:0]}} :
                         EXE_op_h ? {2{EXE_rkd_value[15:0]}} :
                         EXE_rkd_value[31:0];

endmodule