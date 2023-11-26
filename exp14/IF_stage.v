module IF_stage(
    input clk,
    input reset,
    input ID_allowin,
    input [33:0] br_bus,
    output IF_to_ID_valid,
    output [64:0] IF_to_ID_bus,
    input exec_flush,
    input [31:0] IF_ex_entry,
    output inst_sram_req,
    output inst_sram_wr,
    output [1:0] inst_sram_size,
    output [3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input inst_sram_addr_ok,
    input inst_sram_data_ok,
    input [31:0] inst_sram_rdata
);

    wire br_stall;
    wire p_IF_to_IF_valid;
    wire p_IF_ready_go;
    reg p_IF_req_en;
    wire IF_inst_cancel;
    reg exec_flush_r_valid;
    reg [31:0] exec_entry_r;
    reg p_IF_addr_ok_r;
    wire p_IF_addr_ok;
    reg IF_data_ok_r;
    wire IF_data_ok;
    reg [31:0] IF_inst_buf;
    reg IF_inst_buf_valid;
    reg br_taken_r;
    reg [31:0] br_target_r;
    wire IF_allowin;
    reg IF_throw;
    reg IF_valid;
    wire IF_ready_go;
    reg [31:0] IF_pc;
    wire [31:0] nextpc;
    wire [31:0] seq_pc;
    wire [31:0] IF_inst;
    wire IF_ex_adef;
    wire p_IF_ex_adef;
    reg IF_ex_adef_r;

    assign IF_ex_adef = IF_ex_adef_r;
    assign p_IF_ex_adef = nextpc[0] | nextpc[1];
    always @(posedge clk) begin
        if(reset)
            IF_ex_adef_r <= 1'b0;
        else if(inst_sram_req && p_IF_addr_ok && IF_allowin)
            IF_ex_adef_r <= p_IF_ex_adef;
    end

    assign IF_to_ID_bus[64:0] = {
        IF_ex_adef,         //64
        IF_inst[31:0],      //63:32
        IF_pc[31:0]         //31:0
    };
    assign inst_sram_wr = 1'b0;
    assign inst_sram_wstrb[3:0] = {4{1'b0}};
    assign inst_sram_wdata[31:0] = 32'b0;
    assign inst_sram_size[1:0] = {1'b1, 1'b0};
    assign inst_sram_req = ~reset & IF_allowin & p_IF_req_en & ~br_stall;
    assign inst_sram_addr = nextpc;
    assign br_stall = br_bus[33];
    assign p_IF_ready_go = p_IF_addr_ok & inst_sram_req;
    assign p_IF_to_IF_valid  = ~reset & p_IF_ready_go;
    assign p_IF_addr_ok = inst_sram_addr_ok;
    assign IF_ready_go = (IF_data_ok | IF_data_ok_r) & ~IF_throw & ~IF_inst_cancel;
    assign IF_allowin = !IF_valid || IF_ready_go && ID_allowin;
    assign IF_to_ID_valid = IF_valid && IF_ready_go;
    assign IF_data_ok = inst_sram_data_ok;
    assign IF_inst = IF_inst_buf_valid ? IF_inst_buf : inst_sram_rdata;
    assign IF_inst_cancel = exec_flush | exec_flush_r_valid;  
    assign nextpc[31:0] = {32{exec_flush}} & IF_ex_entry[31:0]
                        | {32{exec_flush_r_valid}} & exec_entry_r[31:0]
                        | {32{~br_taken_r & br_bus[32] & ~IF_inst_cancel}} & br_bus[31:0]
                        | {32{br_taken_r & ~IF_inst_cancel}} & br_target_r[31:0]
                        | {32{~IF_inst_cancel & ~(~br_taken_r & br_bus[32])
                               & ~br_taken_r}} & seq_pc;
    assign seq_pc = IF_pc + 32'h4;

        always @(posedge clk) begin
            if(reset)
                p_IF_req_en <= 1'b1;
            else if(inst_sram_req & p_IF_addr_ok)
                p_IF_req_en <= 1'b0;
            else if(IF_to_ID_valid & ID_allowin)
                p_IF_req_en <= 1'b1;
            else if(IF_inst_cancel)
                p_IF_req_en <= 1'b1;
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
            else if(IF_allowin && p_IF_addr_ok)
                br_taken_r <= 1'b0;
            else if(~br_stall && br_bus[32])
                br_taken_r <= 1'b1;
        end
        always @(posedge clk) begin
            if(~br_stall && br_bus[32])
                br_target_r <= br_bus[31:0];
        end

        always @(posedge clk) begin
            if(reset)
                exec_flush_r_valid <= 1'b0;
            else if(p_IF_to_IF_valid && IF_allowin)
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
            else if(IF_allowin && p_IF_to_IF_valid)begin
                IF_pc <= nextpc;
            end
        end
        always @(posedge clk) begin
            if(reset) begin
                IF_valid <= 1'b0;
            end
            else if(exec_flush && !IF_allowin) begin
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
            else if(ID_allowin || IF_inst_cancel)
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
            else if(IF_inst_cancel && p_IF_addr_ok_r)
                IF_throw <= 1'b1;
        end
endmodule