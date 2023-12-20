module cache(
    input          clk,
    input          reset,

    input          valid,       // 表明请求有效
    input          op,          // 1: write  0: read
    input  [  7:0] index,       // 地址的 index 域 (addr[11:4])
    input  [ 19:0] tag,         // 经虚实地址转换后的 paddr 形成的 tag
    input  [  3:0] offset,      // 地址的 offset 域 (addr[3:0])
    input  [  3:0] wstrb,       // 写字节使能信号
    input  [ 31:0] wdata,       // 写数据
    output         addr_ok,     // 该次请求的地址传输 OK，读：地址被接收；写：地址和数据被接收
    output         data_ok,     // 该次请求的数据传输 OK，读：数据返回；写：数据写入完成
    output [ 31:0] rdata,       // 读 cache 的结果

    output         rd_req,      // 读请求有效信号
    output [  2:0] rd_type,     // 读请求类型: 3'b000——字节，3'b001——半字，3'b010——字，3'b100——Cache 行
    output [ 31:0] rd_addr,     // 读请求起始地址
    input          rd_rdy,      // 读请求能否被接收的握手信号
    input          ret_valid,   // 返回数据有效信号
    input          ret_last,    // 返回数据是一次读请求对应的最后一个返回数据
    input  [ 31:0] ret_data,    // 读返回数据
    output         wr_req,      // 写请求有效信号
    output [  2:0] wr_type,     // 写请求类型: 3'b000——字节，3'b001——半字，3'b010——字，3'b100——Cache 行
    output [ 31:0] wr_addr,     // 写请求起始地址
    output [  3:0] wr_wstrb,    // 写操作的字节掩码，仅在写请求类型为 3'b000、3'b001、3'b010 情况下才有意义
    output [127:0] wr_data,     // 写数据
    input          wr_rdy       // 写请求能否被接收的握手信号
);

// request buffer
wire       req_en;
reg        reg_op;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;

// tag compare
wire        way0_hit;
wire        way0_v;
wire [19:0] way0_tag;
wire        way1_hit;
wire        way1_v;
wire [19:0] way1_tag;
wire        cache_hit;

// data select
wire [127:0] way0_data;
wire [127:0] way1_data;
wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;
wire [127:0] replace_data;
wire         replace_way;

// miss buffer
reg [ 1:0] ret_bank;

// LFSR
reg         lfsr;

// write buffer
wire        hit_write;
wire        hit_write_con;
reg         reg_way;
reg  [ 1:0] reg_bank;
reg  [ 7:0] reg_reg_index;
reg  [ 3:0] reg_reg_wstrb;
reg  [31:0] reg_reg_wdata;

// main state machine
parameter  IDLE    = 5'b00001;
parameter  LOOKUP  = 5'b00010;
parameter  MISS    = 5'b00100;
parameter  REPLACE = 5'b01000;
parameter  REFILL  = 5'b10000;
reg  [ 4:0] main_state;
reg  [ 4:0] main_state_r;

// write state machine
parameter  IDLEW   = 2'b01;
parameter  WRITE   = 2'b10;
reg  [ 1:0] write_state;
reg  [ 1:0] write_state_r;

