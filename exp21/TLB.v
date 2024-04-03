module tlb
#(
    parameter TLBNUM = 16
)
(
    input  wire         clk,

// search port 0 (for fetch)
    input  wire [ 18:0] s0_vppn,                // vppn    : 来自访存虚地址的第 31 ~ 13 位
    input  wire         s0_va_bit12,            // va_bit12: 来自访存虚地址的第 12      位
    input  wire [  9:0] s0_asid,                // asid    : 来自 CAR.ASID 的 ASID 域
    output wire         s0_found,               // found   : 用于判定是否产生 TLB 重填异常、页无效异常、页特权等级不合规异常与页修改异常
    output wire [$clog2(TLBNUM)-1:0] s0_index,  // index   : 用于记录命中在第几项，其信息用于填入到 CSR.TLBIDX 中
    output wire [ 19:0] s0_ppn,                 // ppn     : 用于产生最终的物理地址
    output wire [  5:0] s0_ps,                  // ps      : 用于产生最终的物理地址
    output wire [  1:0] s0_plv,                 // plv     : 用于判定是否产生页特权等级不合规异常
    output wire [  1:0] s0_mat,                 // mat     : 用于选择 TLB 存储访问类型
    output wire         s0_d,                   // d       : 用于判定是否产生页修改异常
    output wire         s0_v,                   // v       : 用于判定是否产生页无效异常、页修改异常

// search port 1 (for load/store)
    input  wire [ 18:0] s1_vppn,
    input  wire         s1_va_bit12,
    input  wire [  9:0] s1_asid,
    output wire         s1_found,
    output wire [$clog2(TLBNUM) - 1:0] s1_index,
    output wire [ 19:0] s1_ppn,
    output wire [  5:0] s1_ps,
    output wire [  1:0] s1_plv,
    output wire [  1:0] s1_mat,
    output wire         s1_d,
    output wire         s1_v,

// invtlb opcode
    input  wire         invtlb_valid,           // valid: INVTLB 指令: 用于无效 TLB 中的内容，以维持 TLB 与内存之间页表数据的一致性
    input  wire [  4:0] invtlb_op,              // op   : INVTLB 的操作码，0x0~0x6 对应 7 种操作，其它将触发保留指令例外

// write port
    input  wire         we,                     //w(rite) e(nable)
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  wire         w_e,
    input  wire [ 18:0] w_vppn,
    input  wire [  5:0] w_ps,
    input  wire [  9:0] w_asid,
    input  wire         w_g,
    input  wire [ 19:0] w_ppn0,
    input  wire [  1:0] w_plv0,
    input  wire [  1:0] w_mat0,
    input  wire         w_d0,
    input  wire         w_v0,
    input  wire [ 19:0] w_ppn1,
    input  wire [  1:0] w_plv1,
    input  wire [  1:0] w_mat1,
    input  wire         w_d1,
    input  wire         w_v1,

// read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire         r_e,
    output wire [ 18:0] r_vppn,
    output wire [  5:0] r_ps,
    output wire [  9:0] r_asid,
    output wire         r_g,
    output wire [ 19:0] r_ppn0,
    output wire [  1:0] r_plv0,
    output wire [  1:0] r_mat0,
    output wire         r_d0,
    output wire         r_v0,
    output wire [ 19:0] r_ppn1,
    output wire [  1:0] r_plv1,
    output wire [  1:0] r_mat1,
    output wire         r_d1,
    output wire         r_v1
);

reg  [TLBNUM - 1:0] tlb_e;                      // e    : 存在位，为 1 表示所在 TLB 表项非空
reg  [TLBNUM - 1:0] tlb_ps4MB;                  // ps4MB: 页大小标志，为 1 表示大小为 4MB，为 0 表示为 4KB
reg  [        18:0] tlb_vppn [TLBNUM - 1:0];    // vppn : 虚双页号
reg  [         9:0] tlb_asid [TLBNUM - 1:0];    // asid : 地址空间标识
reg                 tlb_g    [TLBNUM - 1:0];    // g    : 全局标志位，该位为 1 时，查找时不进行 ASID 一致性检查
reg  [        19:0] tlb_ppn0 [TLBNUM - 1:0];    // ppn  : 物理页号
reg  [         1:0] tlb_plv0 [TLBNUM - 1:0];    // plv  : 特权等级
reg  [         1:0] tlb_mat0 [TLBNUM - 1:0];    // mat  : 存储访问类型，0x00 表示强序非缓存，0x01 表示一致可缓存，0x10/0x11 为保留
reg                 tlb_d0   [TLBNUM - 1:0];    // d    : 脏位，为 1 表示该页表项所对应的地址范围内已有脏数据
reg                 tlb_v0   [TLBNUM - 1:0];    // v    : 有效位，为 1 表明该页表项是有效的且被访问过的
reg  [        19:0] tlb_ppn1 [TLBNUM - 1:0];
reg  [         1:0] tlb_plv1 [TLBNUM - 1:0];
reg  [         1:0] tlb_mat1 [TLBNUM - 1:0];
reg                 tlb_d1   [TLBNUM - 1:0];
reg                 tlb_v1   [TLBNUM - 1:0];

