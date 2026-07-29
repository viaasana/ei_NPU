`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/26/2026
// Design Name: 
// Module Name: ei_demux2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Demultiplexer 1-to-2, reverse of ei_mux2
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ei_demux2 (
    input  d,      // Input data
    input  s,      // Select signal
    output y0,     // Output 0 (when s=0)
    output y1      // Output 1 (when s=1)
);
    assign y0 = (~s) & d;  // d goes to y0 when s=0
    assign y1 = (s) & d;   // d goes to y1 when s=1
endmodule
