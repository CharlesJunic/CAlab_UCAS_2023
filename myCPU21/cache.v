module cache (
    input wire clk,
    input wire resetn,
    
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
    output [  2:0] rd_type,     // 读请求类型: 3'b000--字节，3'b001--半字，3'b010--字，3'b100--Cache 行
    output [ 31:0] rd_addr,     // 读请求起始地址
    input          rd_rdy,      // 读请求能否被接收的握手信号
    input          ret_valid,   // 返回数据有效信号
    input          ret_last,    // 返回数据是一次读请求对应的最后一个返回数据
    input  [ 31:0] ret_data,    // 读返回数据
    output         wr_req,      // 写请求有效信号
    output [  2:0] wr_type,     // 写请求类型: 3'b000--字节，3'b001--半字，3'b010--字，3'b100--Cache 行
    output [ 31:0] wr_addr,     // 写请求起始地址
    output [  3:0] wr_wstrb,    // 写操作的字节掩码，仅在写请求类型为 3'b000、3'b001、3'b010 情况下才有意义
    output [127:0] wr_data,     // 写数据
    input          wr_rdy       // 写请求能否被接收的握手信号
);
wire reset;
assign reset = ~resetn;

// request buffer
reg         rb_op;
reg  [ 7:0] rb_index;
reg  [19:0] rb_tag;
reg  [ 3:0] rb_offset;
reg  [ 3:0] rb_wstrb;
reg  [31:0] rb_wdata;
wire [31:0] rb_wstrb_extend;

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
wire [31:0]  way0_load_word;
wire [31:0]  way1_load_word;
wire [31:0]  load_res;
wire [127:0] replace_data;
reg          replace_way;
wire         replace_d;
wire [ 19:0] replace_tag;

// miss buffer
reg [31:0]  ret_bank;

// LFSR
reg         lfsr;

// Data Bank Ram signels
wire [3:0] way0_data_wen;
wire [3:0] way1_data_wen;
wire [ 7:0] way0_data_addr [3:0];
wire [ 7:0] way1_data_addr [3:0];
wire [31:0] way0_data_wdata[3:0];
wire [31:0] way1_data_wdata[3:0];
wire [31:0] way0_data_rdata[3:0];
wire [31:0] way1_data_rdata[3:0];

wire [31:0] way0_data_refill[3:0];
wire [31:0] way1_data_refill[3:0];

// Dirty
reg [255:0] way0_d_array;
reg [255:0] way1_d_array;
reg way0_d;
reg way1_d;

// write buffer
wire        hit_write;
wire        hit_write_con;
wire        hit_write_con_lookup;
wire        hit_write_con_write;
reg  [ 7:0] wb_index;
reg         wb_way;
reg  [ 3:0] wb_offset;
reg  [ 3:0] wb_wstrb;
wire [31:0] wb_wstrb_extend;
reg  [31:0] wb_wdata;
reg  [31:0] wb_odata;

// others
reg  wr_req_r;

// tavg ram signels
wire        way0_tagv_wen;
wire [7:0]  way0_tagv_addr;
wire [20:0] way0_tagv_wdata;
wire [20:0] way0_tagv_rdata;
wire        way1_tagv_wen;
wire [7:0]  way1_tagv_addr;
wire [20:0] way1_tagv_wdata;
wire [20:0] way1_tagv_rdata;

// main state machine
localparam M_IDLE       = 5'b00001,
           M_LOOKUP     = 5'b00010,
           M_MISS       = 5'b00100,
           M_REPLACE    = 5'b01000,
           M_REFILL     = 5'b10000;
reg [4:0] main_state;
reg [4:0] main_next_state;

// write state machine
localparam W_IDLE   = 2'b01,
           W_WRITE  = 2'b10;
reg [1:0] write_state;
reg [1:0] write_next_state;

// main state machine
always @(posedge clk)
begin
    if(reset)
        main_state <= M_IDLE;
    else
        main_state <= main_next_state;