// RAM
    // write
    wire write_way0_databank0;
    wire write_way0_databank1;
    wire write_way0_databank2;
    wire write_way0_databank3;
    wire write_way1_databank0;
    wire write_way1_databank1;
    wire write_way1_databank2;
    wire write_way1_databank3;
    // refill
    wire refill_way0_databank0;
    wire refill_way0_databank1;
    wire refill_way0_databank2;
    wire refill_way0_databank3;
    wire refill_way1_databank0;
    wire refill_way1_databank1;
    wire refill_way1_databank2;
    wire refill_way1_databank3;
    // way0
        // tagv
        wire        way0_tagv_en;
        wire        way0_tagv_we;
        wire [ 7:0] way0_tagv_addr;
        wire [20:0] way0_tagv_wdata;
        wire [20:0] way0_tagv_rdata;
        // bank0
        wire        way0_databank0_en;
        wire [ 3:0] way0_databank0_we;
        wire [ 7:0] way0_databank0_addr;
        wire [31:0] way0_databank0_wdata;
        wire [31:0] way0_databank0_rdata;
        // bank1
        wire        way0_databank1_en;
        wire [ 3:0] way0_databank1_we;
        wire [ 7:0] way0_databank1_addr;
        wire [31:0] way0_databank1_wdata;
        wire [31:0] way0_databank1_rdata;
        // bank2
        wire        way0_databank2_en;
        wire [ 3:0] way0_databank2_we;
        wire [ 7:0] way0_databank2_addr;
        wire [31:0] way0_databank2_wdata;
        wire [31:0] way0_databank2_rdata;
        // bank3
        wire        way0_databank3_en;
        wire [ 3:0] way0_databank3_we;
        wire [ 7:0] way0_databank3_addr;
        wire [31:0] way0_databank3_wdata;
        wire [31:0] way0_databank3_rdata;
    // way1
        // tagv
        wire        way1_tagv_en;
        wire        way1_tagv_we;
        wire [ 7:0] way1_tagv_addr;
        wire [20:0] way1_tagv_wdata;
        wire [20:0] way1_tagv_rdata;
        // bank0
        wire        way1_databank0_en;
        wire [ 3:0] way1_databank0_we;
        wire [ 7:0] way1_databank0_addr;
        wire [31:0] way1_databank0_wdata;
        wire [31:0] way1_databank0_rdata;
        // bank1
        wire        way1_databank1_en;
        wire [ 3:0] way1_databank1_we;
        wire [ 7:0] way1_databank1_addr;
        wire [31:0] way1_databank1_wdata;
        wire [31:0] way1_databank1_rdata;
        // bank2
        wire        way1_databank2_en;
        wire [ 3:0] way1_databank2_we;
        wire [ 7:0] way1_databank2_addr;
        wire [31:0] way1_databank2_wdata;
        wire [31:0] way1_databank2_rdata;
        // bank3
        wire        way1_databank3_en;
        wire [ 3:0] way1_databank3_we;
        wire [ 7:0] way1_databank3_addr;
        wire [31:0] way1_databank3_wdata;
        wire [31:0] way1_databank3_rdata;

// others
    reg         reg_wr_req;
    reg [255:0] way0_d;
    reg [255:0] way1_d;

// output
always @(posedge clk) begin
    if(reset)
        reg_wr_req <= 1'b0;
    else if (main_state == MISS & wr_rdy)
        reg_wr_req <= 1'b1;
    else if (reg_wr_req)
        reg_wr_req <= 1'b0;
