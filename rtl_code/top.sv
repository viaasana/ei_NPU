`timescale 1ns/1ps

module top(
    input  logic        sys_clk,
    input  logic        rst,      // sync, active-high
    input  logic        en,
    input  logic [15:0] a_in,     // Ngõ vào dữ liệu
    output logic [15:0] d_out     // Ngõ ra dữ liệu
);

    logic [15:0] a_r;    // Dữ liệu sau thanh ghi input
    logic [15:0] relu_w; // Kết quả nối dây từ ei_RELU ra
    logic [15:0] relu_r; // Kết quả sau thanh ghi output

    // -----------------------------------------------------------
    // 1. Input Register
    // -----------------------------------------------------------
    regN #(.WIDTH(16)) u_reg_a (
        .clk(sys_clk),
        .rst(rst),
        .en (en),
        .d  (a_in),
        .q  (a_r)
    );

    // -----------------------------------------------------------
    // 2. DUT: ei_RELU
    // -----------------------------------------------------------
    ei_RELU u_relu (
        .data_in   (a_r),
        .data_out  (relu_w)
    );

    // -----------------------------------------------------------
    // 3. Output Register
    // -----------------------------------------------------------
    regN #(.WIDTH(16)) u_reg_out (
        .clk(sys_clk),
        .rst(rst),
        .en (en),
        .d  (relu_w),
        .q  (relu_r)
    );

    assign d_out = relu_r;

endmodule