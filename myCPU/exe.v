module EXE (
    input   wire         clk,
    input   wire         reset,

    input   wire         id_exe_valid,
    output  wire         exe_allowin,
    output  wire         exe_mem_valid,
    input   wire         mem_allowin,

    output  wire         data_sram_en,
    output  wire [ 3:0]  data_sram_we,
    output  wire [31:0]  data_sram_addr,
    output  wire [31:0]  data_sram_wdata,

    input   wire [179:0] id_exe_bus,
    output  wire [ 38:0] exe_wr_bus
    output  wire [102:0] exe_mem_bus,
);
    wire    [ 31:0] pc;
    wire    [ 31:0] inst;

    reg             exe_valid;
    wire            exe_ready_go;

    wire            gr_we;
    wire            mem_we;
    wire            res_from_mem;
    wire    [11:0]  alu_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [31:0]  alu_result;
    wire    [ 4:0]  dest;
    wire    [31:0]  exe_rkd_value;

    reg     [179:0] id_exe_bus_tmp;
    wire            exe_en_bypass;
    wire            exe_blk;

    assign  exe_ready_go = 1'b1;
    assign  exe_mem_valid = exe_ready_go & exe_valid;
    assign  exe_allowin = exe_mem_valid & mem_allowin | ~exe_valid;
    always @(posedge clk ) begin
        if (reset) begin
            exe_valid <= 1'b0;
        end
        else if(exe_allowin) begin
            exe_valid <= id_exe_valid;
        end
    end

    always @(posedge clk ) begin
        if (id_exe_valid & exe_allowin) begin
            id_exe_bus_tmp <= id_exe_bus; 
        end
    end
    assign {gr_we, mem_we, res_from_mem, alu_op, alu_src1, alu_src2, 
                            dest, exe_rkd_value, inst, pc} = id_exe_bus_tmp;
    assign  exe_en_bypass = exe_valid & gr_we;
    assign  exe_blk = exe_valid & res_from_mem & gr_we;
    assign  exe_mem_bus = { gr_we, res_from_mem, dest, pc, inst, alu_result };
    assign  exe_wr_bus = { exe_en_bypass, exe_blk, dest, alu_result };

    alu u_alu (
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );

    assign  data_sram_en = 1'b1;
    assign  data_sram_we = {4{mem_we}};
    assign  data_sram_addr = alu_result;
    assign  data_sram_wdata = exe_rkd_value;
endmodule