end
assign addr_ok  = main_state == IDLE | (main_state == LOOKUP & main_state_r == LOOKUP);
assign data_ok  = (cache_hit & main_state == LOOKUP) | (main_state == REFILL & ret_valid & (ret_bank == reg_offset[3:2]));
assign rdata    = ret_valid ? ret_data : load_res;
assign wr_req   = reg_wr_req & (replace_way ? (way1_v & way1_d[reg_index]) : (way0_v & way0_d[reg_index]));
assign wr_type  = 3'b100;
assign wr_addr  = { (replace_way ? way1_tag : way0_tag), reg_index, reg_offset };
assign wr_wstrb = 4'b1111;
assign wr_data  = replace_data;
assign rd_req   = main_state == REPLACE;
assign rd_type  = 3'b100;
assign rd_addr  = { reg_tag, reg_index, 4'b0 };

// request buffer
assign req_en = (valid & main_state == IDLE & addr_ok) | (valid & main_state == LOOKUP & cache_hit);
always @(posedge clk) begin
    if (reset) begin
        reg_op     <=  1'b0;
        reg_index  <=  8'b0;
        reg_tag    <= 20'b0;
        reg_offset <=  4'b0;
        reg_wstrb  <=  4'b0;
        reg_wdata  <= 32'b0;
    end
    else if (req_en) begin
        reg_op     <= op    ;
        reg_index  <= index ;
        reg_tag    <= tag   ;
        reg_offset <= offset;
        reg_wstrb  <= wstrb ;
        reg_wdata  <= wdata ;
    end
end

// tag compare
assign way0_v    = way0_tagv_rdata[0];
assign way1_v    = way1_tagv_rdata[0];
assign way0_tag  = way0_tagv_rdata[20:1];
assign way1_tag  = way1_tagv_rdata[20:1];
assign way0_hit  = way0_v && (way0_tag == reg_tag);
assign way1_hit  = way1_v && (way1_tag == reg_tag);
assign cache_hit = way0_hit | way1_hit;

// data select
assign way0_data      = { way0_databank3_rdata, way0_databank2_rdata,
                          way0_databank1_rdata, way0_databank0_rdata };
assign way1_data      = { way1_databank3_rdata, way1_databank2_rdata,
                          way1_databank1_rdata, way1_databank0_rdata };
assign way0_load_word = way0_data[reg_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[reg_offset[3:2]*32 +: 32];
assign load_res       = {32{way0_hit}} & way0_load_word
                      | {32{way1_hit}} & way1_load_word;
                      // 如果考虑 miss，应该是三选一
assign replace_data   = replace_way ? way1_data : way0_data;
assign replace_way    = lfsr;

// miss buffer
always @(posedge clk) begin
    if (reset | (main_state == REPLACE & rd_rdy))
        ret_bank <= 1'b0;
    else if (ret_valid & ~ret_last)
        ret_bank <= ret_bank + 1;
    else if (ret_valid & ret_last)
        ret_bank <= 1'b0;
end

// LFSR
always @(posedge clk) begin
    if (main_state == MISS & wr_rdy)
        lfsr <= $random % 2;
end

// write buffer
assign hit_write     = main_state == LOOKUP & cache_hit & reg_op;
assign hit_write_con = (main_state == LOOKUP & reg_op & ~op & valid & offset[3:2] == reg_offset[3:2]) |
                       (write_state == WRITE & ~op & valid & offset[3:2] == reg_offset[3:2]);
always @(posedge clk) begin
    if (reset) begin
        reg_way       <=  1'b0;
        reg_bank      <=  2'b0;
        reg_reg_index <=  8'b0;
        reg_reg_wstrb <=  4'b0;
        reg_reg_wdata <= 32'b0;
    end
    else if (hit_write) begin
        reg_way       <= way1_hit;
        reg_bank      <= reg_offset[3:2];
        reg_reg_index <= reg_index;
        reg_reg_wstrb <= reg_wstrb;
        reg_reg_wdata <= reg_wdata;
    end
end

// main state machine
always @(posedge clk) begin
    if (reset) begin
        main_state <= IDLE;
    end
    else begin
        main_state <= main_state_r;
    end
end
always @(*) begin
    case(main_state)
        IDLE: begin
            if (hit_write_con)
                main_state_r <= IDLE;
            else if (valid)
                main_state_r <= LOOKUP;
            else
                main_state_r <= IDLE;
        end
        LOOKUP:begin
            if (hit_write_con)
                main_state_r <= IDLE;
            else if (~cache_hit)
                main_state_r <= MISS;
            else if (valid)
                main_state_r <= LOOKUP;
            else
                main_state_r <= IDLE;
        end
        MISS:begin
            if (wr_rdy)
                main_state_r <= REPLACE;
            else
                main_state_r <= MISS;
        end
        REPLACE:begin
            if (rd_rdy)
                main_state_r <= REFILL;
            else
                main_state_r <= REPLACE;
        end
        REFILL:begin
            if (ret_valid & ret_last)
                main_state_r <= IDLE;
            else
                main_state_r <= REFILL;
        end
        default:
            main_state_r <= IDLE;
    endcase
end

// write state machine
always @(posedge clk) begin
    if (reset) begin
        write_state <= IDLEW;
    end
    else begin
        write_state <= write_state_r;
    end
end
always @(*) begin
    case(write_state)
        IDLEW:begin
            if (hit_write)
                write_state_r <= WRITE;
            else begin
                write_state_r <= IDLEW;
            end
        end
        WRITE:begin
            if (hit_write)
                write_state_r <= WRITE;
            else begin
                write_state_r <= IDLEW;
            end
        end
        default:
            write_state_r <= IDLEW;
    endcase
end

// dirty
always @(posedge clk) begin
    if (reset) begin
        way0_d <= 255'd0;
        way1_d <= 255'd0;
    end
    else if (write_state == WRITE) begin
        if (reg_way)
            way1_d[reg_reg_index] <= 1'b1;
        else
            way0_d[reg_reg_index] <= 1'b1;
    end
    else if (main_state == REFILL & ret_valid & ret_last) begin
        if (replace_way) begin
            if(reg_op)
                way1_d[reg_index] <= 1'b1;
            else
                way1_d[reg_index] <= 1'b0;
        end
        else begin
            if(reg_op)
                way0_d[reg_index] <= 1'b1;
            else
                way0_d[reg_index] <= 1'b0;
        end
    end
end

// tagv
assign way0_tagv_en    = 1'b1;
assign way1_tagv_en    = 1'b1;
assign way0_tagv_we    = main_state == REFILL & valid & ret_valid & ret_last & ~replace_way;
assign way1_tagv_we    = main_state == REFILL & valid & ret_valid & ret_last & replace_way;
assign way0_tagv_addr  = (main_state == REFILL | main_state == MISS) ? reg_index : index;
assign way1_tagv_addr  = (main_state == REFILL | main_state == MISS) ? reg_index : index;
assign way0_tagv_wdata = { reg_tag, 1'b1 };
assign way1_tagv_wdata = { reg_tag, 1'b1 };
// write
assign write_way0_databank0 = write_state == WRITE & reg_way == 1'b0 & reg_bank == 2'b00;
assign write_way0_databank1 = write_state == WRITE & reg_way == 1'b0 & reg_bank == 2'b01;
assign write_way0_databank2 = write_state == WRITE & reg_way == 1'b0 & reg_bank == 2'b10;
assign write_way0_databank3 = write_state == WRITE & reg_way == 1'b0 & reg_bank == 2'b11;
assign write_way1_databank0 = write_state == WRITE & reg_way == 1'b1 & reg_bank == 2'b00;
assign write_way1_databank1 = write_state == WRITE & reg_way == 1'b1 & reg_bank == 2'b01;
assign write_way1_databank2 = write_state == WRITE & reg_way == 1'b1 & reg_bank == 2'b10;
assign write_way1_databank3 = write_state == WRITE & reg_way == 1'b1 & reg_bank == 2'b11;
//refill
assign refill_way0_databank0 = ret_valid & main_state == REFILL & ret_bank == 2'b00 & replace_way == 1'b0;
assign refill_way0_databank1 = ret_valid & main_state == REFILL & ret_bank == 2'b01 & replace_way == 1'b0;
assign refill_way0_databank2 = ret_valid & main_state == REFILL & ret_bank == 2'b10 & replace_way == 1'b0;
assign refill_way0_databank3 = ret_valid & main_state == REFILL & ret_bank == 2'b11 & replace_way == 1'b0;
assign refill_way1_databank0 = ret_valid & main_state == REFILL & ret_bank == 2'b00 & replace_way == 1'b1;
assign refill_way1_databank1 = ret_valid & main_state == REFILL & ret_bank == 2'b01 & replace_way == 1'b1;
assign refill_way1_databank2 = ret_valid & main_state == REFILL & ret_bank == 2'b10 & replace_way == 1'b1;
assign refill_way1_databank3 = ret_valid & main_state == REFILL & ret_bank == 2'b11 & replace_way == 1'b1;
// en
assign way0_databank0_en = ~hit_write_con;
assign way0_databank1_en = ~hit_write_con;
assign way0_databank2_en = ~hit_write_con;
assign way0_databank3_en = ~hit_write_con;
assign way1_databank0_en = ~hit_write_con;
assign way1_databank1_en = ~hit_write_con;
assign way1_databank2_en = ~hit_write_con;
assign way1_databank3_en = ~hit_write_con;
// we
assign way0_databank0_we = ({4{write_way0_databank0 }} & reg_reg_wstrb)
                         | ({4{refill_way0_databank0}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way0_databank1_we = ({4{write_way0_databank1 }} & reg_reg_wstrb)
                         | ({4{refill_way0_databank1}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way0_databank2_we = ({4{write_way0_databank2 }} & reg_reg_wstrb)
                         | ({4{refill_way0_databank2}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way0_databank3_we = ({4{write_way0_databank3 }} & reg_reg_wstrb)
                         | ({4{refill_way0_databank3}} & (reg_op ? reg_wstrb : 4'b1111));   
assign way1_databank0_we = ({4{write_way1_databank0 }} & reg_reg_wstrb)
                         | ({4{refill_way1_databank0}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way1_databank1_we = ({4{write_way1_databank1 }} & reg_reg_wstrb)
                         | ({4{refill_way1_databank1}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way1_databank2_we = ({4{write_way1_databank2 }} & reg_reg_wstrb)
                         | ({4{refill_way1_databank2}} & (reg_op ? reg_wstrb : 4'b1111));  
assign way1_databank3_we = ({4{write_way1_databank3 }} & reg_reg_wstrb)
                         | ({4{refill_way1_databank3}} & (reg_op ? reg_wstrb : 4'b1111));
// addr
assign way0_databank0_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way0_databank0}} & reg_reg_index);
assign way0_databank1_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way0_databank1}} & reg_reg_index);
assign way0_databank2_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way0_databank2}} & reg_reg_index);
assign way0_databank3_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way0_databank3}} & reg_reg_index);
assign way1_databank0_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way1_databank0}} & reg_reg_index);
assign way1_databank1_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way1_databank1}} & reg_reg_index);
assign way1_databank2_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way1_databank2}} & reg_reg_index);
assign way1_databank3_addr = ({8{(main_state == IDLE | main_state == LOOKUP)}} & index)
                           | ({8{(main_state == MISS | main_state == REFILL)}} & reg_index)
                           | ({8{write_way1_databank3}} & reg_reg_index);
