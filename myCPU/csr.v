module csr(
    input clk,
    input reset,
    input csr_re,               
    input [13:0] csr_num,        
    output [31:0] csr_rvalue,     
    input csr_we,                 
    input [31:0] csr_wmask,    
    input [31:0] csr_wvalue,       
    input [31:0] WB_pc,
    input wb_ex,                    
    input [5:0] wb_ecode,        
    input [8:0] wb_esubcode,        
    input [31:0] wb_vaddr,
    input ertn_flush,             
    output has_int,             
    output [31:0] ex_entry,         
    input [7:0] hw_int_in,          
    input ipi_int_in,
    input [31:0] coreid_in
);

//crmd
    `define CSR_CRMD      14'h0000
    `define CSR_CRMD_PLV  1:0
    `define CSR_CRMD_IE   2
    `define CSR_CRMD_DA   3
//prmd
    `define CSR_PRMD      14'h0001
    `define CSR_PRMD_PPLV 1:0
    `define CSR_PRMD_PIE  2
    `define CSR_PRMD_DA   3
//ecfg
    `define CSR_ECFG      14'h0004
    `define CSR_ECFG_LIE  12:0
//estat
    `define CSR_ESTAT     14'h0005
    `define CSR_ESTAT_IS10  1:0
    `define CSR_ESTAT_ECODE  21:16
    `define CSR_ESTAT_ESUBCODE 30:22
//era
    `define CSR_ERA       14'h0006
    `define CSR_ERA_PC    31:0
//eentry
    `define CSR_EENTRY    14'h000c
    `define CSR_EENTRY_VA 31:6
//save
    `define CSR_SAVE0     14'h0030
    `define CSR_SAVE1     14'h0031
    `define CSR_SAVE2     14'h0032
    `define CSR_SAVE3     14'h0033
    `define CSR_SAVE_DATA 31:0
//badv
    `define CSR_BADV      14'h0007
//time
    `define CSR_TID       14'h0040
    `define CSR_TID_TID   31:0
    `define CSR_TCFG      14'h0041
    `define CSR_TCFG_EN   0
    `define CSR_TCFG_PERIOD 1
    `define CSR_TCFG_INITV 31:2
    `define CSR_TVAL      14'h0042
    `define CSR_TICLR     14'h0044
    `define CSR_TICLR_CLR 0
//exc code
    `define ECODE_INT     6'h00
    `define ECODE_SYS     6'h0b
    `define ECODE_ADEF    6'h08
    `define ESUBCODE_ADEF 9'h000
    `define ECODE_ALE     6'h09
    `define ECODE_BRK     6'h0c
    `define ECODE_INE     6'h0d


reg [1:0] csr_crmd_plv;
reg [1:0] csr_prmd_pplv;
reg csr_crmd_ie;
reg csr_prmd_pie;
reg [12:0] csr_ecfg_lie;
reg [12:0] csr_estat_is;
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;
reg [31:0] csr_era_pc;
reg [25:0] csr_eentry_va;
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;
reg [31:0] csr_badv_vaddr;
reg [31:0] csr_tid_tid;
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [31:0] timer_cnt;
reg [29:0] csr_tcfg_initval;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire wb_ex_addr_err;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
wire csr_ticlr_clr;
wire [31:0] csr_ticlr_rvalue;
wire [12:0] int_vec;

