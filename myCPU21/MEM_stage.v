module MEM_stage(
    input          clk,
    input          reset,
    input          WB_allowin,
    output         MEM_allowin,
    input          EXE_to_MEM_valid,
    input  [230:0] EXE_to_MEM_bus,
    output         MEM_to_WB_valid,
    output [223:0] MEM_to_WB_bus,
    input  [ 31:0] data_sram_rdata,
    input          data_sram_data_ok,
    output         out_MEM_valid,
    input          exec_flush
);

wire [ 31:0] MEM_pc;
wire [ 31:0] MEM_mem_result;
wire [ 31:0] MEM_alu_result;
wire [ 31:0] MEM_final_result;
wire [ 31:0] MEM_ld_result;
wire [  4:0] MEM_dest;
wire [  1:0] MEM_vaddr;
wire         MEM_res_from_mem;
wire         MEM_gr_we;
wire         MEM_mem_we;
wire         MEM_op_b;
wire         MEM_op_h;
wire         MEM_op_unsigned_ld;
wire [ 31:0] MEM_rj_value;
wire [ 31:0] MEM_rkd_value;
wire         MEM_inst_csrrd;
wire         MEM_inst_csrwr;
wire         MEM_inst_csrxchg;
wire         MEM_inst_syscall;
wire         MEM_inst_ertn;
wire [ 14:0] MEM_ex_code;
wire [ 13:0] MEM_csr_num;
wire         MEM_ex_adef;
wire         MEM_ex_ine;
wire         MEM_ex_ale;
wire         MEM_inst_brk;
wire         MEM_inst_rdcntid;
wire         MEM_inst_rdcntvl_w;
wire         MEM_inst_rdcntvh_w;
wire [ 31:0] MEM_ex_baddr;
wire         MEM_ex;
reg          MEM_valid;
wire         MEM_ready_go;
reg  [230:0] EXE_to_MEM_bus_rf;
wire         MEM_inst_tlbsrch;
wire         MEM_tlbsrch_hit;
wire [  3:0] MEM_tlbsrch_index;
wire         MEM_inst_tlbrd;
wire         MEM_inst_tlbwr;
wire         MEM_inst_tlbfill;
wire         MEM_inst_invtlb;
wire         MEM_ex_pif;
wire         MEM_ex_pil;
wire         MEM_ex_pis;
wire         MEM_ex_ppi;
wire         MEM_ex_pme;
wire         MEM_ex_tlbr;
wire         MEM_refetch_flush;
assign MEM_ex = MEM_ex_adef |
                MEM_ex_ale  |
                MEM_ex_ine |
                MEM_inst_syscall |
                MEM_inst_brk |
                MEM_inst_ertn |
                MEM_ex_ppi |
                MEM_ex_pif |
                MEM_ex_tlbr |
                MEM_ex_pil |
                MEM_ex_pis |
                MEM_ex_pme;

assign MEM_ready_go = (MEM_res_from_mem | MEM_mem_we) ? (data_sram_data_ok | exec_flush | MEM_ex) : 1'b1;
assign MEM_allowin = !MEM_valid || MEM_ready_go && WB_allowin;
assign out_MEM_valid = MEM_valid;

always @(posedge clk) begin
    if(reset)
        MEM_valid <= 1'b0;
    else if(exec_flush)
        MEM_valid <= 1'b0;
    else if(MEM_allowin)
        MEM_valid <= EXE_to_MEM_valid;
end

always @(posedge clk) begin
    if(MEM_allowin && EXE_to_MEM_valid)
        EXE_to_MEM_bus_rf <= EXE_to_MEM_bus;
end

