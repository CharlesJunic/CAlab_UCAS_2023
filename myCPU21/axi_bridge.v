module axi_bridge(
    input         clk,
    input         resetn,
    /*input         inst_sram_req,
    input         inst_sram_wr,
    input  [ 1:0] inst_sram_size,*/
    input  [ 3:0] inst_sram_wstrb,
    /*input  [31:0] inst_sram_addr,*/
    input  [31:0] inst_sram_wdata,
    /*output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    output [31:0] inst_sram_rdata,*/
    //icache read
    input         icache_rd_req,
    input  [ 2:0] icache_rd_type,
    input  [31:0] icache_rd_addr,
    output        icache_rd_rdy,
    output        icache_ret_valid,
    output        icache_ret_last,
    output [31:0] icache_ret_data,

    input         data_sram_req,
    input         data_sram_wr,
    input  [ 1:0] data_sram_size,
    input  [ 3:0] data_sram_wstrb,
    input  [31:0] data_sram_addr,
    input  [31:0] data_sram_wdata,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    output [31:0] data_sram_rdata,
    output [ 3:0] arid,         //读请求的id号，取指0，取数1
    output [31:0] araddr,       //读请求地址
    output [ 7:0] arlen,        //读请求传输长度，固定为0
    output [ 2:0] arsize,       //读请求传输大小
    output [ 1:0] arburst,      //读请求传输类型，固定为0b01
    output [ 1:0] arlock,       //读请求原子锁，固定为0
    output [ 3:0] arcache,      //读请求cache属性，固定为0
    output [ 2:0] arprot,       //读请求保护属性，固定为0
    output        arvalid,      //读请求握手信号，地址有效
    input         arready,      //读请求握手信号，slave端准备好接收地址传输
    input  [ 3:0] rid,          //读请求的id号，同一请求的rid和arid一致，取指0，取数1
    input  [31:0] rdata,        //读请求读回数据
    input  [ 1:0] rresp,        //读请求，本次是否成功完成，可忽略
    input         rlast,        //读请求，数据有效，可忽略
    input         rvalid,       //读请求握手信号，数据有效
    input         rready,       //读请求握手信号，master端准备好接受数据传输
    output [ 3:0] awid,         //写请求的id号，固定为1
    output [31:0] awaddr,       //写请求的地址
    output [ 7:0] awlen,        //写请求，请求传输长度，固定为0
    output [ 2:0] awsize,       //写请求，请求传输大小
    output [ 1:0] awburst,      //写请求，传输类型，固定为0b01
    output [ 1:0] awlock,       //写请求，原子锁，固定为0
    output [ 3:0] awcache,      //写请求，cache属性，固定为0
    output [ 2:0] awprot,       //写请求，保护属性，固定为0
    output        awvalid,      //写请求握手信号，地址有效
    input         awready,      //写请求握手信号，slave端准备好接受地址传输
    output [ 3:0] wid,          //写请求的id号，固定为1
    output [31:0] wdata,        //写请求数据
    output [ 3:0] wstrb,        //写请求，字节选通位
    output        wlast,        //写请求，本次写请求的最后一拍数据的指示信号，固定为1
    output        wvalid,       //写请求握手信号，数据有效
    output        wready,       //写请求握手信号，slave端准备好接受数据传输
    input  [ 3:0] bid,          //写请求的id号，同一请求的bid，wid，awid一致，可忽略
    input  [ 1:0] bresp,        //写请求，本次写请求是否成功完成，可忽略
    input         bvalid,       //写请求握手信号，写请求响应有效
    output        bready        //写请求握手信号，master端准备好接受写响应
);

