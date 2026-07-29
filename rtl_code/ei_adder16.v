`timescale 1ns/1ps 
module ei_adder16 (
    input  [15:0] a,
    input  [15:0] b,
    output [15:0] sum,
    output        cout
);
    wire [16:0] c;

    assign c[0] = 1'b0;   // không có carry in ban đầu

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ADD_CHAIN
            ei_full_adder fa_inst (
                .a   (a[i]),
                .b   (b[i]),
                .cin (c[i]),
                .sum (sum[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    assign cout = c[16];
endmodule
