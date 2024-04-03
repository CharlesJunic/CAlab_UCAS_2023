module MEM (
    input  wire          clk,
    input  wire          reset,

    input  wire         exe_mem_valid,
    output wire         mem_allowin,
    output wire         mem_wb_valid,
    input  wire         wb_allowin,

    input  wire [ 31:0] data_sram_rdata,

    input  wire [102:0] exe_mem_bus,
    output wire [101:0] mem_wb_bus,
    output wire [ 37:0] mem_wr_bus
);
    wire    [ 31:0] pc;
    wire    [ 31:0] inst;

    reg             mem_valid;
    wire            mem_ready_go;

    wire            gr_we;
    wire            res_from_mem;
    wire    [  4:0] dest;
    wire    [ 31:0] alu_result;
    wire    [ 31:0] final_result;

    reg     [102:0] exe_mem_bus_tmp;
    wire            mem_en_bypass;

    assign  mem_ready_go = 1'b1;
    assign  mem_wb_valid = mem_ready_go & mem_valid;
    assign  mem_allowin = mem_wb_valid & wb_allowin | ~mem_valid;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
        end
        else if(mem_allowin) begin
            mem_valid <= exe_mem_valid;
        end
    end

    always @(posedge clk) begin
        if (exe_mem_valid & mem_allowin) begin
            exe_mem_bus_tmp <= exe_mem_bus;
        end
    end
    assign  {gr_we, res_from_mem, dest, pc, inst, alu_result} = exe_mem_bus_tmp;
    assign  final_result = res_from_mem ? data_sram_rdata : alu_result;
    assign  mem_en_bypass = mem_valid & gr_we;
    assign  mem_wb_bus = {gr_we, pc, inst, final_result, dest};
    assign  mem_wr_bus = {mem_en_bypass, dest, final_result};
endmodule