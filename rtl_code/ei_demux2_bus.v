`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/05/2026 10:57:32 AM
// Design Name: 
// Module Name: ei_demux2_bus
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module ei_demux2_bus #(
    parameter WIDTH = 16
)(
    input  [WIDTH-1:0] d,
    input              s,
    output [WIDTH-1:0] y0,
    output [WIDTH-1:0] y1
);

genvar i;
generate
    for(i = 0; i < WIDTH; i = i + 1) begin : GEN_DEMUX
        ei_demux2 u_demux2 (
            .d  (d[i]),
            .s  (s),
            .y0 (y0[i]),
            .y1 (y1[i])
        );
    end
endgenerate

endmodule