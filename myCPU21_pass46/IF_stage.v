module IF_stage(
    input         clk,
    input         reset,
    input         ID_allowin,
    input  [33:0] br_bus,
    output        IF_to_ID_valid,
    output [99:0] IF_to_ID_bus,
    output [19:0] IF_to_WB_bus,
    input  [27:0] IF_crmd_dmw_bus,
    input  [36:0] WB_to_IF_bus,
    input         exec_flush,
    input  [31:0] IF_ex_entry,
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    output [31:0] inst_addr_vrtl
);

wire        br_stall;    
reg         br_taken_r;    
wire        p_IF_to_IF_valid;
wire        p_IF_ready_go;
reg         p_IF_req_en;
wire        IF_inst_cancel;
reg         p_IF_addr_ok_r;
wire        p_IF_addr_ok;
reg         exec_flush_r_valid;
reg  [31:0] exec_entry_r;
reg         IF_data_ok_r;
wire        IF_data_ok;
reg  [31:0] IF_inst_buf;
reg         IF_inst_buf_valid;
reg  [31:0] br_target_r;
wire        IF_allowin;
reg         IF_throw;
reg         IF_valid;
wire        IF_ready_go;
reg  [31:0] IF_pc;
wire [31:0] nextpc;
wire [31:0] seq_pc;
wire [31:0] IF_inst;
wire        IF_ex_adef;
reg         p_IF_entry_req_r;
wire        IF_crmd_da;
wire        IF_crmd_pg;
wire [ 1:0] IF_crmd_plv;
wire        IF_dmw0_plv0;
wire        IF_dmw0_plv3;
wire [ 1:0] IF_dmw0_mat;
wire [ 2:0] IF_dmw0_pseg;
wire [ 2:0] IF_dmw0_vseg;
wire        IF_dmw1_plv0;
wire        IF_dmw1_plv3;
wire [ 1:0] IF_dmw1_mat;
wire [ 2:0] IF_dmw1_pseg;
wire [ 2:0] IF_dmw1_vseg;
wire [ 1:0] IF_crmd_datf;
wire [ 1:0] IF_crmd_datm;
wire        IF_dmw0_hit;
wire        IF_dmw1_hit;
wire        IF_tlb_hit;
wire [31:0] IF_tlb_paddr;
wire        IF_s0_found;
wire [ 3:0] IF_s0_index;
wire [19:0] IF_s0_ppn;
wire [ 5:0] IF_s0_ps;
wire [ 1:0] IF_s0_plv;
wire [ 1:0] IF_s0_mat;
wire        IF_s0_d;
wire        IF_s0_v;
wire        IF_ex_tlbr;
wire        IF_ex_pif;
wire        IF_ex_ppi;
wire [31:0] IF_ex_baddr;

assign IF_to_ID_bus[99:0] = {
    IF_ex_baddr[31:0],  //99:68
    IF_ex_ppi,          //67
    IF_ex_pif,          //66
    IF_ex_tlbr,         //65
    IF_ex_adef,         //64
    IF_inst[31:0],      //63:32
    IF_pc[31:0]         //31:0
};
    