wire                s0_sel;                     // sel  : 用于根据页大小选择访存虚地址的第 23 位或第 13 位
wire                s1_sel;

wire [TLBNUM - 1:0] match0;
wire [TLBNUM - 1:0] match1;

wire [TLBNUM - 1:0] invtlb_mask[31:0];          // mask : 匹配信号，与对应 invtlb_op 进行匹配
wire [TLBNUM - 1:0] cond1;                      // cond1: 子情况，G 域是否等于 0
wire [TLBNUM - 1:0] cond2;                      // cond2: 子情况，G 域是否等于 1
wire [TLBNUM - 1:0] cond3;                      // cond3: 子情况，s1_asid 是否等于 ASID 域
wire [TLBNUM - 1:0] cond4;                      // cond4: 子情况，s1_vppn 是否匹配 VPPN 和 PS 域

assign match0[ 0] = (s0_vppn[18:9] == tlb_vppn[ 0][18:9])
                  & (tlb_ps4MB[ 0] || s0_vppn[8:0] == tlb_vppn[ 0][8:0])
                  & ((s0_asid == tlb_asid[ 0]) || tlb_g[ 0]) & tlb_e[ 0];
assign match0[ 1] = (s0_vppn[18:9] == tlb_vppn[ 1][18:9])
                  & (tlb_ps4MB[ 1] || s0_vppn[8:0] == tlb_vppn[ 1][8:0])
                  & ((s0_asid == tlb_asid[ 1]) || tlb_g[ 1]) & tlb_e[ 1];
assign match0[ 2] = (s0_vppn[18:9] == tlb_vppn[ 2][18:9])
                  & (tlb_ps4MB[ 2] || s0_vppn[8:0] == tlb_vppn[ 2][8:0])
                  & ((s0_asid == tlb_asid[ 2]) || tlb_g[ 2]) & tlb_e[ 2];
assign match0[ 3] = (s0_vppn[18:9] == tlb_vppn[ 3][18:9])
                  & (tlb_ps4MB[ 3] || s0_vppn[8:0] == tlb_vppn[ 3][8:0])
                  & ((s0_asid == tlb_asid[ 3]) || tlb_g[ 3]) & tlb_e[ 3];
assign match0[ 4] = (s0_vppn[18:9] == tlb_vppn[ 4][18:9])
                  & (tlb_ps4MB[ 4] || s0_vppn[8:0] == tlb_vppn[ 4][8:0])
                  & ((s0_asid == tlb_asid[ 4]) || tlb_g[ 4]) & tlb_e[ 4];
assign match0[ 5] = (s0_vppn[18:9] == tlb_vppn[ 5][18:9])
                  & (tlb_ps4MB[ 5] || s0_vppn[8:0] == tlb_vppn[ 5][8:0])
                  & ((s0_asid == tlb_asid[ 5]) || tlb_g[ 5]) & tlb_e[ 5];
assign match0[ 6] = (s0_vppn[18:9] == tlb_vppn[ 6][18:9])
                  & (tlb_ps4MB[ 6] || s0_vppn[8:0] == tlb_vppn[ 6][8:0])
                  & ((s0_asid == tlb_asid[ 6]) || tlb_g[ 6]) & tlb_e[ 6];
assign match0[ 7] = (s0_vppn[18:9] == tlb_vppn[ 7][18:9])
                  & (tlb_ps4MB[ 7] || s0_vppn[8:0] == tlb_vppn[ 7][8:0])
                  & ((s0_asid == tlb_asid[ 7]) || tlb_g[ 7]) & tlb_e[ 7];
