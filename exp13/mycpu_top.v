module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    output wire inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
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
wire [64:0] IF_to_ID_bus;
wire [197:0] ID_to_EXE_bus;
wire [212:0] EXE_to_MEM_bus;
wire [206:0] MEM_to_WB_bus;
wire [37:0] WB_to_rf_bus;
wire [32:0] br_bus;
wire [31:0] WB_pc_gen_exec;
wire exec_flush;


IF_stage u_IF_stage(
    .clk (clk),
    .reset (reset),
    .ID_allowin (ID_allowin),
    .br_bus (br_bus),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus (IF_to_ID_bus),
    .inst_sram_en (inst_sram_en),
    .inst_sram_we (inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_rdata (inst_sram_rdata),
    .inst_sram_wdata (inst_sram_wdata),
    .exec_flush(exec_flush),
    .WB_pc_gen_exec(WB_pc_gen_exec)
);

ID_stage u_ID_stage(
    .clk (clk),
    .reset (reset),
    .EXE_allowin (EXE_allowin),
    .ID_allowin (ID_allowin),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus (IF_to_ID_bus),
    .ID_to_EXE_valid (ID_to_EXE_valid),
    .ID_to_EXE_bus (ID_to_EXE_bus),
    .br_bus (br_bus),
    .WB_to_rf_bus (WB_to_rf_bus),
    .out_WB_valid(out_WB_valid),
    .EXE_to_MEM_bus(EXE_to_MEM_bus),
    .out_EXE_valid(out_EXE_valid),
    .MEM_to_WB_bus(MEM_to_WB_bus),
    .out_MEM_valid(out_MEM_valid),
    .exec_flush(exec_flush)
);

EXE_stage u_EXE_stage(
    .clk (clk),
    .reset (reset),
    .MEM_allowin (MEM_allowin),
    .EXE_allowin (EXE_allowin),
    .ID_to_EXE_valid (ID_to_EXE_valid),
    .ID_to_EXE_bus (ID_to_EXE_bus),
    .EXE_to_MEM_valid (EXE_to_MEM_valid),
    .EXE_to_MEM_bus (EXE_to_MEM_bus),
    .data_sram_en (data_sram_en),
    .data_sram_wen (data_sram_we),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata (data_sram_wdata),
    .out_EXE_valid(out_EXE_valid),
    .exec_flush(exec_flush)
);

MEM_stage u_MEM_stage(
    .clk (clk),
    .reset (reset),
    .WB_allowin (WB_allowin),
    .MEM_allowin (MEM_allowin),
    .EXE_to_MEM_valid (EXE_to_MEM_valid),
    .EXE_to_MEM_bus (EXE_to_MEM_bus),
    .MEM_to_WB_valid (MEM_to_WB_valid),
    .MEM_to_WB_bus (MEM_to_WB_bus),
    .data_sram_rdata (data_sram_rdata),
    .out_MEM_valid(out_MEM_valid),
    .exec_flush(exec_flush)
);

WB_stage u_WB_stage(
    .clk (clk),
    .reset (reset),
    .WB_allowin (WB_allowin),
    .MEM_to_WB_valid (MEM_to_WB_valid),
    .MEM_to_WB_bus (MEM_to_WB_bus),
    .WB_to_rf_bus (WB_to_rf_bus),
    .debug_wb_rf_pc (debug_wb_pc),
    .debug_wb_rf_we (debug_wb_rf_we),
    .debug_wb_rf_wnum (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata),
    .out_WB_valid(out_WB_valid),
    .exec_flush(exec_flush),
    .WB_pc_gen_exec(WB_pc_gen_exec)
);

endmodule
