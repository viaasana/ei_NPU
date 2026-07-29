`timescale 1ns/1ps

// =====================================================
// MUX 2:1 cho bus 11-bit, dùng ei_mux2 1-bit
// =====================================================
module ei_mux11 (
    input  [10:0] d0,  // chọn khi s = 0
    input  [10:0] d1,  // chọn khi s = 1
    input         s,
    output [10:0] y
);
    genvar i;
    generate
        for (i = 0; i < 11; i = i + 1) begin : GEN_MUX11
            ei_mux2 u_mux (
                .d0 (d0[i]),
                .d1 (d1[i]),
                .s  (s),
                .y  (y[i])
            );
        end
    endgenerate
endmodule