assign match0[ 8] = (s0_vppn[18:9] == tlb_vppn[ 8][18:9])
                  & (tlb_ps4MB[ 8] || s0_vppn[8:0] == tlb_vppn[ 8][8:0])
                  & ((s0_asid == tlb_asid[ 8]) || tlb_g[ 8]) & tlb_e[ 8];
assign match0[ 9] = (s0_vppn[18:9] == tlb_vppn[ 9][18:9])
                  & (tlb_ps4MB[ 9] || s0_vppn[8:0] == tlb_vppn[ 9][8:0])
                  & ((s0_asid == tlb_asid[ 9]) || tlb_g[ 9]) & tlb_e[ 9];
assign match0[10] = (s0_vppn[18:9] == tlb_vppn[10][18:9])
                  & (tlb_ps4MB[10] || s0_vppn[8:0] == tlb_vppn[10][8:0])
                  & ((s0_asid == tlb_asid[10]) || tlb_g[10]) & tlb_e[10];
assign match0[11] = (s0_vppn[18:9] == tlb_vppn[11][18:9])
                  & (tlb_ps4MB[11] || s0_vppn[8:0] == tlb_vppn[11][8:0])
                  & ((s0_asid == tlb_asid[11]) || tlb_g[11]) & tlb_e[11];
assign match0[12] = (s0_vppn[18:9] == tlb_vppn[12][18:9])
                  & (tlb_ps4MB[12] || s0_vppn[8:0] == tlb_vppn[12][8:0])
                  & ((s0_asid == tlb_asid[12]) || tlb_g[12]) & tlb_e[12];
assign match0[13] = (s0_vppn[18:9] == tlb_vppn[13][18:9])
                  & (tlb_ps4MB[13] || s0_vppn[8:0] == tlb_vppn[13][8:0])
                  & ((s0_asid == tlb_asid[13]) || tlb_g[13]) & tlb_e[13];
assign match0[14] = (s0_vppn[18:9] == tlb_vppn[14][18:9])
                  & (tlb_ps4MB[14] || s0_vppn[8:0] == tlb_vppn[14][8:0])
                  & ((s0_asid == tlb_asid[14]) || tlb_g[14]) & tlb_e[14];
assign match0[15] = (s0_vppn[18:9] == tlb_vppn[15][18:9])
                  & (tlb_ps4MB[15] || s0_vppn[8:0] == tlb_vppn[15][8:0])
                  & ((s0_asid == tlb_asid[15]) || tlb_g[15]) & tlb_e[15];

assign match1[ 0] = (cond2[ 0] | cond3[ 0]) & cond4[ 0] & tlb_e[ 0];
assign match1[ 1] = (cond2[ 1] | cond3[ 1]) & cond4[ 1] & tlb_e[ 1];
assign match1[ 2] = (cond2[ 2] | cond3[ 2]) & cond4[ 2] & tlb_e[ 2];
assign match1[ 3] = (cond2[ 3] | cond3[ 3]) & cond4[ 3] & tlb_e[ 3];
assign match1[ 4] = (cond2[ 4] | cond3[ 4]) & cond4[ 4] & tlb_e[ 4];
assign match1[ 5] = (cond2[ 5] | cond3[ 5]) & cond4[ 5] & tlb_e[ 5];
assign match1[ 6] = (cond2[ 6] | cond3[ 6]) & cond4[ 6] & tlb_e[ 6];
assign match1[ 7] = (cond2[ 7] | cond3[ 7]) & cond4[ 7] & tlb_e[ 7];
assign match1[ 8] = (cond2[ 8] | cond3[ 8]) & cond4[ 8] & tlb_e[ 8];
assign match1[ 9] = (cond2[ 9] | cond3[ 9]) & cond4[ 9] & tlb_e[ 9];
assign match1[10] = (cond2[10] | cond3[10]) & cond4[10] & tlb_e[10];
assign match1[11] = (cond2[11] | cond3[11]) & cond4[11] & tlb_e[11];
assign match1[12] = (cond2[12] | cond3[12]) & cond4[12] & tlb_e[12];
assign match1[13] = (cond2[13] | cond3[13]) & cond4[13] & tlb_e[13];
assign match1[14] = (cond2[14] | cond3[14]) & cond4[14] & tlb_e[14];
assign match1[15] = (cond2[15] | cond3[15]) & cond4[15] & tlb_e[15];