assign inst_sram_wr = 1'b0;
assign inst_sram_wstrb[3:0] = {4{1'b0}};
assign inst_sram_wdata[31:0] = 32'b0;
assign inst_sram_size[1:0] = {1'b1, 1'b0};
assign inst_sram_req = ~reset & IF_allowin & p_IF_req_en & ~br_stall;
assign inst_sram_addr[28:0] = IF_tlb_hit ? IF_tlb_paddr[28:0] : nextpc[28:0];
assign inst_sram_addr[31:29] = {{3{IF_crmd_da}} & nextpc[31:29]}
                             | {{3{IF_dmw0_hit & ~IF_dmw1_hit}} & IF_dmw0_pseg}
                             | {{3{IF_dmw1_hit & ~IF_dmw0_hit}} & IF_dmw1_pseg}
                             | {{3{IF_tlb_hit}} & IF_tlb_paddr[31:29]};

assign br_stall = br_bus[33];

assign p_IF_ready_go = p_IF_addr_ok & inst_sram_req;
assign p_IF_to_IF_valid  = ~reset & p_IF_ready_go;
assign p_IF_addr_ok = inst_sram_addr_ok;

assign IF_ready_go = (IF_data_ok | IF_data_ok_r) & ~IF_inst_cancel & ~IF_throw;
assign IF_allowin = !IF_valid | IF_ready_go & ID_allowin;
assign IF_to_ID_valid = IF_valid & IF_ready_go;
assign IF_data_ok = inst_sram_data_ok;
assign IF_inst = IF_inst_buf_valid ? IF_inst_buf : inst_sram_rdata;

assign IF_inst_cancel = exec_flush | exec_flush_r_valid;  
assign nextpc[31:0] = {32{p_IF_entry_req_r}} & exec_entry_r[31:0]
                    | {32{~br_taken_r & br_bus[32] & ~p_IF_entry_req_r}} & br_bus[31:0]
                    | {32{br_taken_r & ~p_IF_entry_req_r}} & br_target_r[31:0]
                    | {32{~p_IF_entry_req_r & ~(~br_taken_r & br_bus[32]) & ~br_taken_r}} & seq_pc;
assign seq_pc = IF_pc + 32'h4;
assign inst_addr_vrtl = nextpc; // for icache
assign IF_dmw0_hit  = (nextpc[31:29] == IF_dmw0_vseg) & 
                        ((IF_crmd_plv == 2'b00 && IF_dmw0_plv0) || (IF_crmd_plv == 2'b11 && IF_dmw0_plv3)) &
                        ~IF_crmd_da;
assign IF_dmw1_hit  = (nextpc[31:29] == IF_dmw1_vseg) & 
                        ((IF_crmd_plv == 2'b00 && IF_dmw1_plv0) || (IF_crmd_plv == 2'b11 && IF_dmw1_plv3)) &
                        ~IF_crmd_da;
assign IF_tlb_hit   = ~IF_dmw0_hit & ~IF_dmw1_hit & ~IF_crmd_da;
assign IF_tlb_paddr = IF_s0_ps == 6'd21 ? {IF_s0_ppn[19:9], nextpc[20:0]} : {IF_s0_ppn[19:0], nextpc[11:0]};

assign IF_ex_adef  = (inst_sram_addr[0] | inst_sram_addr[1]) & IF_valid;
assign IF_ex_tlbr  = IF_tlb_hit & ~IF_s0_found & IF_valid;
assign IF_ex_pif   = IF_tlb_hit & IF_s0_found & ~IF_s0_v & IF_valid;
assign IF_ex_ppi   = IF_tlb_hit & IF_s0_found & IF_s0_v & (IF_crmd_plv > IF_s0_plv) & IF_valid;
assign IF_ex_baddr = (inst_sram_req && p_IF_addr_ok && IF_allowin) ? nextpc : IF_ex_baddr;

assign {
    IF_crmd_datf,
    IF_crmd_datm,
    IF_crmd_da,
    IF_crmd_pg,
    IF_crmd_plv[1:0],
    IF_dmw0_plv0,
    IF_dmw0_plv3,
    IF_dmw0_mat[1:0],
    IF_dmw0_pseg[2:0],
    IF_dmw0_vseg[2:0],
    IF_dmw1_plv0,
    IF_dmw1_plv3,
    IF_dmw1_mat[1:0],
    IF_dmw1_pseg[2:0],
    IF_dmw1_vseg[2:0]
} = IF_crmd_dmw_bus[27:0];

assign IF_to_WB_bus[19:0] = nextpc[31:12];
assign {
    IF_s0_found,
    IF_s0_index[3:0],
    IF_s0_ppn[19:0],
    IF_s0_ps[5:0],
    IF_s0_plv[1:0],
    IF_s0_mat[1:0],
    IF_s0_d,
    IF_s0_v
} = WB_to_IF_bus[36:0];

always @(posedge clk) begin
    if(reset)
        p_IF_req_en <= 1'b1;
    //else if(inst_sram_req & p_IF_addr_ok)
    else if(inst_sram_req & p_IF_addr_ok & ~IF_inst_cancel)
        p_IF_req_en <= 1'b0;
    else if(IF_to_ID_valid & ID_allowin)
        p_IF_req_en <= 1'b1;
    else if(IF_inst_cancel)
        p_IF_req_en <= 1'b1;
end

always @(posedge clk)begin
    if(reset)
        p_IF_entry_req_r <= 1'b0;
    else if(inst_sram_req & p_IF_addr_ok & p_IF_entry_req_r)
        p_IF_entry_req_r <= 1'b0;
    else if(inst_sram_req & p_IF_addr_ok & IF_inst_cancel)
        p_IF_entry_req_r <= 1'b1;
    else if(p_IF_addr_ok_r & IF_inst_cancel)
        p_IF_entry_req_r <= 1'b1;
end

always @(posedge clk) begin
    if(reset)
        p_IF_addr_ok_r <= 1'b0;
    else if(inst_sram_req & p_IF_addr_ok)
        p_IF_addr_ok_r <= 1'b1;
    else if(IF_data_ok)
        p_IF_addr_ok_r <= 1'b0;
end

always @(posedge clk) begin
    if(reset)
        br_taken_r <= 1'b0;
    //else if(IF_allowin & p_IF_addr_ok)
    else if(p_IF_ready_go)
        br_taken_r <= 1'b0;
    //else if(~br_stall & br_bus[32])
    else if (inst_sram_req & ~p_IF_addr_ok & br_bus[32])
        br_taken_r <= 1'b1;
end
always @(posedge clk) begin
    if(~br_stall & br_bus[32])
        br_target_r <= br_bus[31:0];
end

always @(posedge clk) begin
    if(reset)
        exec_flush_r_valid <= 1'b0;
    else if(p_IF_to_IF_valid & IF_allowin)
        exec_flush_r_valid <= 1'b0;
    else if(exec_flush)
        exec_flush_r_valid <= 1'b1;
end
always @(posedge clk) begin
    if(exec_flush)
        exec_entry_r <= IF_ex_entry;
end

always @(posedge clk) begin
    if(reset) begin
        IF_pc <= 32'h1bfffffc;
    end
    else if(IF_allowin & p_IF_to_IF_valid)begin
        IF_pc <= nextpc;
    end
end
always @(posedge clk) begin
    if(reset) begin
        IF_valid <= 1'b0;
    end
    //else if(exec_flush & !IF_allowin) begin
    else if((IF_inst_cancel | p_IF_entry_req_r) & !IF_allowin) begin
        IF_valid <= 1'b0;
    end
    else if(IF_allowin)begin
        IF_valid <= p_IF_to_IF_valid;
    end
end

always @(posedge clk) begin
    if(reset)
        IF_data_ok_r <= 1'b0;
    else if(ID_allowin)
        IF_data_ok_r <= 1'b0;
    else if(IF_data_ok)
        IF_data_ok_r <= 1'b1;
end

always @(posedge clk) begin
    if(reset)
        IF_inst_buf_valid <= 1'b0;
    else if(ID_allowin | IF_inst_cancel)
        IF_inst_buf_valid <= 1'b0;
    else if(IF_data_ok)
        IF_inst_buf_valid <= 1'b1;
end
always @(posedge clk) begin
    if(IF_data_ok)
        IF_inst_buf <= inst_sram_rdata;
end

always @(posedge clk) begin
    if(reset)
        IF_throw <= 1'b0;
    else if(IF_data_ok)
        IF_throw <= 1'b0;
    else if(IF_inst_cancel & p_IF_addr_ok_r)
        IF_throw <= 1'b1;
end
        
endmodule