end
always @(*)begin
    case (main_state)
        M_IDLE:
        begin
            if (valid & ~hit_write_con)
                main_next_state = M_LOOKUP;
            else 
                main_next_state = M_IDLE;
        end
        M_LOOKUP:
        begin
            if (cache_hit & (~valid | valid & hit_write_con))
                main_next_state = M_IDLE;
            else if (cache_hit & valid & ~hit_write_con)
                main_next_state = M_LOOKUP;
            else if (~cache_hit)
                main_next_state = M_MISS;
            else
                main_next_state = M_LOOKUP;
        end
        M_MISS:
        begin
            if (wr_rdy)
                main_next_state = M_REPLACE;
            else
                main_next_state = M_MISS;
        end
        M_REPLACE:
            if (rd_rdy)
                main_next_state = M_REFILL;
            else 
                main_next_state = M_REPLACE;
        M_REFILL:
        begin
            if (ret_valid & ret_last)
                main_next_state = M_IDLE;
            else 
                main_next_state = M_REFILL;
        end
        default:
        begin
            main_next_state = M_IDLE;
        end
    endcase
end

// write state machine
always @(posedge clk)
begin
    if(reset)
        write_state <= W_IDLE;
    else
        write_state <= write_next_state;
end

always @(*)begin
    case (write_state)
        W_IDLE:
        begin
            if (hit_write)
                write_next_state = W_WRITE;
            else 
                write_next_state = W_IDLE;
        end
        W_WRITE:
        begin
            if (hit_write)
                write_next_state = W_WRITE;
            else 
                write_next_state = W_IDLE;
        end
        default:
        begin
            write_next_state = W_IDLE;
        end
    endcase
end

// tagv
assign way0_tagv_wen = (main_state == M_REFILL) & ~replace_way;
assign way1_tagv_wen = (main_state == M_REFILL) & replace_way;
assign way0_tagv_addr = {8{main_state == M_IDLE}} & index
                      | {8{main_state == M_LOOKUP}} & rb_index
                      | {8{main_state == M_MISS}} & rb_index
                      | {8{main_state == M_REFILL}} & rb_index;
assign way1_tagv_addr = {8{main_state == M_IDLE}} & index
                      | {8{main_state == M_LOOKUP}} & rb_index
                      | {8{main_state == M_MISS}} & rb_index
                      | {8{main_state == M_REFILL}} & rb_index;
