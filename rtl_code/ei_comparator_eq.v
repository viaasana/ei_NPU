module ei_comparator_eq #(
    parameter WIDTH = 6
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output             eq
);
    wire [WIDTH-1:0] xnor_bits;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin
            assign xnor_bits[i] = ~(a[i] ^ b[i]);
        end
    endgenerate

    assign eq = &xnor_bits; // AND tất cả bit
endmodule
          