assign {
    MEM_refetch_flush,
    MEM_ex_pif,
    MEM_ex_pil,
    MEM_ex_pis,
    MEM_ex_ppi,
    MEM_ex_pme,
    MEM_ex_tlbr,
    MEM_inst_tlbsrch,
    MEM_tlbsrch_hit,
    MEM_tlbsrch_index[3:0],
    MEM_inst_tlbrd,
    MEM_inst_tlbwr,
    MEM_inst_tlbfill,
    MEM_inst_invtlb,
    MEM_mem_we,
    MEM_ex_adef,
    MEM_ex_ine,
    MEM_ex_ale,
    MEM_ex_baddr[31:0],
    MEM_inst_brk,
    MEM_inst_rdcntid,
    MEM_inst_rdcntvl_w,
    MEM_inst_rdcntvh_w,
    MEM_ex_code[14:0],    
    MEM_rj_value[31:0],     
    MEM_rkd_value[31:0],    
    MEM_inst_syscall,       
    MEM_inst_ertn,           
    MEM_inst_csrrd,        
    MEM_inst_csrwr,       
    MEM_inst_csrxchg,       
    MEM_csr_num[13:0],     
    MEM_vaddr,
    MEM_op_unsigned_ld,
    MEM_op_b,
    MEM_op_h,
    MEM_pc[31:0],
    MEM_alu_result[31:0],
    MEM_res_from_mem,
    MEM_gr_we,
    MEM_dest[4:0] 
} = EXE_to_MEM_bus_rf[229:0];

assign MEM_mem_result = data_sram_rdata;
assign MEM_ld_result  = {32{MEM_op_b & MEM_vaddr == 2'b00}} & {{24{~MEM_op_unsigned_ld & MEM_mem_result[ 7]}},MEM_mem_result[ 7: 0]} |
                        {32{MEM_op_b & MEM_vaddr == 2'b01}} & {{24{~MEM_op_unsigned_ld & MEM_mem_result[15]}},MEM_mem_result[15: 8]} |
                        {32{MEM_op_b & MEM_vaddr == 2'b10}} & {{24{~MEM_op_unsigned_ld & MEM_mem_result[23]}},MEM_mem_result[23:16]} |
                        {32{MEM_op_b & MEM_vaddr == 2'b11}} & {{24{~MEM_op_unsigned_ld & MEM_mem_result[31]}},MEM_mem_result[31:24]} |
                        {32{MEM_op_h & MEM_vaddr == 2'b00}} & {{16{~MEM_op_unsigned_ld & MEM_mem_result[15]}},MEM_mem_result[15: 0]} |
                        {32{MEM_op_h & MEM_vaddr == 2'b10}} & {{16{~MEM_op_unsigned_ld & MEM_mem_result[31]}},MEM_mem_result[31:16]} |
                        {32{~MEM_op_b & ~MEM_op_h}} & MEM_mem_result[31:0];
assign MEM_final_result = MEM_res_from_mem ? MEM_ld_result : MEM_alu_result;
assign MEM_to_WB_valid  = MEM_valid && MEM_ready_go;

assign MEM_to_WB_bus[223:0] = {
    MEM_refetch_flush,      //223
    MEM_ex_pif,             //222
    MEM_ex_pil,             //221
    MEM_ex_pis,             //220
    MEM_ex_ppi,             //219
    MEM_ex_pme,             //218
    MEM_ex_tlbr,            //217
    MEM_inst_tlbsrch,       //216
    MEM_tlbsrch_hit,        //215
    MEM_tlbsrch_index[3:0], //214:211
    MEM_inst_tlbrd,         //210
    MEM_inst_tlbwr,         //209
    MEM_inst_tlbfill,       //208
    MEM_inst_invtlb,        //207
    MEM_ex_adef,            //206
    MEM_ex_ine,             //205
    MEM_ex_ale,             //204
    MEM_ex_baddr[31:0],     //203:172
    MEM_inst_brk,           //171
    MEM_inst_rdcntid,       //170
    MEM_inst_rdcntvl_w,     //169
    MEM_inst_rdcntvh_w,     //168
    MEM_ex_code[14:0],      //167:153
    MEM_rj_value[31:0],     //152:121
    MEM_rkd_value[31:0],    //120:89
    MEM_inst_syscall,       //88:88
    MEM_inst_ertn,          //87:87
    MEM_inst_csrrd,         //86:86
    MEM_inst_csrwr,         //85:85
    MEM_inst_csrxchg,       //84:84
    MEM_csr_num[13:0],      //83:70
    MEM_pc[31:0],           //69:38         
    MEM_gr_we,              //37:37
    MEM_dest[4:0],          //36:32
    MEM_final_result[31:0]  //31:0
};

endmodule