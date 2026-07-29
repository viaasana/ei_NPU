`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/26/2026
// Design Name: 
// Module Name: ei_demuxN
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Demultiplexer N-output built from ei_demux2 modules (tree structure)
// 
// Dependencies: ei_demux2.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ei_demuxN #(
    parameter N = 8  // Number of outputs (must be power of 2)
) (
    input  d,                  // Input data
    input  [$clog2(N)-1:0] s,  // Select signal
    output [N-1:0] y           // Output array
);

    localparam SEL_WIDTH = $clog2(N);
    
    generate
        if (N == 1) begin
            // Base case: single output
            assign y[0] = d;
        end
        else if (N == 2) begin
            // Use ei_demux2 directly
            ei_demux2 demux_inst (
                .d(d),
                .s(s[0]),
                .y0(y[0]),
                .y1(y[1])
            );
        end
        else begin
            // Recursive case: build from ei_demux2 and smaller demuxN
            localparam HALF_N = N / 2;
            localparam HALF_SEL_WIDTH = SEL_WIDTH - 1;
            
            wire demux2_y0, demux2_y1;
            
            // First level: demux2 splits into two paths
            ei_demux2 demux2_inst (
                .d(d),
                .s(s[SEL_WIDTH-1]),      // Most significant bit
                .y0(demux2_y0),
                .y1(demux2_y1)
            );
            
            // Second level: two ei_demuxN blocks for each path
            ei_demuxN #(.N(HALF_N)) demux_lower (
                .d(demux2_y0),
                .s(s[HALF_SEL_WIDTH-1:0]),
                .y(y[HALF_N-1:0])
            );
            
            ei_demuxN #(.N(HALF_N)) demux_upper (
                .d(demux2_y1),
                .s(s[HALF_SEL_WIDTH-1:0]),
                .y(y[N-1:HALF_N])
            );
        end
    endgenerate

endmodule
