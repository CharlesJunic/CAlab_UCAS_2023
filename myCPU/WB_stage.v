module WB_stage(
    input clk,
    input reset,
    output WB_allowin,
    input MEM_to_WB_valid,
    input [69:0] MEM_to_WB_bus,
    output [37:0] WB_to_rf_bus,
    output out_WB_valid,
    output [31:0] debug_wb_rf_pc,
    output [3:0] debug_wb_rf_we,
    output [4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg WB_valid;
wire WB_ready_go;
reg [69:0] MEM_to_WB_bus_r;
wire [31:0] WB_pc;
wire [31:0] WB_final_result;
wire [4:0] WB_dest;
wire WB_gr_we;
wire WB_rf_we;

assign WB_ready_go = 1'b1;
assign WB_allowin = !WB_valid || WB_ready_go;
assign out_WB_valid = WB_valid;

always @(posedge clk) begin
    if(reset)
        WB_valid <= 1'b0;
    else if(WB_allowin)
        WB_valid <= MEM_to_WB_valid;
end

always @(posedge clk) begin
    if(WB_allowin && MEM_to_WB_valid) 
        MEM_to_WB_bus_r <= MEM_to_WB_bus;
end

assign {
    WB_pc[31:0],
    WB_gr_we,
    WB_dest[4:0],
    WB_final_result[31:0] } = MEM_to_WB_bus_r[69:0];

assign WB_rf_we = WB_gr_we && WB_valid;

assign WB_to_rf_bus[37:0] = {
    WB_gr_we,               //37:37
    WB_dest[4:0],           //36:32
    WB_final_result[31:0]   //31:0
};

assign debug_wb_rf_pc = WB_pc;
assign debug_wb_rf_we = {4{WB_rf_we}};
assign debug_wb_rf_wnum = WB_dest;
assign debug_wb_rf_wdata = WB_final_result;

endmodule