// wdata
assign way0_databank0_wdata = ({32{write_way0_databank0 }} & reg_reg_wdata & way0_hit)
                            | ({32{write_way0_databank0 }} & ~way0_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way0_databank0}} & ((reg_op & reg_offset[3:2]==2'b00) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way0_databank1_wdata = ({32{write_way0_databank1 }} & reg_reg_wdata & way0_hit)
                            | ({32{write_way0_databank1 }} & ~way0_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way0_databank1}} & ((reg_op & reg_offset[3:2]==2'b01) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way0_databank2_wdata = ({32{write_way0_databank2 }} & reg_reg_wdata & way0_hit)
                            | ({32{write_way0_databank2 }} & ~way0_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way0_databank2}} & ((reg_op & reg_offset[3:2]==2'b10) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way0_databank3_wdata = ({32{write_way0_databank3 }} & reg_reg_wdata & way0_hit)
                            | ({32{write_way0_databank3 }} & ~way0_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way0_databank3}} & ((reg_op & reg_offset[3:2]==2'b11) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way1_databank0_wdata = ({32{write_way1_databank0 }} & reg_reg_wdata & way1_hit)
                            | ({32{write_way1_databank0 }} & ~way1_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way1_databank0}} & ((reg_op & reg_offset[3:2]==2'b00) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way1_databank1_wdata = ({32{write_way1_databank1 }} & reg_reg_wdata & way1_hit)
                            | ({32{write_way1_databank1 }} & ~way1_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way1_databank1}} & ((reg_op & reg_offset[3:2]==2'b01) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way1_databank2_wdata = ({32{write_way1_databank2 }} & reg_reg_wdata & way1_hit)
                            | ({32{write_way1_databank2 }} & ~way1_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way1_databank2}} & ((reg_op & reg_offset[3:2]==2'b10) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));
assign way1_databank3_wdata = ({32{write_way1_databank3 }} & reg_reg_wdata & way1_hit)
                            | ({32{write_way1_databank3 }} & ~way1_hit & 
                            { reg_reg_wstrb[3] ? reg_reg_wdata[31:24] : ret_data[31:24] ,
                              reg_reg_wstrb[2] ? reg_reg_wdata[23:16] : ret_data[23:16] ,
                              reg_reg_wstrb[1] ? reg_reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_reg_wstrb[0] ? reg_reg_wdata[ 7: 0] : ret_data[ 7: 0] })
                            | ({32{refill_way1_databank3}} & ((reg_op & reg_offset[3:2]==2'b11) ?
                            { reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24] ,
                              reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16] ,
                              reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8] ,
                              reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0] }
                            : ret_data));

// TAGV RAM: RAM 256 * 21 (2 blocks)
    // way0
    TAGV_RAM way0_tagv(
        .clka (clk            ), //时钟信号
        .ena  (way0_tagv_en   ), //端口 A 使能信号，高电平有效
        .wea  (way0_tagv_we   ), //写使能信号，高电平表示写入，低电平表示读出
        .addra(way0_tagv_addr ), //地址信号
        .dina (way0_tagv_wdata), //写数据端口
        .douta(way0_tagv_rdata)  //读数据端口
    );
    // way1
    TAGV_RAM way1_tagv(
        .clka (clk            ),
        .ena  (way1_tagv_en   ),
        .wea  (way1_tagv_we   ),
        .addra(way1_tagv_addr ),
        .dina (way1_tagv_wdata),
        .douta(way1_tagv_rdata)
    );
// DATA Bank RAM: RAM 256 * 32 (8 blocks)
    // way0 bank0
    DATABank_RAM way0_databank0(
        .clka (clk                 ),
        .ena  (way0_databank0_en   ),
        .wea  (way0_databank0_we   ),
        .addra(way0_databank0_addr ),
        .dina (way0_databank0_wdata),
        .douta(way0_databank0_rdata)
    );
    // way0 bank1
    DATABank_RAM way0_databank1(
        .clka (clk                 ),
        .ena  (way0_databank1_en   ),
        .wea  (way0_databank1_we   ),
        .addra(way0_databank1_addr ),
        .dina (way0_databank1_wdata),
        .douta(way0_databank1_rdata)
    );
    // way0 bank2
    DATABank_RAM way0_databank2(
        .clka (clk                 ),
        .ena  (way0_databank2_en   ),
        .wea  (way0_databank2_we   ),
        .addra(way0_databank2_addr ),
        .dina (way0_databank2_wdata),
        .douta(way0_databank2_rdata)
    );
    // way0 bank3
    DATABank_RAM way0_databank3(
        .clka (clk                 ),
        .ena  (way0_databank3_en   ),
        .wea  (way0_databank3_we   ),
        .addra(way0_databank3_addr ),
        .dina (way0_databank3_wdata),
        .douta(way0_databank3_rdata)
    );
    // way1 bank0
    DATABank_RAM way1_databank0(
        .clka (clk                 ),
        .ena  (way1_databank0_en   ),
        .wea  (way1_databank0_we   ),
        .addra(way1_databank0_addr ),
        .dina (way1_databank0_wdata),
        .douta(way1_databank0_rdata)
    );
    // way1 bank1
    DATABank_RAM way1_databank1(
        .clka (clk                 ),
        .ena  (way1_databank1_en   ),
        .wea  (way1_databank1_we   ),
        .addra(way1_databank1_addr ),
        .dina (way1_databank1_wdata),
        .douta(way1_databank1_rdata)
    );
    // way1 bank2
    DATABank_RAM way1_databank2(
        .clka (clk                 ),
        .ena  (way1_databank2_en   ),
        .wea  (way1_databank2_we   ),
        .addra(way1_databank2_addr ),
        .dina (way1_databank2_wdata),
        .douta(way1_databank2_rdata)
    );
    // way1 bank3
    DATABank_RAM way1_databank3(
        .clka (clk                 ),
        .ena  (way1_databank3_en   ),
        .wea  (way1_databank3_we   ),
        .addra(way1_databank3_addr ),
        .dina (way1_databank3_wdata),
        .douta(way1_databank3_rdata)
    );

endmodule