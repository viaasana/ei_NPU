`timescale 1ns/1ps
module ei_sign(
    input  sign_a,
    input  sign_b,
    output sign_r
);
    assign sign_r = (~sign_a &  sign_b) | ( sign_a & ~sign_b);
endmodule