//search port 0 (for fetch)
    assign s0_found    = |match0[TLBNUM - 1:0];
    assign s0_index[0] = match0[ 1] | match0[ 3] | match0[ 5] | match0[ 7] 
                       | match0[ 9] | match0[11] | match0[13] | match0[15];
    assign s0_index[1] = match0[ 2] | match0[ 3] | match0[ 6] | match0[ 7] 
                       | match0[10] | match0[11] | match0[14] | match0[15];
    assign s0_index[2] = match0[ 4] | match0[ 5] | match0[ 6] | match0[ 7]
                       | match0[12] | match0[13] | match0[14] | match0[15];
    assign s0_index[3] = match0[ 8] | match0[ 9] | match0[10] | match0[11]
                       | match0[12] | match0[13] | match0[14] | match0[15];
    assign s0_sel = tlb_ps4MB[s0_index] ? s0_vppn[8] : s0_va_bit12;
    assign s0_ppn = s0_sel ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_ps  = tlb_ps4MB[s0_index] ? 6'd21 : 6'd12;
    assign s0_plv = s0_sel ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat = s0_sel ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d   = s0_sel ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
    assign s0_v   = s0_sel ? tlb_v1  [s0_index] : tlb_v0  [s0_index];

//search port 1 (for fetch)
    assign s1_found    = |match1[TLBNUM - 1:0];
    assign s1_index[0] = match1[ 1] | match1[ 3] | match1[ 5] | match1[ 7] 
                       | match1[ 9] | match1[11] | match1[13] | match1[15];
    assign s1_index[1] = match1[ 2] | match1[ 3] | match1[ 6] | match1[ 7]
                       | match1[10] | match1[11] | match1[14] | match1[15];
    assign s1_index[2] = match1[ 4] | match1[ 5] | match1[ 6] | match1[ 7]
                       | match1[12] | match1[13] | match1[14] | match1[15];
    assign s1_index[3] = match1[ 8] | match1[ 9] | match1[10] | match1[11]
                       | match1[12] | match1[13] | match1[14] | match1[15];
    assign s1_sel = tlb_ps4MB[s1_index] ? s1_vppn[8] : s1_va_bit12;
    assign s1_ppn = s1_sel ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_ps  = tlb_ps4MB[s1_index] ? 6'd21 : 6'd12;
    assign s1_plv = s1_sel ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat = s1_sel ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d   = s1_sel ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
    assign s1_v   = s1_sel ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

