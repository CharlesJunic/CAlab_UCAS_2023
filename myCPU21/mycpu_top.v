module mycpu_top(
    input         aclk,         //axi时钟
    input         aresetn,      //axi复位，低电平有效
    output [ 3:0] arid,         //读请求的id号，取指0，取数1
    output [31:0] araddr,       //读请求地址
    output [ 7:0] arlen,        //读请求传输长度，固定为0
    output [ 2:0] arsize,       //读请求传输大小
    output [ 1:0] arburst,      //读请求传输类型
    output [ 1:0] arlock,       //读请求原子锁
    output [ 3:0] arcache,      //读请求cache属性
    output [ 2:0] arprot,       //读请求保护属性
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
    output        bready,       //写请求握手信号，master端准备好接受写响应
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_we,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

/******************** DECLARATION ********************/
    wire        cpu_inst_req;
    wire        cpu_inst_wr;
    wire [ 1:0] cpu_inst_size;
    wire [31:0] cpu_inst_addr;
    wire [ 3:0] cpu_inst_wstrb;
    wire [31:0] cpu_inst_wdata;
    wire        cpu_inst_addr_ok;
    wire        cpu_inst_data_ok;
    wire [31:0] cpu_inst_rdata;
    wire        cpu_data_req;
    wire        cpu_data_wr;
    wire [ 1:0] cpu_data_size;
    wire [31:0] cpu_data_addr;
    wire [ 3:0] cpu_data_wstrb;
    wire [31:0] cpu_data_wdata;
    wire        cpu_data_addr_ok;
    wire        cpu_data_data_ok;
    wire [31:0] cpu_data_rdata;
    // for icache
    wire         icache_addr_ok;
    wire         icache_data_ok;
    wire [ 31:0] icache_rdata;
    wire         icache_rd_req;
    wire [  2:0] icache_rd_type;
    wire [ 31:0] icache_rd_addr;
    wire         icache_rd_rdy;
    wire         icache_ret_valid;
    wire         icache_ret_last;
    wire [ 31:0] icache_ret_data;
    wire         icache_wr_req;
    wire [  2:0] icache_wr_type;
    wire [ 31:0] icache_wr_addr;
    wire [  3:0] icache_wr_strb;
    wire [127:0] icache_wr_data;
    wire         icache_wr_rdy;
    wire [ 31:0] inst_addr_vrtl;
    wire         inst_mem_type;
/******************** CPU CORE ********************/
    mycpu_core u_mycpu_core(
        .clk(aclk),
        .resetn(aresetn),
        .inst_sram_req(cpu_inst_req),
        .inst_sram_wr(cpu_inst_wr),
        .inst_sram_size(cpu_inst_size),
        .inst_sram_addr(cpu_inst_addr),
        .inst_sram_wstrb(cpu_inst_wstrb),
        .inst_sram_wdata(cpu_inst_wdata),
        .inst_sram_addr_ok(icache_addr_ok), //icache
        .inst_sram_data_ok(icache_data_ok), //icache
        .inst_sram_rdata(icache_rdata), //icache
        .data_sram_req(cpu_data_req),
        .data_sram_wr(cpu_data_wr),
        .data_sram_size(cpu_data_size),
        .data_sram_addr(cpu_data_addr),
        .data_sram_wstrb(cpu_data_wstrb),
        .data_sram_wdata(cpu_data_wdata),
        .data_sram_addr_ok(cpu_data_addr_ok),
        .data_sram_data_ok(cpu_data_data_ok),
        .data_sram_rdata(cpu_data_rdata),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),
        .inst_addr_vrtl(inst_addr_vrtl), //icache
        .inst_mem_type(inst_mem_type)   //icache
    );

/******************** AXI BRIDGE ********************/
    axi_bridge u_axi_bridge(
        .clk(aclk),
        .resetn(aresetn),
        /*.inst_sram_req(cpu_inst_req),
        .inst_sram_wr(cpu_inst_wr),
        .inst_sram_size(cpu_inst_size),
        .inst_sram_addr(cpu_inst_addr),*/
        .inst_sram_wstrb(cpu_inst_wstrb),
        .inst_sram_wdata(cpu_inst_wdata),
        /*.inst_sram_addr_ok(cpu_inst_addr_ok),
        .inst_sram_data_ok(cpu_inst_data_ok),
        .inst_sram_rdata(cpu_inst_rdata),*/
        .data_sram_req(cpu_data_req),
        .data_sram_wr(cpu_data_wr),
        .data_sram_size(cpu_data_size),
        .data_sram_addr(cpu_data_addr),
        .data_sram_wstrb(cpu_data_wstrb),
        .data_sram_wdata(cpu_data_wdata),
        .data_sram_addr_ok(cpu_data_addr_ok),
        .data_sram_data_ok(cpu_data_data_ok),
        .data_sram_rdata(cpu_data_rdata),
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),
        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),
        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),
        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        // for icache
        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),
        .icache_rd_rdy(icache_rd_rdy),
        .icache_ret_valid(icache_ret_valid),
        .icache_ret_last(icache_ret_last),
        .icache_ret_data(icache_ret_data)
    );

    cache icache(
        .clk    (aclk),
        .resetn (aresetn),

        .valid  (cpu_inst_req),
        .op     (cpu_inst_wr),
        .inst_mem_type(inst_mem_type),
        .index  (cpu_inst_addr[11:4]),
        .tag    (cpu_inst_addr[31:12]),
        .offset (cpu_inst_addr[3:0]),
        .wstrb  (cpu_inst_wstrb),
        .wdata  (cpu_inst_wdata),
        .addr_ok(icache_addr_ok),
        .data_ok(icache_data_ok),
        .rdata  (icache_rdata),

        .rd_req (icache_rd_req),
        .rd_type(icache_rd_type),
        .rd_addr(icache_rd_addr),
        .rd_rdy   (icache_rd_rdy),
        .ret_valid(icache_ret_valid),
        .ret_last (icache_ret_last),
        .ret_data (icache_ret_data),

        .wr_req (icache_wr_req),
        .wr_type(icache_wr_type),
        .wr_addr(icache_wr_addr ),
        .wr_wstrb(icache_wr_strb),
        .wr_data(icache_wr_data),
        .wr_rdy (1'b1)
    );

endmodule