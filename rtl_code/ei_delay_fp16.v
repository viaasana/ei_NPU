`timescale 1ns/1ps

// Delay FP16 theo số cycle bất kỳ, có en để giữ sync pipeline
module ei_delay_fp16 #(
    parameter integer CYCLES = 0
)(
    input         clk,
    input         rst,
    input         en,
    input  [15:0] d,
    output [15:0] q
);
generate
    if (CYCLES == 0) begin : g0
        assign q = d;
    end else if (CYCLES == 1) begin : g1
        wire [15:0] q1;
        regN #(.WIDTH(16)) u1 (.clk(clk), .rst(rst), .en(en), .d(d), .q(q1));
        assign q = q1;
    end else begin : gN
        localparam integer W = 16*CYCLES;
        wire [W-1:0] pipe_d;
        wire [W-1:0] pipe_q;

        // shift left mỗi cycle, append d vào LSB
        assign pipe_d = { pipe_q[W-17:0], d };

        regN #(.WIDTH(W)) u_pipe (
            .clk(clk), .rst(rst), .en(en),
            .d(pipe_d), .q(pipe_q)
        );

        assign q = pipe_q[W-1:W-16]; // value delayed CYCLES cycles
    end
endgenerate
endmodule