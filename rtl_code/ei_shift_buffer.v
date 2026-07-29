`timescale 1ns/1ps
module ei_shift_buffer #(
  parameter integer WIDTH = 16,
  parameter integer DEPTH = 8
)(
  input                   clk,
  input                   rst,
  input                   en,

  // input stream
  input      [WIDTH-1:0]  in_data,
  input                   in_valid,
  output                  in_ready,

  // output stream
  output     [WIDTH-1:0]  out_data,
  output                  out_valid,
  input                   out_ready
);

  reg [WIDTH-1:0] mem [0:DEPTH-1];
  reg [$clog2(DEPTH+1)-1:0] count;

  assign in_ready  = (count < DEPTH);
  assign out_valid = (count != 0);
  assign out_data  = mem[0];

  wire push = en && in_valid && in_ready;
  wire pop  = en && out_valid && out_ready;

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      count <= 0;
      // (không cần clear mem)
    end else if (en) begin
      case ({push, pop})
        2'b10: begin
          // push only
          mem[count] <= in_data;
          count <= count + 1;
        end

        2'b01: begin
          // pop only: shift left
          for (i = 0; i < DEPTH-1; i = i + 1)
            mem[i] <= mem[i+1];
          count <= count - 1;
        end

        2'b11: begin
          // push & pop same cycle:
          // shift left then write into tail (count-1), count unchanged
          for (i = 0; i < DEPTH-1; i = i + 1)
            mem[i] <= mem[i+1];
          mem[count-1] <= in_data;
          // count stays
        end

        default: begin
          // idle
          count <= count;
        end
      endcase
    end
  end

endmodule
