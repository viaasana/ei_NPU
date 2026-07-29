`timescale 1ns/1ps

module ei_adderN #(
    parameter WIDTH = 6
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] sum,
    output             cout   // carry-out
);
    wire [WIDTH:0] c;   // chuỗi carry

    assign c[0] = 1'b0; // không có carry-in (adder thường)

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : ADD_CHAIN
            ei_full_adder fa (
                .a   (a[i]),
                .b   (b[i]),
                .cin (c[i]),
                .sum (sum[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    // carry-out cuối
    assign cout = c[WIDTH];

endmodule