//write port
    always @(posedge clk) begin
       if (we) begin
            tlb_e   [w_index] <= w_e;
            tlb_vppn[w_index] <= w_vppn;
            tlb_asid[w_index] <= w_asid;
            tlb_g   [w_index] <= w_g;
            tlb_ppn0[w_index] <= w_ppn0;
            tlb_plv0[w_index] <= w_plv0;
            tlb_mat0[w_index] <= w_mat0;
            tlb_d0  [w_index] <= w_d0;
            tlb_v0  [w_index] <= w_v0;
            tlb_ppn1[w_index] <= w_ppn1;
            tlb_plv1[w_index] <= w_plv1;
            tlb_mat1[w_index] <= w_mat1;
            tlb_d1  [w_index] <= w_d1;
            tlb_v1  [w_index] <= w_v1;
        end
        
        if (we && (w_ps == 6'd21))
            tlb_ps4MB[w_index] <= 1'b1;
        else if (we && (w_ps == 6'd12))
            tlb_ps4MB[w_index] <= 1'b0;

        if (invtlb_valid)
            tlb_e <= ~invtlb_mask[invtlb_op] & tlb_e;
    end

//read port
    assign r_e    = tlb_e    [r_index];
    assign r_vppn = tlb_vppn [r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
    assign r_asid = tlb_asid [r_index];
    assign r_g    = tlb_g    [r_index];
    assign r_ppn0 = tlb_ppn0 [r_index];
    assign r_plv0 = tlb_plv0 [r_index];
    assign r_mat0 = tlb_mat0 [r_index];
    assign r_d0   = tlb_d0   [r_index];
    assign r_v0   = tlb_v0   [r_index]; 
    assign r_ppn1 = tlb_ppn1 [r_index];
    assign r_plv1 = tlb_plv1 [r_index];
    assign r_mat1 = tlb_mat1 [r_index];
    assign r_d1   = tlb_d1   [r_index];
    assign r_v1   = tlb_v1   [r_index];

//INVTLB mask
    assign invtlb_mask[0] = 16'hffff;               // cond1 || cond2
    assign invtlb_mask[1] = 16'hffff;               // cond1 || cond2
    assign invtlb_mask[2] = {                       // cond2
        cond2[15], cond2[14], cond2[13], cond2[12],
        cond2[11], cond2[10], cond2[ 9], cond2[ 8],
        cond2[ 7], cond2[ 6], cond2[ 5], cond2[ 4],
        cond2[ 3], cond2[ 2], cond2[ 1], cond2[ 0]
    };
    assign invtlb_mask[3] = {                       // cond1
        cond1[15], cond1[14], cond1[13], cond1[12],
        cond1[11], cond1[10], cond1[ 9], cond1[ 8],
        cond1[ 7], cond1[ 6], cond1[ 5], cond1[ 4],
        cond1[ 3], cond1[ 2], cond1[ 1], cond1[ 0]
    };
    assign invtlb_mask[4] = {                       // cond1 && cond3
        cond1[15] & cond3[15], cond1[14] & cond3[14], cond1[13] & cond3[13], cond1[12] & cond3[12],
        cond1[11] & cond3[11], cond1[10] & cond3[10], cond1[ 9] & cond3[ 9], cond1[ 8] & cond3[ 8],
        cond1[ 7] & cond3[ 7], cond1[ 6] & cond3[ 6], cond1[ 5] & cond3[ 5], cond1[ 4] & cond3[ 4],
        cond1[ 3] & cond3[ 3], cond1[ 2] & cond3[ 2], cond1[ 1] & cond3[ 1], cond1[ 0] & cond3[ 0]
    };
    assign invtlb_mask[5] = {                       // cond1 && cond3 && cond4
        cond1[15] & cond3[15] & cond4[15], cond1[14] & cond3[14] & cond4[14],
        cond1[13] & cond3[13] & cond4[13], cond1[12] & cond3[12] & cond4[12],
        cond1[11] & cond3[11] & cond4[11], cond1[10] & cond3[10] & cond4[10],
        cond1[ 9] & cond3[ 9] & cond4[ 9], cond1[ 8] & cond3[ 8] & cond4[ 8],
        cond1[ 7] & cond3[ 7] & cond4[ 7], cond1[ 6] & cond3[ 6] & cond4[ 6],
        cond1[ 5] & cond3[ 5] & cond4[ 5], cond1[ 4] & cond3[ 4] & cond4[ 4],
        cond1[ 3] & cond3[ 3] & cond4[ 3], cond1[ 2] & cond3[ 2] & cond4[ 2],
        cond1[ 1] & cond3[ 1] & cond4[ 1], cond1[ 0] & cond3[ 0] & cond4[ 0]
    };
    assign invtlb_mask[6] = {                       // (cond2 || cond3) && cond4
        match1[15], match1[14], match1[13], match1[12],
        match1[11], match1[10], match1[ 9], match1[ 8],
        match1[ 7], match1[ 6], match1[ 5], match1[ 4],
        match1[ 3], match1[ 2], match1[ 1], match1[ 0]
    };
    genvar i;
    generate for (i = 7; i < 32; i = i + 1)
    begin
        assign invtlb_mask[i] = 16'h0000;           // 16'h0000
    end
    endgenerate

//INVTLB conditions
    // cond1
        assign cond1[TLBNUM - 1:0] = {
            ~tlb_g[15], ~tlb_g[14], ~tlb_g[13], ~tlb_g[12],
            ~tlb_g[11], ~tlb_g[10], ~tlb_g[ 9], ~tlb_g[ 8],
            ~tlb_g[ 7], ~tlb_g[ 6], ~tlb_g[ 5], ~tlb_g[ 4],
            ~tlb_g[ 3], ~tlb_g[ 2], ~tlb_g[ 1], ~tlb_g[ 0]
        };
    // cond2
        assign cond2[TLBNUM - 1:0] = {
             tlb_g[15],  tlb_g[14],  tlb_g[13],  tlb_g[12],
             tlb_g[11],  tlb_g[10],  tlb_g[ 9],  tlb_g[ 8],
             tlb_g[ 7],  tlb_g[ 6],  tlb_g[ 5],  tlb_g[ 4],
             tlb_g[ 3],  tlb_g[ 2],  tlb_g[ 1],  tlb_g[ 0]
        };
    // cond3
        assign cond3[ 0] = tlb_asid[ 0] == s1_asid;
        assign cond3[ 1] = tlb_asid[ 1] == s1_asid;
        assign cond3[ 2] = tlb_asid[ 2] == s1_asid;
        assign cond3[ 3] = tlb_asid[ 3] == s1_asid;
        assign cond3[ 4] = tlb_asid[ 4] == s1_asid;
        assign cond3[ 5] = tlb_asid[ 5] == s1_asid;
        assign cond3[ 6] = tlb_asid[ 6] == s1_asid;
        assign cond3[ 7] = tlb_asid[ 7] == s1_asid;
        assign cond3[ 8] = tlb_asid[ 8] == s1_asid;
        assign cond3[ 9] = tlb_asid[ 9] == s1_asid;
        assign cond3[10] = tlb_asid[10] == s1_asid;
        assign cond3[11] = tlb_asid[11] == s1_asid;
        assign cond3[12] = tlb_asid[12] == s1_asid;
        assign cond3[13] = tlb_asid[13] == s1_asid;
        assign cond3[14] = tlb_asid[14] == s1_asid;
        assign cond3[15] = tlb_asid[15] == s1_asid;
    // cond4
        assign cond4[ 0] = (s1_vppn[18:9] == tlb_vppn[ 0][18:9])
                         & (tlb_ps4MB[ 0] || s1_vppn[8:0] == tlb_vppn[ 0][8:0]);
        assign cond4[ 1] = (s1_vppn[18:9] == tlb_vppn[ 1][18:9])
                         & (tlb_ps4MB[ 1] || s1_vppn[8:0] == tlb_vppn[ 1][8:0]);
        assign cond4[ 2] = (s1_vppn[18:9] == tlb_vppn[ 2][18:9])
                         & (tlb_ps4MB[ 2] || s1_vppn[8:0] == tlb_vppn[ 2][8:0]);
        assign cond4[ 3] = (s1_vppn[18:9] == tlb_vppn[ 3][18:9])
                         & (tlb_ps4MB[ 3] || s1_vppn[8:0] == tlb_vppn[ 3][8:0]);
        assign cond4[ 4] = (s1_vppn[18:9] == tlb_vppn[ 4][18:9])
                         & (tlb_ps4MB[ 4] || s1_vppn[8:0] == tlb_vppn[ 4][8:0]);
        assign cond4[ 5] = (s1_vppn[18:9] == tlb_vppn[ 5][18:9])
                         & (tlb_ps4MB[ 5] || s1_vppn[8:0] == tlb_vppn[ 5][8:0]);
        assign cond4[ 6] = (s1_vppn[18:9] == tlb_vppn[ 6][18:9])
                         & (tlb_ps4MB[ 6] || s1_vppn[8:0] == tlb_vppn[ 6][8:0]);
        assign cond4[ 7] = (s1_vppn[18:9] == tlb_vppn[ 7][18:9])
                         & (tlb_ps4MB[ 7] || s1_vppn[8:0] == tlb_vppn[ 7][8:0]);
        assign cond4[ 8] = (s1_vppn[18:9] == tlb_vppn[ 8][18:9])
                         & (tlb_ps4MB[ 8] || s1_vppn[8:0] == tlb_vppn[ 8][8:0]);
        assign cond4[ 9] = (s1_vppn[18:9] == tlb_vppn[ 9][18:9])
                         & (tlb_ps4MB[ 9] || s1_vppn[8:0] == tlb_vppn[ 9][8:0]);
        assign cond4[10] = (s1_vppn[18:9] == tlb_vppn[10][18:9])
                         & (tlb_ps4MB[10] || s1_vppn[8:0] == tlb_vppn[10][8:0]);
        assign cond4[11] = (s1_vppn[18:9] == tlb_vppn[11][18:9])
                         & (tlb_ps4MB[11] || s1_vppn[8:0] == tlb_vppn[11][8:0]);
        assign cond4[12] = (s1_vppn[18:9] == tlb_vppn[12][18:9])
                         & (tlb_ps4MB[12] || s1_vppn[8:0] == tlb_vppn[12][8:0]);
        assign cond4[13] = (s1_vppn[18:9] == tlb_vppn[13][18:9])
                         & (tlb_ps4MB[13] || s1_vppn[8:0] == tlb_vppn[13][8:0]);
        assign cond4[14] = (s1_vppn[18:9] == tlb_vppn[14][18:9])
                         & (tlb_ps4MB[14] || s1_vppn[8:0] == tlb_vppn[14][8:0]);
        assign cond4[15] = (s1_vppn[18:9] == tlb_vppn[15][18:9])
                         & (tlb_ps4MB[15] || s1_vppn[8:0] == tlb_vppn[15][8:0]);

endmodule