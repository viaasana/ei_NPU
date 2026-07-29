`timescale 1ns/1ps
module ei_tree_adder_fp16_3x3 (
    input         sys_clk,
    input         rst,     // sync active-high
    input         en,
    input  [15:0] x0,
    input  [15:0] x1,
    input  [15:0] x2,
    input  [15:0] x3,
    input  [15:0] x4,
    input  [15:0] x5,
    input  [15:0] x6,
    input  [15:0] x7,
    input  [15:0] x8,
    output [15:0] y
);
    // -------------------------
    // Level 1 (lat 4)
    // -------------------------
    wire [15:0] s0, s1, s2, s3;

    ei_adder_fp16 a10 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x0), .b_in(x1), .sum_out(s0));
    ei_adder_fp16 a11 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x2), .b_in(x3), .sum_out(s1));
    ei_adder_fp16 a12 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x4), .b_in(x5), .sum_out(s2));
    ei_adder_fp16 a13 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(x6), .b_in(x7), .sum_out(s3));

    // -------------------------
    // Level 2 (lat 8)
    // -------------------------
    wire [15:0] t0, t1;
    ei_adder_fp16 a20 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(s0), .b_in(s1), .sum_out(t0));
    ei_adder_fp16 a21 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(s2), .b_in(s3), .sum_out(t1));

    // -------------------------
    // Level 3 (lat 12)
    // -------------------------
    wire [15:0] u0;
    ei_adder_fp16 a30 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(t0), .b_in(t1), .sum_out(u0));

    // -------------------------
    // Delay x8 by 12 cycles to align with u0
    // -------------------------
    wire [15:0] x8_d12;
    ei_delay_fp16 #(.CYCLES(12)) u_dly12 (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(x8), .q(x8_d12)
    );

    // -------------------------
    // Level 4 (lat 16): final
    // -------------------------
    ei_adder_fp16 a40 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(u0), .b_in(x8_d12), .sum_out(y));

endmodule