`timescale 1ns/1ps
// =====================================================
// NEW #2: Variable SHR + Sticky
// d_out = d_in >> shamt (if shamt>=WIDTH => 0)
// sticky = OR of bits shifted out (lower bits)
// NOTE: sticky NOT merged into d_out[0]; you OR it outside.
// =====================================================
module ei_shr_varN_sticky #(
    parameter integer WIDTH   = 14,
    parameter integer SHAMT_W = 6
)(
    input  wire [WIDTH-1:0]   d_in,
    input  wire [SHAMT_W-1:0] shamt,
    output wire [WIDTH-1:0]   d_out,
    output reg                sticky
);
    integer i;

    wire shamt_ge_w = (shamt >= WIDTH[SHAMT_W-1:0]);
    assign d_out = shamt_ge_w ? {WIDTH{1'b0}} : (d_in >> shamt);

    always @* begin
        sticky = 1'b0;
        // OR all bits i < shamt
        for (i = 0; i < WIDTH; i = i+1) begin
            if (i < shamt) sticky = sticky | d_in[i];
        end
        if (shamt == 0) sticky = 1'b0;
    end
endmodule