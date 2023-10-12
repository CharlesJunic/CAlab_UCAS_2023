module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg         reset;
    always @(posedge clk) reset <= ~resetn;

    wire            if_id_valid;
    wire            id_allowin;
    wire            id_exe_valid;
    wire            exe_allowin;
    wire            exe_mem_valid;
    wire            mem_allowin;
    wire            mem_wb_valid;
    wire            wb_allowin;

    wire    [ 63:0] if_id_bus;
    wire    [ 32:0] id_if_bus;
    wire    [179:0] id_exe_bus;
    wire    [102:0] exe_mem_bus;
    wire    [ 38:0] exe_wr_bus;
    wire    [101:0] mem_wb_bus;
    wire    [ 37:0] mem_wr_bus;
    wire    [ 37:0] wb_id_bus;

    IF my_if (
        .clk                (clk),
        .reset              (reset),
        .id_allowin         (id_allowin),
        .if_id_valid        (if_id_valid),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .inst_sram_en       (inst_sram_en),
        .inst_sram_we       (inst_sram_we),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_rdata    (inst_sram_rdata),
        .inst_sram_wdata    (inst_sram_wdata)
    );
    ID my_id (
        .clk                (clk),
        .reset              (reset),
        .if_id_valid        (if_id_valid),
        .id_allowin         (id_allowin),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .exe_allowin        (exe_allowin),
        .id_exe_valid       (id_exe_valid),
        .id_exe_bus         (id_exe_bus),
        .wb_id_bus          (wb_id_bus),
        .exe_wr_bus         (exe_wr_bus),
        .mem_wr_bus         (mem_wr_bus)
    );
    EXE my_exe (
        .clk                (clk),
        .reset              (reset),
        .exe_allowin        (exe_allowin),
        .id_exe_valid       (id_exe_valid),
        .id_exe_bus         (id_exe_bus),
        .exe_mem_valid      (exe_mem_valid),
        .mem_allowin        (mem_allowin),
        .exe_mem_bus        (exe_mem_bus),
        .data_sram_en       (data_sram_en),
        .data_sram_we       (data_sram_we),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .exe_wr_bus         (exe_wr_bus)
    );
    MEM my_mem (
        .clk                (clk),
        .reset              (reset),
        .mem_allowin        (mem_allowin),
        .exe_mem_valid      (exe_mem_valid),
        .exe_mem_bus        (exe_mem_bus),
        .mem_wb_valid       (mem_wb_valid),
        .wb_allowin         (wb_allowin),
        .mem_wb_bus         (mem_wb_bus),
        .data_sram_rdata    (data_sram_rdata),
        .mem_wr_bus         (mem_wr_bus)
    );
    WB my_wb (
        .clk                (clk),
        .reset              (reset),
        .wb_allowin         (wb_allowin),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_bus         (mem_wb_bus),
        .wb_id_bus          (wb_id_bus),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata)
    );
endmodule