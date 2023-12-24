module WB (
    input  wire         clk,
    input  wire         reset,

    input  wire         mem_wb_valid,
    output wire         wb_allowin,

    input  wire [101:0] mem_wb_bus,
    output wire [ 37:0] wb_id_bus,

    output wire [ 31:0] debug_wb_pc,
    output wire [  3:0] debug_wb_rf_we,
    output wire [  4:0] debug_wb_rf_wnum,
    output wire [ 31:0] debug_wb_rf_wdata
);
    wire    [ 31:0] pc;
    wire    [ 31:0] inst;

    reg             wb_valid;
    wire            wb_ready_go;

    wire            wb_gr_we;
    reg     [101:0] mem_wb_bus_tmp;
    wire    [ 31:0] final_result;
    wire            rf_we;
    wire    [  4:0] rf_waddr;
    wire    [ 31:0] rf_wdata;
    wire    [  4:0] dest;

    assign wb_ready_go = 1'b1;
    assign wb_allowin = wb_ready_go | ~wb_valid;
    always @(posedge clk ) begin
        if (reset) begin
            wb_valid <= 1'b0;
        end
        else if (wb_allowin) begin
            wb_valid <= mem_wb_valid;
        end
    end
    always @(posedge clk ) begin
        if (mem_wb_valid & wb_allowin) begin
            mem_wb_bus_tmp <= mem_wb_bus;
        end
    end

    assign  { wb_gr_we, pc, inst, final_result, dest } = mem_wb_bus_tmp;
    assign  rf_we = wb_valid & wb_gr_we;
    assign  rf_waddr = dest; 
    assign  rf_wdata = final_result;
    assign  wb_id_bus = { rf_we, rf_waddr, rf_wdata };

    assign  debug_wb_pc = pc;
    assign  debug_wb_rf_we = {4{rf_we}};
    assign  debug_wb_rf_wnum = rf_waddr;
    assign  debug_wb_rf_wdata = final_result;
endmodule