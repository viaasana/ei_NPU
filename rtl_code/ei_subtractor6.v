`timescale 1ns/1ps
module ei_subtractor6 (
    input  [5:0] a,
    input  [5:0] b,
    output [5:0] diff,
    output       borrow   // optional: không dùng cũng được
);
    wire [6:0] c;

    // c[0] = 1 => +1 để thành a + (~b) + 1
    assign c[0] = 1'b1;

    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : SUB_CHAIN
            ei_full_adder fa_sub (
                .a   (a[i]),
                .b   (~b[i]),   // đảo b
                .cin (c[i]),
                .sum (diff[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    // Với 2's complement: borrow = ~carry_out (nếu cần xài)
    assign borrow = ~c[6];

endmodule
