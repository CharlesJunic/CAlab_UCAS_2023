module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [31:0] inst_addr_vrtl,
    output wire        inst_mem_type
);

reg          reset;
always @(posedge clk) reset <= ~resetn;

wire         ID_allowin;
wire         EXE_allowin;
wire         MEM_allowin;
wire         WB_allowin;
wire         IF_to_ID_valid;
wire         ID_to_EXE_valid;
wire         EXE_to_MEM_valid;
wire         MEM_to_WB_valid;
wire         out_EXE_valid;
wire         out_MEM_valid;
wire         out_WB_valid;
wire [ 99:0] IF_to_ID_bus;
wire [ 19:0] IF_to_WB_bus;
wire [246:0] ID_to_EXE_bus;
wire [230:0] EXE_to_MEM_bus;
wire [ 68:0] EXE_to_WB_bus;
wire [223:0] MEM_to_WB_bus;
wire [ 36:0] WB_to_EXE_bus;
wire [ 36:0] WB_to_IF_bus;
wire [ 52:0] WB_to_ID_bus;
wire [ 33:0] br_bus;
wire [ 27:0] crmd_dmw_bus;
wire [ 31:0] IF_ex_entry;
wire         exec_flush;
wire         refetch_flush;
wire [1:0] csr_crmd_datf;
wire [1:0] csr_crmd_datm;
assign csr_crmd_datf = crmd_dmw_bus[27:26];
assign csr_crmd_datm = crmd_dmw_bus[25:24];
assign inst_mem_type = csr_crmd_datf[0];

IF_stage u_IF_stage(
    .clk                (clk              ),
    .reset              (reset            ),
    .ID_allowin         (ID_allowin       ),
    .br_bus             (br_bus           ),
    .IF_to_ID_valid     (IF_to_ID_valid   ),
    .IF_to_ID_bus       (IF_to_ID_bus     ),
    .IF_to_WB_bus       (IF_to_WB_bus     ),
    .IF_crmd_dmw_bus    (crmd_dmw_bus     ),
    .WB_to_IF_bus       (WB_to_IF_bus     ),
    .inst_sram_req      (inst_sram_req    ),
    .inst_sram_wr       (inst_sram_wr     ),
    .inst_sram_size     (inst_sram_size   ),
    .inst_sram_wstrb    (inst_sram_wstrb  ),
    .inst_sram_addr     (inst_sram_addr   ),
    .inst_sram_rdata    (inst_sram_rdata  ),
    .inst_sram_wdata    (inst_sram_wdata  ),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),
    .exec_flush         (exec_flush       ),
    .IF_ex_entry        (IF_ex_entry      ),
    .inst_addr_vrtl     (inst_addr_vrtl   )
);

ID_stage u_ID_stage(
    .clk                (clk              ),
    .reset              (reset            ),
    .EXE_allowin        (EXE_allowin      ),
    .ID_allowin         (ID_allowin       ),
    .IF_to_ID_valid     (IF_to_ID_valid   ),
    .IF_to_ID_bus       (IF_to_ID_bus     ),
    .ID_to_EXE_valid    (ID_to_EXE_valid  ),
    .ID_to_EXE_bus      (ID_to_EXE_bus    ),
    .br_bus             (br_bus           ),
    .WB_to_ID_bus       (WB_to_ID_bus     ),
    .out_WB_valid       (out_WB_valid     ),
    .EXE_to_MEM_bus     (EXE_to_MEM_bus   ),
    .out_EXE_valid      (out_EXE_valid    ),
    .MEM_to_WB_bus      (MEM_to_WB_bus    ),
    .out_MEM_valid      (out_MEM_valid    ),
    .exec_flush         (exec_flush       ),
    .data_sram_data_ok  (data_sram_data_ok)
);

EXE_stage u_EXE_stage(
    .clk                (clk              ),
    .reset              (reset            ),
    .MEM_allowin        (MEM_allowin      ),
    .EXE_allowin        (EXE_allowin      ),
    .ID_to_EXE_valid    (ID_to_EXE_valid  ),
    .ID_to_EXE_bus      (ID_to_EXE_bus    ),
    .WB_to_EXE_bus      (WB_to_EXE_bus    ),
    .EXE_to_MEM_valid   (EXE_to_MEM_valid ),
    .EXE_to_MEM_bus     (EXE_to_MEM_bus   ),
    .EXE_to_WB_bus      (EXE_to_WB_bus    ),
    .EXE_crmd_dmw_bus   (crmd_dmw_bus     ),
    .data_sram_req      (data_sram_req    ),
    .data_sram_wr       (data_sram_wr     ),
    .data_sram_size     (data_sram_size   ),
    .data_sram_wstrb    (data_sram_wstrb  ),
    .data_sram_addr     (data_sram_addr   ),
    .data_sram_wdata    (data_sram_wdata  ),
    .data_sram_addr_ok  (data_sram_addr_ok),
    .out_EXE_valid      (out_EXE_valid    ),
    .exec_flush         (exec_flush       )
);

MEM_stage u_MEM_stage(
    .clk                (clk              ),
    .reset              (reset            ),
    .WB_allowin         (WB_allowin       ),
    .MEM_allowin        (MEM_allowin      ),
    .EXE_to_MEM_valid   (EXE_to_MEM_valid ),
    .EXE_to_MEM_bus     (EXE_to_MEM_bus   ),
    .MEM_to_WB_valid    (MEM_to_WB_valid  ),
    .MEM_to_WB_bus      (MEM_to_WB_bus    ),
    .data_sram_rdata    (data_sram_rdata  ),
    .data_sram_data_ok  (data_sram_data_ok),
    .out_MEM_valid      (out_MEM_valid    ),
    .exec_flush         (exec_flush       )
);

WB_stage u_WB_stage(
    .clk                (clk              ),
    .reset              (reset            ),
    .WB_allowin         (WB_allowin       ),
    .MEM_to_WB_valid    (MEM_to_WB_valid  ),
    .MEM_to_WB_bus      (MEM_to_WB_bus    ),
    .EXE_to_WB_bus      (EXE_to_WB_bus    ),
    .IF_to_WB_bus       (IF_to_WB_bus     ),
    .WB_to_ID_bus       (WB_to_ID_bus     ),
    .WB_to_EXE_bus      (WB_to_EXE_bus    ),
    .WB_to_IF_bus       (WB_to_IF_bus     ),
    .debug_wb_rf_pc     (debug_wb_pc      ),
    .debug_wb_rf_we     (debug_wb_rf_we   ),
    .debug_wb_rf_wnum   (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata  (debug_wb_rf_wdata),
    .out_WB_valid       (out_WB_valid     ),
    .exec_flush         (exec_flush       ),
    .WB_pc_gen_exec     (IF_ex_entry      ),
    .WB_crmd_dmw_bus    (crmd_dmw_bus     )
);

endmodule