assign way0_tagv_wdata = {21{main_state == M_REFILL}} & {rb_tag, 1'b1};
assign way1_tagv_wdata = {21{main_state == M_REFILL}} & {rb_tag, 1'b1};
assign {way0_tag, way0_v} = way0_tagv_rdata;
assign {way1_tag, way1_v} = way1_tagv_rdata;

// TAGV RAM 256 * 21 (2 blocks)
TAGV_RAM way0_tagv_ram (
             .clka (clk             ),  //时钟信号
             .wea  (way0_tagv_wen   ),  //写使能信号，高电平表示写入，低电平表示读出
             .addra(way0_tagv_addr  ),  //地址信号
             .dina (way0_tagv_wdata ),  //写数据端口
             .douta(way0_tagv_rdata )   //读数据端口
         );
TAGV_RAM way1_tagv_ram (
             .clka (clk),
             .wea  (way1_tagv_wen),
             .addra(way1_tagv_addr),
             .dina (way1_tagv_wdata),
             .douta(way1_tagv_rdata)
         );

// Data Bank RAM 256 * 32 (8 blocks)
genvar i;
generate
    for (i = 0; i < 4; i = i + 1)
    begin : data_bank_gen
        DATABank_RAM way0_data_bank_ram (
                          .clka (clk),
                          .wea  (way0_data_wen[i]),
                          .addra(way0_data_addr[i]),
                          .dina (way0_data_wdata[i]),
                          .douta(way0_data_rdata[i])
                      );
        DATABank_RAM way1_data_bank_ram (
                          .clka (clk),
                          .wea  (way1_data_wen[i]),
                          .addra(way1_data_addr[i]),
                          .dina (way1_data_wdata[i]),
                          .douta(way1_data_rdata[i])
                      );
    end
endgenerate
assign wb_wstrb_extend = {{8{wb_wstrb[3]}}, {8{wb_wstrb[2]}}, {8{wb_wstrb[1]}}, {8{wb_wstrb[0]}}};
assign rb_wstrb_extend = {{8{rb_wstrb[3]}}, {8{rb_wstrb[2]}}, {8{rb_wstrb[1]}}, {8{rb_wstrb[0]}}};
generate
    for (i = 0; i < 4; i = i + 1)
    begin : data_bank_IO_gen
        assign way0_data_wen[i]    = (write_state == W_WRITE) & wb_offset[3:2] == i
                                     | (main_state == M_REFILL) & ~replace_way & ret_bank == i;
        assign way1_data_wen[i]    = (write_state == W_WRITE) & wb_offset[3:2] == i
                                     | (main_state == M_REFILL) & replace_way & ret_bank == i;
        assign way0_data_addr[i]   = {8{main_state == M_IDLE}} & index
                                     | {8{main_state == M_LOOKUP}} & index
                                     | {8{main_state == M_MISS}} & rb_index
                                     | {8{main_state == M_REFILL}} & rb_index
                                     | {8{write_state == W_WRITE}} & wb_index;
        assign way1_data_addr[i]   = {8{main_state == M_IDLE}} & index
                                     | {8{main_state == M_LOOKUP}} & index
                                     | {8{main_state == M_MISS}} & rb_index
                                     | {8{main_state == M_REFILL}} & rb_index
                                     | {8{write_state == W_WRITE}} & wb_index;
        assign way0_data_refill[i] = ((rb_op == 1 & rb_offset[3:2] == i) ? (ret_data & ~rb_wstrb_extend | rb_wdata & rb_wstrb_extend) : ret_data);
        assign way0_data_wdata[i]  = {32{write_state == W_WRITE}} & (wb_odata & ~wb_wstrb_extend | wb_wdata & wb_wstrb_extend)
                                     | {32{main_state == M_REFILL}} & way0_data_refill[i];
        assign way1_data_refill[i] = ((rb_op == 1 & rb_offset[3:2] == i) ? (ret_data & ~rb_wstrb_extend | rb_wdata & rb_wstrb_extend) : ret_data);
        assign way1_data_wdata[i]  = {32{write_state == W_WRITE}} & (wb_odata & ~wb_wstrb_extend | wb_wdata & wb_wstrb_extend)
                                     | {32{main_state == M_REFILL}} & way1_data_refill[i];
        assign way0_data[i*32+:32] = way0_data_rdata[i];
        assign way1_data[i*32+:32] = way1_data_rdata[i];
    end
endgenerate

// Dirty
// way0
always @(posedge clk)
begin
    if (reset)begin
        way0_d_array <= 256'b0;
    end 
    else if (write_state == W_IDLE & ~wb_way)begin
        way0_d_array[wb_index] <= 1'b0;
    end 
    else if (main_state == M_REFILL & ~replace_way)begin
        if (rb_op == 1)begin
            way0_d_array[rb_index] <= 1'b1;
        end else begin
            way0_d_array[rb_index] <= 1'b0;
        end
    end
end
// way1
always @(posedge clk)
begin
    if (reset)
        way1_d_array <= 256'b0;
    else if (write_state == W_IDLE & wb_way)
        way1_d_array[wb_index] <= 1'b0;
    else if (main_state == M_REFILL & replace_way)begin
        if (rb_op == 1)
            way1_d_array[rb_index] <= 1'b1;
        else
            way1_d_array[rb_index] <= 1'b0;
    end
end
// way0
always @(posedge clk)
begin
    if (reset) 
        way0_d <= 1'b0;
    else if (main_state == M_MISS & main_next_state == M_REPLACE)
        way0_d <= way0_d_array[rb_index];
end
// way1
always @(posedge clk)
begin
    if (reset)begin
        way1_d <= 1'b0;
    end else if (main_state == M_MISS & main_next_state == M_REPLACE) begin
        way1_d <= way1_d_array[rb_index];
    end
end

// request buffer
always @(posedge clk)
begin
    if (reset)begin
        rb_op     <= 1'b0;
        rb_index  <= 8'b0;
        rb_tag    <= 20'b0;
        rb_offset <= 4'b0;
        rb_wstrb  <= 4'b0;
        rb_wdata  <= 32'b0;
    end else if (main_next_state == M_LOOKUP)begin
        rb_op     <= op;
        rb_index  <= index;
        rb_tag    <= tag;
        rb_offset <= offset;
        rb_wstrb  <= wstrb;
        rb_wdata  <= wdata;
    end
end

// tag compare
assign way0_hit       = way0_v && (way0_tag == rb_tag);
assign way1_hit       = way1_v && (way1_tag == rb_tag);
assign cache_hit      = way0_hit | way1_hit;

// data select
assign way0_load_word = way0_data[rb_offset[3:2]*32+:32];
assign way1_load_word = way1_data[rb_offset[3:2]*32+:32];
// 三选一
assign load_res       = (main_state == M_REFILL) ? ret_data : {32{way0_hit}} & way0_load_word | {32{way1_hit}} & way1_load_word;

// miss buffer
always @(posedge clk)
begin
    if (reset)
        ret_bank <= 32'b0;
    else if (ret_valid & ret_last)
        ret_bank <= 32'b0;
    else if (ret_valid & ~ret_last)
        ret_bank <= ret_bank + 1;
end

// replace
always @(posedge clk)
begin
    if (reset)begin
        replace_way <= 1'b0;
    end else if (main_state == M_LOOKUP & ~cache_hit)begin
        replace_way <= lfsr;
    end
end

assign replace_data = replace_way ? way1_data : way0_data;
assign replace_tag  = replace_way ? way1_tag : way0_tag;
assign replace_d    = replace_way ? (way1_v & way1_d) : (way0_v & way0_d);

// lfsr
always @(posedge clk)begin
    if (reset)
        lfsr <= 1'b0;
    else
        lfsr <= $random % 2;
    
end

// write buffer
assign hit_write = main_state == M_LOOKUP & cache_hit & rb_op;
// hit write conflict
assign hit_write_con_lookup = (main_state == M_LOOKUP) & (rb_op) & cache_hit & valid & (~op) & (rb_tag == tag) & (rb_index == index) & (rb_offset[3:2] == offset[3:2]);
assign hit_write_con_write = (write_state == W_WRITE) & valid & (~op) & (wb_index == index) & (wb_offset[3:2] == offset[3:2]);
assign hit_write_con = hit_write_con_lookup | hit_write_con_write;

always @(posedge clk)begin
    if (reset)begin
        wb_way    <= 1'b0;
        wb_index  <= 8'b0;
        wb_offset <= 4'b0;
        wb_wstrb  <= 4'b0;
        wb_wdata  <= 32'b0;
    end else if (hit_write)begin
        wb_index  <= rb_index;
        wb_way    <= way1_hit;
        wb_offset <= rb_offset;
        wb_wstrb  <= rb_wstrb;
        wb_wdata  <= rb_wdata;
        wb_odata  <= load_res;
    end
end

// output
always @(posedge clk)begin
    if (reset)begin
        wr_req_r <= 1'b0;
    end else if (main_state == M_MISS & main_next_state == M_REPLACE)begin
        wr_req_r <= 1'b1;
    end else if (wr_rdy)begin
        wr_req_r <= 1'b0;
    end
end
assign addr_ok = (main_state == M_IDLE & ~hit_write_con) | (main_state == M_LOOKUP & cache_hit & ~hit_write_con);
assign data_ok = (main_state == M_LOOKUP & cache_hit) | (main_state == M_REFILL & ret_valid & ret_bank == rb_offset[3:2]);
assign rdata   = ({32{main_state == M_LOOKUP}} & load_res) | ({32{main_state == M_REFILL}} & ret_data);
assign wr_req = wr_req_r & replace_d;
assign wr_type = 3'b100;
assign wr_addr = {replace_tag, rb_index, 4'b0};
assign wr_wstrb = 4'b0;
assign wr_data = replace_data;
assign rd_req  = main_state == M_REPLACE;
assign rd_type = 3'b100;
assign rd_addr = { rb_tag, rb_index, 4'b0 };


endmodule