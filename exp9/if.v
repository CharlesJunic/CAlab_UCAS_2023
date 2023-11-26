module IF (
    input   wire         clk,
    input   wire         reset,

    output  wire         inst_sram_en,
    output  wire [ 3:0]  inst_sram_we,
    output  wire [31:0]  inst_sram_addr,
    output  wire [31:0]  inst_sram_wdata,
    input   wire [31:0]  inst_sram_rdata,

    input   wire         id_allowin,
    output  wire         if_id_valid,

    input   wire [32:0]  id_if_bus,
    output  wire [63:0]  if_id_bus
);
    reg             if_valid;
    wire            if_ready_go;
    wire            if_allowin;

    wire            br_taken;
    wire    [31:0]  br_targrt;

    reg     [31:0]  pc;
    wire    [31:0]  inst;

    wire    [31:0]  seq_pc;
    wire    [31:0]  nextpc;

    assign  if_ready_go = 1'b1;
    assign  if_allowin = reset | if_ready_go & id_allowin;
    always @(posedge clk) begin
        if(reset) begin
            if_valid <= 1'b0;
        end
        else if(if_allowin)begin
            if_valid <= 1'b1;
        end
        else if(br_taken)begin
            if_valid <= 1'b0;
        end
    end

    assign inst_sram_en     = if_allowin;
    assign inst_sram_we     = 4'b0;
    assign inst_sram_addr   = nextpc;
    assign inst_sram_wdata  = 32'b0;
    assign inst             = inst_sram_rdata;

    assign  if_id_valid = if_ready_go & if_valid;

    assign  { br_taken, br_targrt } = id_if_bus;
    assign  if_id_bus = { pc, inst };

    assign  seq_pc = pc + 3'h4;
    assign  nextpc = br_taken ? br_targrt : seq_pc;
    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset
        end
        else if (if_allowin) begin
            pc <= nextpc;
        end
    end
endmodule