module WB_stage(
    input          clk,
    input          reset,
    output         WB_allowin,
    input          MEM_to_WB_valid,
    input  [206:0] MEM_to_WB_bus,
    output [ 37:0] WB_to_rf_bus,
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

reg WB_valid;
wire WB_ready_go;
reg [206:0] MEM_to_WB_bus_rf;
wire [31:0] WB_pc;
wire [31:0] WB_final_result;
wire [4:0] WB_dest;
wire WB_gr_we;
wire WB_rf_we;
wire [31:0]WB_rf_wdata;
wire WB_is_priv;
wire WB_inst_csrrd;
wire WB_inst_csrwr;
wire WB_inst_csrxchg;
wire WB_inst_syscall;
wire WB_inst_ertn;
wire WB_wb_ex;
wire WB_csr_re;
wire WB_csr_we;
wire [14:0] WB_ex_code;
wire [13:0] WB_csr_num_inst;
wire [13:0] WB_csr_num;
wire [31:0] WB_rj_value;
wire [31:0] WB_csr_wmask;
wire [31:0] WB_csr_rvalue;
wire [31:0] WB_csr_wdata;
wire [31:0] WB_ex_entry;
wire [5:0] WB_ecode;
wire [8:0] WB_esubcode;
wire WB_ex_adef;
wire WB_ex_ine;
wire WB_ex_ale;
wire [31:0] WB_ex_baddr;
wire WB_inst_brk;
wire WB_inst_rdcntid;
wire WB_inst_rdcntvl_w;
wire WB_inst_rdcntvh_w;
wire WB_has_int;
reg WB_has_int_rf;

assign WB_ready_go = 1'b1;
assign WB_allowin = !WB_valid || WB_ready_go;
assign out_WB_valid = WB_valid;

always @(posedge clk) begin
    if(reset)
        WB_valid <= 1'b0;
    else if(exec_flush)
        WB_valid <= 1'b0;
    else if(WB_allowin)
        WB_valid <= MEM_to_WB_valid;
end

always @(posedge clk) begin
    if(WB_allowin && MEM_to_WB_valid) 
        MEM_to_WB_bus_rf <= MEM_to_WB_bus;
end

assign {
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
    WB_final_result[31:0] } = MEM_to_WB_bus_rf[206:0];

//assign WB_rf_we = WB_gr_we & WB_valid;
assign WB_rf_we = WB_gr_we & WB_valid & ~WB_wb_ex;

assign WB_to_rf_bus[37:0] = {
    WB_rf_we,               //37:37
    WB_dest[4:0],           //36:32
    WB_rf_wdata[31:0]       //31:0
};

assign WB_is_priv = WB_inst_csrrd | WB_inst_csrwr | WB_inst_csrxchg | WB_inst_ertn | WB_inst_syscall |
                    WB_inst_brk | WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w;
assign WB_rf_wdata = WB_is_priv ? WB_csr_rvalue[31:0] : WB_final_result[31:0];
assign WB_csr_re = (WB_inst_csrrd | WB_inst_csrxchg | WB_inst_csrwr |
                    WB_inst_rdcntid | WB_inst_rdcntvl_w | WB_inst_rdcntvh_w) & WB_valid;
assign WB_csr_we = (WB_inst_csrwr | WB_inst_csrxchg) & WB_valid;
assign WB_ecode = {6{WB_valid & WB_has_int}} & `ECODE_INT |
                  {6{WB_valid & WB_ex_adef}} & `ECODE_ADEF |
                  {6{WB_valid & WB_ex_ale}} & `ECODE_ALE |
                  {6{WB_valid & WB_inst_syscall}} & `ECODE_SYS |
                  {6{WB_valid & WB_inst_brk}} & `ECODE_BRK |
                  {6{WB_valid & WB_ex_ine}} & `ECODE_INE;
assign WB_esubcode = 9'h000;
assign WB_wb_ex = (WB_inst_syscall | WB_inst_brk | WB_has_int | WB_ex_adef | WB_ex_ine | WB_ex_ale) & WB_valid;
assign WB_csr_num = {14{WB_inst_ertn}} & `CSR_ERA |
                    {14{WB_inst_rdcntvl_w | WB_inst_rdcntvh_w}} & `CSR_TVAL |
                    {14{WB_inst_rdcntid}} & `CSR_TID |
                    {14{~WB_inst_ertn & ~WB_inst_rdcntvh_w & ~WB_inst_rdcntvl_w & ~WB_inst_rdcntid}} & WB_csr_num_inst;
assign WB_csr_wmask = WB_inst_csrxchg ? WB_rj_value : 32'hffffffff;
assign exec_flush = (WB_inst_syscall | WB_inst_ertn | WB_inst_brk | WB_ex_adef | WB_ex_ine | WB_ex_ale | WB_has_int) & WB_valid;
assign WB_pc_gen_exec = {32{WB_inst_ertn}} & WB_csr_rvalue |
                        {32{exec_flush & ~WB_inst_ertn}} & WB_ex_entry;

csr u_csr(
    .clk(clk),
    .reset(reset),
    .csr_re(WB_csr_re),
    .csr_we(WB_csr_we),
    .csr_num(WB_csr_num),
    .csr_rvalue(WB_csr_rvalue),
    .csr_wmask(WB_csr_wmask),
    .csr_wvalue(WB_csr_wdata),
    .wb_ex(WB_wb_ex),
    .WB_pc(WB_pc),
    .wb_ecode(WB_ecode),
    .wb_esubcode(WB_esubcode),
    .wb_vaddr(WB_ex_baddr),
    .ertn_flush(WB_inst_ertn),
    .has_int(WB_has_int),
    .ex_entry(WB_ex_entry),
    .hw_int_in(8'b0),
    .ipi_int_in(1'b0),
    .coreid_in(32'b0)
);

assign debug_wb_rf_pc = WB_pc;
assign debug_wb_rf_we = {4{WB_rf_we}};
assign debug_wb_rf_wnum = WB_dest;
assign debug_wb_rf_wdata = WB_rf_wdata;

endmodule