wire [2:0] asize_data;
wire [2:0] asize_inst;
wire [7:0] inst_rd_len;
assign asize_data = {data_sram_size[1:0], ~(|data_sram_size[1:0])};
// assign asize_inst = {inst_sram_size[1:0], ~(|inst_sram_size[1:0])};
assign asize_inst = 3'd2;
//assign inst_rd_len = {3{icache_rd_type[2]}};
assign inst_rd_len = {6'b0, {2{icache_rd_type[2]}}};


/******************** DECALRATION ********************/

reg [7:0] r_cur_state;
reg [7:0] r_next_state;
reg [7:0] w_cur_state;
reg [7:0] w_next_state;
reg [ 3:0] arid_r;
reg [31:0] araddr_r;
reg [ 7:0] arlen_r;
reg [ 2:0] arsize_r;
reg        arvalid_r;
reg [ 2:0] rd_count;
reg [ 3:0] awid_r;
reg [31:0] awaddr_r;
reg [ 2:0] awsize_r;
reg        awvalid_r;
reg [31:0] wdata_r;
reg [ 3:0] wstrb_r;
wire cpu_inst_read_req;
wire cpu_inst_write_req;
wire cpu_data_read_req;
wire cpu_data_write_req;
/******************** READ STATE MACHINE ********************/

localparam READ_INIT = 8'h01,           //r_cur_state[0]  读初始化    
           READ_INST_REQ = 8'h02,       //r_cur_state[1]  读指令请求  
           READ_DATA_REQ = 8'h04,       //r_cur_state[2]  读数据请求  
           READ_DONE = 8'h08;           //r_cur_state[3]  读完成

always @(posedge clk) begin
    if(!resetn)
        r_cur_state <= READ_INIT;
    else
        r_cur_state <= r_next_state;
end

always @(*) begin
    case(r_cur_state)
        READ_INIT: begin
            if(cpu_inst_read_req)
                r_next_state = READ_INST_REQ;
            else if(cpu_data_read_req)
                r_next_state = READ_DATA_REQ;
            else
                r_next_state = READ_INIT;
        end
        READ_INST_REQ, READ_DATA_REQ: begin
            if(arvalid_r & arready)
                r_next_state = READ_DONE;
            else
                r_next_state = r_cur_state;
        end
        READ_DONE: begin
            if(rready & rvalid & (rd_count == arlen_r) )
                r_next_state = READ_INIT;
            else 
                r_next_state = READ_DONE;
        end
        default: 
            r_next_state = READ_INIT;
    endcase
end

always @(posedge clk) begin
    if(~resetn) begin
        arid_r <= 4'b0;
        arvalid_r <= 1'b0;
        arsize_r <= 3'b0;
        araddr_r <= 32'b0;
        arlen_r <= 8'b0;
    end
    else if(r_cur_state[0] & cpu_inst_read_req) begin
        arid_r <= 4'b0;
        arvalid_r <= 1'b1;
        arsize_r <= asize_inst;
        araddr_r <= icache_rd_addr;
        arlen_r <= inst_rd_len;
    end
    else if(r_cur_state[0] & cpu_data_read_req) begin
        arid_r <= 4'b1;
        arvalid_r <= 1'b1;
        arsize_r <= asize_data;
        araddr_r <= data_sram_addr;
        arlen_r <= 8'b0;
    end
    else if((r_cur_state[1] | r_cur_state[2]) & arready & arvalid) begin       
        arvalid_r <= 1'b0;
    end
    else if(r_cur_state[3] & rready & rvalid & (rd_count == arlen_r)) begin
        arid_r <= 4'b0;
        arsize_r <= 3'b0;
        araddr_r <= 32'b0;
        arlen_r <= 8'b0;
    end
end

/******************** READ COMBINATIONAL LOGIC ********************/

assign arid = arid_r;
assign araddr = araddr_r;
assign arlen = arlen_r;
assign arsize = arsize_r;
assign arburst = 2'b01;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arvalid = arvalid_r;
assign rready = (r_cur_state == READ_DONE);

/******************** READ BURST ********************/
 always @(posedge clk) begin
        if(~resetn)
            rd_count <= 3'b000;
        else if(r_cur_state[1] || r_cur_state[2])
            rd_count <= 3'b000;
        else if(r_cur_state[3] && rready & rvalid)
            rd_count <= rd_count + 3'b001;
    end
/******************** WRITE STATE MACHINE ********************/

localparam WRITE_INIT = 8'h01,          //w_cur_state[0]  写初始化
           WRITE_INST_REQ = 8'h02,      //w_cur_state[1]  写指令请求
           WRITE_DATA_REQ = 8'h04,      //w_cur_state[2]  写数据请求
           WRITE_DATA_OK = 8'h08,       //w_cur_state[3]  数据就绪
           WRITE_DONE = 8'h10;          //w_cur_state[4]  写完成

always @(posedge clk) begin
    if(!resetn)
        w_cur_state <= WRITE_INIT;
    else
        w_cur_state <= w_next_state;
end

always @(*) begin
    case(w_cur_state)
        WRITE_INIT: begin
            if(cpu_inst_write_req)
                w_next_state = WRITE_INST_REQ;
            else if(cpu_data_write_req)
                w_next_state = WRITE_DATA_REQ;
            else
                w_next_state = WRITE_INIT;
        end
        WRITE_INST_REQ: begin
            if(awvalid & awready)
                w_next_state = WRITE_DATA_OK;
            else 
                w_next_state = WRITE_INST_REQ;
        end
        WRITE_DATA_REQ: begin
            if(awvalid & awready)
                w_next_state = WRITE_DATA_OK;
            else
                w_next_state = WRITE_DATA_REQ;
        end
        WRITE_DATA_OK: begin
            if(wvalid & wready)
                w_next_state = WRITE_DONE;
            else    
                w_next_state = WRITE_DATA_OK;
        end
        WRITE_DONE: begin
            if(bvalid & bready)
                w_next_state = WRITE_INIT;
            else
                w_next_state = WRITE_DONE;
        end
        default:
            w_next_state = WRITE_INIT;
    endcase
end

always @(posedge clk) begin
    if(~resetn) begin
        awid_r <= 4'b0;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
        awvalid_r <= 1'b0;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end
    else if(w_cur_state[0] & cpu_inst_write_req) begin
        awid_r <= 4'b0;
        awaddr_r <= 32'b0;
        awsize_r <= asize_inst;
        awvalid_r <= 1'b1;
        wdata_r <= inst_sram_wdata;
        wstrb_r <= inst_sram_wstrb;
    end
    else if(w_cur_state[0] & cpu_data_write_req) begin
        awid_r <= 4'b1;
        awaddr_r <= data_sram_addr;
        awsize_r <= asize_data;
        awvalid_r <= 1'b1;
        wdata_r <= data_sram_wdata;
        wstrb_r <= data_sram_wstrb;
    end
    else if((w_cur_state[2] | w_cur_state[3]) & awvalid & awready) begin
        awvalid_r <= 1'b0;
    end
    else if(w_cur_state[4] & bvalid & bready) begin
        awid_r <= 4'b0;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0; 
    end
end

/******************** WRITE COMBINATIONAL LOGIC ********************/

assign awid = awid_r;
assign awaddr = awaddr_r;
assign awlen = 8'b0;
assign awsize = awsize_r;
assign awburst = 2'b01;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign awvalid = awvalid_r;
assign wid = 4'b1;
assign wdata = wdata_r;
assign wstrb = wstrb_r;
//assign wlast = 1'b1;
assign wlast = wvalid;
assign wvalid = (w_cur_state == WRITE_DATA_OK);
assign bready = (w_cur_state == WRITE_DONE);

/******************** CPU INTERFACE ********************/

//assign cpu_inst_read_req = inst_sram_req & ~inst_sram_wr;       //wr读请求0，写请求1
assign cpu_inst_read_req = icache_rd_req;
//assign cpu_inst_write_req = inst_sram_req & inst_sram_wr;
//assign cpu_inst_write_req = icache_wr_req;
assign cpu_inst_write_req = 1'b0;
assign cpu_data_read_req = data_sram_req & ~data_sram_wr;
assign cpu_data_write_req = data_sram_req & data_sram_wr;
assign icache_rd_rdy = (r_cur_state[1] & arvalid & arready & (arid_r == 4'b0)) |
                        (w_cur_state[1] & awvalid & awready & (awid_r == 4'b0));
assign icache_ret_valid = (r_cur_state[3] & rready & rvalid & (arid_r == 4'b0)) |
                        (w_cur_state[4] & bready & bvalid & (awid_r == 4'b0));
assign icache_ret_data = rdata;
assign icache_ret_last = r_cur_state[3] && (rd_count == arlen_r);
assign data_sram_addr_ok = (r_cur_state[2] & arvalid & arready & (arid_r == 4'b1)) |
                        (w_cur_state[2] & awvalid & awready & (awid_r == 4'b1));
assign data_sram_data_ok = (r_cur_state[3] & rready & rvalid & (arid_r == 4'b1)) |
                        (w_cur_state[4] & bready & bvalid & (awid_r == 4'b1));
assign data_sram_rdata = rdata;

endmodule