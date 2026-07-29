`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2026 09:19:42 AM
// Design Name: 
// Module Name: ei_residual_connector
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

module ei_residual_connector #(
    parameter integer VALID_LAT = 4   // set to match ei_adder_fp16 latency
)(
    input          sys_clk,
    input          rst,
    input          en,

    input          valid_in,
    output         valid_out,

    input  [15:0]  a0, a1, a2,
    input  [15:0]  a3, a4, a5,
    input  [15:0]  a6, a7, a8,

    input  [15:0]  b0, b1, b2,
    input  [15:0]  b3, b4, b5,
    input  [15:0]  b6, b7, b8,

    output [15:0]  s0, s1, s2,
    output [15:0]  s3, s4, s5,
    output [15:0]  s6, s7, s8
);

    wire [15:0] mat_a [0:8];
    wire [15:0] mat_b [0:8];
    wire [15:0] mat_s [0:8];

    assign mat_a[0] = a0; assign mat_a[1] = a1; assign mat_a[2] = a2;
    assign mat_a[3] = a3; assign mat_a[4] = a4; assign mat_a[5] = a5;
    assign mat_a[6] = a6; assign mat_a[7] = a7; assign mat_a[8] = a8;

    assign mat_b[0] = b0; assign mat_b[1] = b1; assign mat_b[2] = b2;
    assign mat_b[3] = b3; assign mat_b[4] = b4; assign mat_b[5] = b5;
    assign mat_b[6] = b6; assign mat_b[7] = b7; assign mat_b[8] = b8;

    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin : GEN_FP_ADDERS
            ei_adder_fp16 u_fp_adder (
                .sys_clk (sys_clk),
                .rst     (rst),
                .en      (en),
                .a_in    (mat_a[i]),
                .b_in    (mat_b[i]),
                .sum_out (mat_s[i])
            );
        end
    endgenerate

    assign s0 = mat_s[0]; assign s1 = mat_s[1]; assign s2 = mat_s[2];
    assign s3 = mat_s[3]; assign s4 = mat_s[4]; assign s5 = mat_s[5];
    assign s6 = mat_s[6]; assign s7 = mat_s[7]; assign s8 = mat_s[8];

    // ------------------------------------------------------------
    // Valid pipeline
    // valid_out is delayed to match the datapath latency
    // ------------------------------------------------------------
    generate
        if (VALID_LAT == 0) begin : GEN_VALID_BYPASS
            assign valid_out = valid_in & en;
        end else begin : GEN_VALID_PIPE
            reg [VALID_LAT-1:0] valid_pipe;
            integer k;

            always @(posedge sys_clk) begin
                if (rst) begin
                    valid_pipe <= {VALID_LAT{1'b0}};
                end else if (en) begin
                    valid_pipe[0] <= valid_in;
                    for (k = 1; k < VALID_LAT; k = k + 1) begin
                        valid_pipe[k] <= valid_pipe[k-1];
                    end
                end
            end

            assign valid_out = valid_pipe[VALID_LAT-1];
        end
    endgenerate

endmodule