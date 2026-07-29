`timescale 1ns / 1ps

module ei_fp16_maxpooling #(
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             en,

    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [WIDTH-1:0] d4,
    input  logic [WIDTH-1:0] d5,
    input  logic [WIDTH-1:0] d6,
    input  logic [WIDTH-1:0] d7,
    input  logic [WIDTH-1:0] d8,

    output logic [WIDTH-1:0] max_out
);

    // Comparator outputs
    logic [WIDTH-1:0] c_d01, c_d23, c_d45, c_d67;
    logic [WIDTH-1:0] c_d0123, c_d4567;
    logic [WIDTH-1:0] c_d01234567;
    logic [WIDTH-1:0] c_max_out;

    // Stage 0 registers
    logic [WIDTH-1:0] r0_d0, r0_d1, r0_d2, r0_d3, r0_d4;
    logic [WIDTH-1:0] r0_d5, r0_d6, r0_d7, r0_d8;

    // Stage 1 registers
    logic [WIDTH-1:0] r1_d01, r1_d23, r1_d45, r1_d67;
    logic [WIDTH-1:0] r1_d8;

    // Stage 2 registers
    logic [WIDTH-1:0] r2_d0123, r2_d4567;
    logic [WIDTH-1:0] r2_d8;

    // Stage 3 registers
    logic [WIDTH-1:0] r3_d01234567;
    logic [WIDTH-1:0] r3_d8;

    // ================= STAGE 0 =================
    always_ff @(posedge clk) begin
        if (rst) begin
            r0_d0 <= '0; r0_d1 <= '0; r0_d2 <= '0;
            r0_d3 <= '0; r0_d4 <= '0; r0_d5 <= '0;
            r0_d6 <= '0; r0_d7 <= '0; r0_d8 <= '0;
        end else if (en) begin
            r0_d0 <= d0;
            r0_d1 <= d1;
            r0_d2 <= d2;
            r0_d3 <= d3;
            r0_d4 <= d4;
            r0_d5 <= d5;
            r0_d6 <= d6;
            r0_d7 <= d7;
            r0_d8 <= d8;
        end
    end

    // ================= STAGE 1 =================
    ei_fp16_2num_comparator g0 (.a(r0_d0), .b(r0_d1), .max_val(c_d01));
    ei_fp16_2num_comparator g1 (.a(r0_d2), .b(r0_d3), .max_val(c_d23));
    ei_fp16_2num_comparator g2 (.a(r0_d4), .b(r0_d5), .max_val(c_d45));
    ei_fp16_2num_comparator g3 (.a(r0_d6), .b(r0_d7), .max_val(c_d67));

    always_ff @(posedge clk) begin
        if (rst) begin
            r1_d01 <= '0;
            r1_d23 <= '0;
            r1_d45 <= '0;
            r1_d67 <= '0;
            r1_d8  <= '0;
        end else if (en) begin
            r1_d01 <= c_d01;
            r1_d23 <= c_d23;
            r1_d45 <= c_d45;
            r1_d67 <= c_d67;
            r1_d8  <= r0_d8;
        end
    end

    // ================= STAGE 2 =================
    ei_fp16_2num_comparator g4 (.a(r1_d01), .b(r1_d23), .max_val(c_d0123));
    ei_fp16_2num_comparator g5 (.a(r1_d45), .b(r1_d67), .max_val(c_d4567));

    always_ff @(posedge clk) begin
        if (rst) begin
            r2_d0123 <= '0;
            r2_d4567 <= '0;
            r2_d8    <= '0;
        end else if (en) begin
            r2_d0123 <= c_d0123;
            r2_d4567 <= c_d4567;
            r2_d8    <= r1_d8;
        end
    end

    // ================= STAGE 3 =================
    ei_fp16_2num_comparator g6 (.a(r2_d0123), .b(r2_d4567), .max_val(c_d01234567));

    always_ff @(posedge clk) begin
        if (rst) begin
            r3_d01234567 <= '0;
            r3_d8        <= '0;
        end else if (en) begin
            r3_d01234567 <= c_d01234567;
            r3_d8        <= r2_d8;
        end
    end

    // ================= STAGE 4 =================
    ei_fp16_2num_comparator g7 (.a(r3_d01234567), .b(r3_d8), .max_val(c_max_out));

    always_ff @(posedge clk) begin
        if (rst) begin
            max_out <= '0;
        end else if (en) begin
            max_out <= c_max_out;
        end
    end

endmodule