//CRMD
    assign csr_crmd_rvalue = {28'b0, 1'b1, csr_crmd_ie, csr_crmd_plv};
    //PLV
    always @(posedge clk) begin
        if(reset)
            csr_crmd_plv <= 2'b0;
        else if(wb_ex)
            csr_crmd_plv <= 2'b0;
        else if(ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                        |  ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
    end

    //IE
    always @(posedge clk) begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

//PRMD
    assign csr_prmd_rvalue = {28'b0, 1'b0, csr_prmd_pie, csr_prmd_pplv};
    //PPLV
    always @(posedge clk) begin
        if(wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if(csr_we && csr_num == `CSR_PRMD) begin
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                        |  ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                        |  ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        end
    end

//ECFG
    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie[12:11],1'b0,csr_ecfg_lie[9:0]};//1bff
    //LIE
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we & csr_num == `CSR_ECFG) 
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                        |  ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end

//ESTAT
    assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    //IS
    always @(posedge clk) begin
        if(reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                            |   ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[`CSR_ESTAT_IS10];
        
        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
        csr_estat_is[12] <= ipi_int_in;
    end      

    //ECODE, ESUBCODE
    always @(posedge clk) begin
        if(wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end      

//ERA
    assign csr_era_rvalue = csr_era_pc;
    //pc
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_pc <= WB_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end    

//BADV
    assign csr_badv_rvalue = csr_badv_vaddr;
    assign wb_ex_addr_err = wb_ecode == `ECODE_ALE || wb_ecode == `ECODE_ADEF;
    //vaddr
    always @(posedge clk) begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADEF &&
                               wb_esubcode == `ESUBCODE_ADEF) ? WB_pc : wb_vaddr;
    end

//EENTRY
    assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};
    //VA
    always @(posedge clk) begin
        if(csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end

//SAVE0~3
    assign csr_save0_rvalue = csr_save0_data;
    assign csr_save1_rvalue = csr_save1_data;
    assign csr_save2_rvalue = csr_save2_data;
    assign csr_save3_rvalue = csr_save3_data;
    //DATA
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end


//TID
    assign csr_tid_rvalue = csr_tid_tid;
    always @(posedge clk)begin
        if(reset)
            csr_tid_tid <= coreid_in;
        else if(csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

//TCFG
    assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if(reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                             | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
        end
    end

//TVAL
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                          | ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if(reset)
            timer_cnt <= 32'hffffffff;
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end
assign csr_tval = timer_cnt[31:0];

//TICLR
    assign csr_ticlr_clr = 1'b0;
    assign csr_ticlr_rvalue = {30'b0, csr_ticlr_clr};

//read value
    assign csr_rvalue = {32{csr_num == `CSR_CRMD}} & csr_crmd_rvalue
                    |   {32{csr_num == `CSR_PRMD}} & csr_prmd_rvalue
                    |   {32{csr_num == `CSR_ECFG}} & csr_ecfg_rvalue
                    |   {32{csr_num == `CSR_ESTAT}} & csr_estat_rvalue
                    |   {32{csr_num == `CSR_ERA}} & csr_era_rvalue
                    |   {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                    |   {32{csr_num == `CSR_SAVE0}} & csr_save0_rvalue
                    |   {32{csr_num == `CSR_SAVE1}} & csr_save1_rvalue
                    |   {32{csr_num == `CSR_SAVE2}} & csr_save2_rvalue
                    |   {32{csr_num == `CSR_SAVE3}} & csr_save3_rvalue
                    |   {32{csr_num == `CSR_BADV}} & csr_badv_rvalue
                    |   {32{csr_num == `CSR_TID}} & csr_tid_rvalue
                    |   {32{csr_num == `CSR_TCFG}} &  {csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en}
                    |   {32{csr_num == `CSR_TVAL}} & csr_tval
                    |   {32{csr_num == `CSR_TICLR}} & csr_ticlr_rvalue;
                    
//ex entry
    assign ex_entry = csr_eentry_rvalue;

//has_int
    assign int_vec[12:0] = { csr_ecfg_lie[12] & csr_estat_is[12],
                             csr_ecfg_lie[11] & csr_estat_is[11],
                             csr_ecfg_lie[10] & csr_estat_is[10],
                             csr_ecfg_lie[9] & csr_estat_is[9],
                             csr_ecfg_lie[8] & csr_estat_is[8],
                             csr_ecfg_lie[7] & csr_estat_is[7],
                             csr_ecfg_lie[6] & csr_estat_is[6],
                             csr_ecfg_lie[5] & csr_estat_is[5],
                             csr_ecfg_lie[4] & csr_estat_is[4],
                             csr_ecfg_lie[3] & csr_estat_is[3],
                             csr_ecfg_lie[2] & csr_estat_is[2],
                             csr_ecfg_lie[1] & csr_estat_is[1],
                             csr_ecfg_lie[0] & csr_estat_is[0]
                           };
    assign has_int = ~(int_vec == 13'b0) & csr_crmd_ie;

endmodule