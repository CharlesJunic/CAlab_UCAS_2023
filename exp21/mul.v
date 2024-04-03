module Booth_Wallace_Mux(
        input  wire        mul_clk,
        input  wire        reset,
        input  wire [ 2:0] mul_op,
        input  wire [31:0] X,
        input  wire [31:0] Y,
        output wire [31:0] result
);
    wire [  63:0]   X_extend;
    wire [  63:0]   multiplicand [15:0];
    wire [   2:0]   signal [15:0];
    wire [  63:0]   par_product [15:0];
    wire [  15:0]   par_product_t [63:0];
    wire [  15:0]   par_cout;
    wire [  13:0]   wt_cio [64:0];
    wire [  63:0]   wt_c;
    wire [  63:0]   wt_result;
    wire [  63:0]   mul_result;
    
    assign   X_extend   = mul_op[2] ? {32'b0, X} : {{32{X[31]}}, X};
    assign   wt_cio[0]  = 14'b0;
    assign   mul_result = {wt_c[62:0], 1'b0} + wt_result[63:0] + 
                            {(mul_op[2] & Y[31]) ? { X, 32'b0 } : 64'b0};
    assign   result     = mul_op[0] ? mul_result[31:0] : mul_result[63:32];

    genvar i, j, p, q;
    generate
        for (p = 0; p < 64; p = p + 1) begin
            for (q = 0; q < 16; q = q + 1) begin
                assign par_product_t[p][q] = par_product[q][p];
            end
        end
        for (i = 0; i < 16; i = i + 1) begin
            assign multiplicand[i] = (i == 0) ? X_extend : multiplicand[i - 1] << 2;
            assign signal[i]       = {Y[i + i + 1], Y[i + i], (i == 0) ? 1'b0 : Y[i + i - 1]};
            partial_product_generator generator(
                .X           (multiplicand[i]),
                .Y           (signal[i]),
                .par_product (par_product[i]),
                .cout        (par_cout[i])
            );
        end
        for (j = 0; j < 64; j = j + 1) begin
            wallace_tree u_wt(
                .mul_clk(mul_clk),
                .reset  (reset),
                .num    (par_product_t[j]),
                .cin    (wt_cio[j]),
                .cout   (wt_cio[j + 1]),
                .c      (wt_c[j]),
                .result (wt_result[j])
            );
        end
    endgenerate
endmodule

module partial_product_generator (
        input  wire [ 63:0] X,
        input  wire [  2:0] Y,
        output wire [ 63:0] par_product,
        output wire         cout
);
    wire        add_once;
    wire        add_twice;
    wire        del_once;
    wire        del_twice;
    wire        add_del_zero;

    wire [64:0] add_once_val;
    wire [64:0] add_twice_val;
    wire [64:0] del_once_val;
    wire [64:0] del_twice_val;

    assign  add_once      = ~Y[2] & (Y[1] ^ Y[0]);
    assign  add_twice     = ~Y[2] & Y[1] & Y[0];
    assign  del_once      = Y[2] & (Y[1] ^ Y[0]);
    assign  del_twice     = Y[2] & ~Y[1] & ~Y[0];
    assign  add_del_zero  = (~Y[2] & ~Y[1] & ~Y[0]) | (Y[2] & Y[1] & Y[0]);
    
    assign  add_once_val  = {1'b0, X};
    assign  add_twice_val = {1'b0, add_once_val[63], add_once_val[61:0], 1'b0};
    assign  del_once_val  = {1'b1, (~X + 1)};
    assign  del_twice_val = {1'b1, del_once_val[63], del_once_val[61:0], 1'b0};

    assign  {cout, par_product} = ({65{add_once}}     & add_once_val )
                                | ({65{add_twice}}    & add_twice_val)
                                | ({65{del_once}}     & del_once_val )
                                | ({65{del_twice}}    & del_twice_val)
                                | ({65{add_del_zero}} & 65'b0        );
endmodule

module wallace_tree (
        input  wire          mul_clk,
        input  wire          reset,
        input  wire [15:0]   num,
        input  wire [13:0]   cin,
        output wire [13:0]   cout,
        output wire          result,
        output wire          c
);
    wire    [  14:0]    A;
    wire    [  14:0]    B;
    wire    [  14:0]    adder_cin;
    wire    [  14:0]    adder_result;
    wire    [  10:0]    level1;
    wire    [   5:0]    level2;
    wire    [   5:0]    level3;
    wire    [   2:0]    level4;
    wire    [   2:0]    level5;
    reg     [  15:0]    num_to_add;
    
    always@(posedge mul_clk) begin
        if (reset) begin
            num_to_add <= 11'b0;
        end
        else begin
            num_to_add <= num;
        end
    end

    assign {A[4:0], B[4:0], adder_cin[4:0]} = num_to_add[14:0];
    assign level1 = {adder_result[4:0], num_to_add[15], cin[4:0]};

    assign {A[8:5], B[8:5], adder_cin[8:5]} = {level1[10:0], 1'b0};
    assign level2 = {adder_result[8:5], cin[6:5]};

    assign {A[10:9], B[10:9], adder_cin[10:9]} = level2;
    assign level3 = {adder_result[10:9], cin[10:7]};
    
    assign {A[12:11], B[12:11], adder_cin[12:11]} = level3;
    assign level4 = {adder_result[12:11], cin[11]};
    
    assign {A[13], B[13], adder_cin[13]} = level4;
    assign level5 = {adder_result[13], cin[13:12]};
    
    assign {A[14], B[14], adder_cin[14]} = level5;
    assign result = adder_result[14];
    
    genvar i;
    generate
        for (i = 0; i < 14; i = i + 1) begin
            adder add(
                .A(A[i]),
                .B(B[i]),
                .cin(adder_cin[i]),
                .cout(cout[i]),
                .result(adder_result[i])
            );
        end
    endgenerate
    adder add(
        .A(A[14]),
        .B(B[14]),
        .cin(adder_cin[14]),
        .cout(c),
        .result(adder_result[14])
    );
endmodule
    
module adder(
        input  wire     A,
        input  wire     B,
        output wire     result,
        input  wire     cin,
        output wire     cout
);
    assign result   = ~(~(A & ~B & ~cin) & ~(~A & B & ~cin) & ~(~A & ~B & cin) & ~(A & B & cin));
    assign cout     = (A & B) | (A & cin) | (B & cin);
endmodule
