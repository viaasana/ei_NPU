`timescale 1ns/1ps

module ei_shr_varN #(
    parameter WIDTH = 11
)(
    input  [WIDTH-1:0] d_in,
    input  [3:0]       shamt,   // 0..15
    output [WIDTH-1:0] d_out
);
    wire [WIDTH-1:0] s0, s1, s2, s3;

    assign s0 = d_in;

    genvar i;

    // shift 1 bit nếu shamt[0] = 1
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : STAGE1
            wire keep    = s0[i];
            wire shifted = (i+1 < WIDTH) ? s0[i+1] : 1'b0;
            ei_mux2 u1 (
                .d0(keep),
                .d1(shifted),
                .s (shamt[0]),
                .y (s1[i])
            );
        end
    endgenerate

    // shift 2 bit nếu shamt[1] = 1
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : STAGE2
            wire keep    = s1[i];
            wire shifted = (i+2 < WIDTH) ? s1[i+2] : 1'b0;
            ei_mux2 u2 (
                .d0(keep),
                .d1(shifted),
                .s (shamt[1]),
                .y (s2[i])
            );
        end
    endgenerate

    // shift 4 bit nếu shamt[2] = 1
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : STAGE3
            wire keep    = s2[i];
            wire shifted = (i+4 < WIDTH) ? s2[i+4] : 1'b0;
            ei_mux2 u3 (
                .d0(keep),
                .d1(shifted),
                .s (shamt[2]),
                .y (s3[i])
            );
        end
    endgenerate

    // shift 8 bit nếu shamt[3] = 1
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : STAGE4
            wire keep    = s3[i];
            wire shifted = (i+8 < WIDTH) ? s3[i+8] : 1'b0;
            ei_mux2 u4 (
                .d0(keep),
                .d1(shifted),
                .s (shamt[3]),
                .y (d_out[i])
            );
        end
    endgenerate
endmodule
