module IF_stage(
    input clk,
    input reset,
    input ID_allowin,
    input [32:0] br_bus,
    output IF_to_ID_valid,
    output [64:0] IF_to_ID_bus,
    output inst_sram_en,
    output [ 3:0] inst_sram_we,
    output [31:0] inst_sram_addr,
    input  [31:0] inst_sram_rdata,
    output [31:0] inst_sram_wdata,    
    input exec_flush,
    input [31:0] WB_pc_gen_exec
);
    reg IF_valid;
    wire IF_allowin;
    wire IF_ready_go;
    wire pre_IF_valid;
    reg [31:0] IF_pc;
    wire [31:0] nextpc;
    wire [31:0] seq_pc;
    wire [31:0] IF_inst;
    wire IF_ex_adef;
    
    assign IF_ex_adef = (IF_pc[0] | IF_pc[1]) & IF_valid;
    assign IF_to_ID_bus[64:0] = {
        IF_ex_adef,         //64
        IF_inst[31:0],      //63:32
        IF_pc[31:0]         //31:0
    };
    assign nextpc[31:0] = exec_flush ? WB_pc_gen_exec :
                          br_bus[32] ? br_bus[31:0] : seq_pc;

    assign seq_pc = IF_pc + 32'h4;

    assign pre_IF_valid  = ~reset;
    assign IF_ready_go = 1'b1;
    assign IF_allowin = !IF_valid || IF_ready_go && ID_allowin;
    assign IF_to_ID_valid = IF_valid;

    assign inst_sram_en = IF_allowin && pre_IF_valid;
    assign inst_sram_we = 4'b0;
    assign inst_sram_addr = nextpc;
    assign inst_sram_wdata = 32'b0;
    assign IF_inst = inst_sram_rdata;

    always @(posedge clk) begin
        if(reset) begin
            IF_pc <= 32'h1bfffffc;
        end
        else if(ID_allowin)begin
            IF_pc <= nextpc;
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            IF_valid <= 1'b0;
        end
        else if(pre_IF_valid && IF_allowin)begin
            IF_valid <= pre_IF_valid;
        end
    end

endmodule