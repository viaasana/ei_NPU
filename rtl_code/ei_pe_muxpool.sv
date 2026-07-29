`timescale 1ns/1ps

module ei_pe_muxpool #(
    parameter int LATENCY_MUL = 4,
    parameter int LAT_TREE    = 16,
    parameter int LAT_TOTAL   = LATENCY_MUL + LAT_TREE
)(
    input  logic        sys_clk,
    input  logic        rst,
    input  logic        en,
    input  logic        valid_in,

    // mode:
    // 0x = conv
    // 10 = avg pool
    // 11 = max pool
    input  logic [1:0] pool_mode,

    // conv inputs
    input  logic [15:0] x0,x1,x2,x3,x4,x5,x6,x7,x8,
    input  logic [15:0] w0,w1,w2,w3,w4,w5,w6,w7,w8,

    // pool inputs
    input  logic [15:0] pool0,pool1,pool2,pool3,pool4,pool5,pool6,pool7,pool8,

    // average pool constant: 1/4 or 1/9 in FP16
    input  logic [15:0] const_pool,

    output logic [15:0] data_out,
    output logic        valid_out
);

    localparam int LAT_MAXPOOL  = 5;
    localparam int LAT_MAX_ALIGN = LAT_TOTAL - LAT_MAXPOOL;

    // -----------------------------
    // 1) Multipliers for conv path
    // -----------------------------
    logic [15:0] p0,p1,p2,p3,p4,p5,p6,p7,p8;
    logic [15:0] sum_out;
    logic [15:0] pool_output;

    logic [15:0] max_out_raw;
    logic [15:0] max_out_aligned;

    ei_multiplier_fp16 mul0 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x0), .b_in(w0), .c_out(p0));
    ei_multiplier_fp16 mul1 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x1), .b_in(w1), .c_out(p1));
    ei_multiplier_fp16 mul2 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x2), .b_in(w2), .c_out(p2));
    ei_multiplier_fp16 mul3 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x3), .b_in(w3), .c_out(p3));
    ei_multiplier_fp16 mul4 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x4), .b_in(w4), .c_out(p4));
    ei_multiplier_fp16 mul5 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x5), .b_in(w5), .c_out(p5));
    ei_multiplier_fp16 mul6 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x6), .b_in(w6), .c_out(p6));
    ei_multiplier_fp16 mul7 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x7), .b_in(w7), .c_out(p7));
    ei_multiplier_fp16 mul8 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x8), .b_in(w8), .c_out(p8));

    // -----------------------------
    // 2) Select tree input
    //    pool_mode[1] = 0 -> conv products p0..p8
    //    pool_mode[1] = 1 -> pool inputs pool0..pool8
    // -----------------------------
    logic [15:0] t0,t1,t2,t3,t4,t5,t6,t7,t8;

    ei_muxN #(.WIDTH(16)) mux0 (.d0(p0), .d1(pool0), .s(pool_mode[1]), .y(t0));
    ei_muxN #(.WIDTH(16)) mux1 (.d0(p1), .d1(pool1), .s(pool_mode[1]), .y(t1));
    ei_muxN #(.WIDTH(16)) mux2 (.d0(p2), .d1(pool2), .s(pool_mode[1]), .y(t2));
    ei_muxN #(.WIDTH(16)) mux3 (.d0(p3), .d1(pool3), .s(pool_mode[1]), .y(t3));
    ei_muxN #(.WIDTH(16)) mux4 (.d0(p4), .d1(pool4), .s(pool_mode[1]), .y(t4));
    ei_muxN #(.WIDTH(16)) mux5 (.d0(p5), .d1(pool5), .s(pool_mode[1]), .y(t5));
    ei_muxN #(.WIDTH(16)) mux6 (.d0(p6), .d1(pool6), .s(pool_mode[1]), .y(t6));
    ei_muxN #(.WIDTH(16)) mux7 (.d0(p7), .d1(pool7), .s(pool_mode[1]), .y(t7));
    ei_muxN #(.WIDTH(16)) mux8 (.d0(p8), .d1(pool8), .s(pool_mode[1]), .y(t8));

    // -----------------------------
    // 3) Tree adder
    // -----------------------------
    ei_tree_adder u_tree (
        .sys_clk(sys_clk),
        .rst    (rst),
        .en     (en),
        .in0(t0), .in1(t1), .in2(t2),
        .in3(t3), .in4(t4), .in5(t5),
        .in6(t6), .in7(t7), .in8(t8),
        .sum_out(sum_out)
    );

    // -----------------------------
    // 4) New pipelined maxpool
    // -----------------------------
    ei_fp16_maxpooling #(
        .WIDTH(16)
    ) u_max_pooling (
        .clk    (sys_clk),
        .rst    (rst),
        .en     (en),

        .d0(t0), .d1(t1), .d2(t2),
        .d3(t3), .d4(t4), .d5(t5),
        .d6(t6), .d7(t7), .d8(t8),

        .max_out(max_out_raw)
    );

    // -----------------------------
    // 5) Delay maxpool output to match LAT_TOTAL
    //    new maxpool latency = 5 cycles
    //    total external latency = LAT_TOTAL
    // -----------------------------
    generate
        if (LAT_MAX_ALIGN == 0) begin : GEN_NO_MAX_ALIGN
            assign max_out_aligned = max_out_raw;
        end else begin : GEN_MAX_ALIGN
            logic [15:0] max_chain [0:LAT_MAX_ALIGN];

            assign max_chain[0] = max_out_raw;

            genvar mi;
            for (mi = 0; mi < LAT_MAX_ALIGN; mi = mi + 1) begin : GEN_MAX_DELAY_FF
                regN #(.WIDTH(16)) u_max_delay (
                    .clk(sys_clk),
                    .rst(rst),
                    .en (en),
                    .d  (max_chain[mi]),
                    .q  (max_chain[mi+1])
                );
            end

            assign max_out_aligned = max_chain[LAT_MAX_ALIGN];
        end
    endgenerate

    // -----------------------------
    // 6) Valid pipeline
    // -----------------------------
    logic [LAT_TOTAL:0] vchain;
    assign vchain[0] = valid_in;

    genvar vi;
    generate
        for (vi = 0; vi < LAT_TOTAL; vi = vi + 1) begin : GEN_VFF
            regN #(.WIDTH(1)) u_vff (
                .clk(sys_clk),
                .rst(rst),
                .en (en),
                .d  (vchain[vi]),
                .q  (vchain[vi+1])
            );
        end
    endgenerate

    assign valid_out = vchain[LAT_TOTAL];

    // -----------------------------
    // 7) Delay pool_mode to match data_out
    // -----------------------------
    logic [1:0] mode_chain [0:LAT_TOTAL];
    assign mode_chain[0] = pool_mode;

    genvar ci;
    generate
        for (ci = 0; ci < LAT_TOTAL; ci = ci + 1) begin : GEN_MODE_FF
            regN #(.WIDTH(2)) u_mode_ff (
                .clk(sys_clk),
                .rst(rst),
                .en (en),
                .d  (mode_chain[ci]),
                .q  (mode_chain[ci+1])
            );
        end
    endgenerate

    logic [1:0] pool_mode_d;
    assign pool_mode_d = mode_chain[LAT_TOTAL];

    // -----------------------------
    // 8) Average pooling output
    // -----------------------------
    ei_multiplier_fp16 pool_mul (
        .sys_clk(sys_clk),
        .rst    (rst),
        .en     (en),
        .a_in   (sum_out),
        .b_in   (const_pool),
        .c_out  (pool_output)
    );

    // -----------------------------
    // 9) Final output select
    // -----------------------------
    always_comb begin
        unique case (pool_mode_d)
            2'b10:   data_out = pool_output;       // avg pool
            2'b11:   data_out = max_out_aligned;   // max pool
            default: data_out = sum_out;           // conv, both 00 and 01
        endcase
    end

endmodule