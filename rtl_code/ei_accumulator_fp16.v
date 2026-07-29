//`timescale 1ns/1ps
//module ei_accumulator_fp16 #(
//    parameter integer LAT   = 5,
//    parameter integer CW    = 3  // counter width, phải đủ chứa (2^CW > LAT)
//)(
//    input              sys_clk,
//    input              rst,
//    input              en,
//    input              acc_clear,

//    input      [15:0]  bias,      // Changed from inout to input
//    input      [15:0]  a_in,
//    input              valid_in,

//    output     [15:0]  sum_out,
//    output             valid_out,
//    output             ready_in 
//);

//  // -------------------------
//  // 1) Input register
//  // -------------------------
//  reg [15:0] in_reg;

//  // -------------------------
//  // 2) busy + counter
//  // -------------------------
//  reg busy;
//  wire accept = en & valid_in & ~busy;
//  assign ready_in = ~busy;

//  wire [CW-1:0] cnt_q;
//  wire cnt_cout;
//  localparam integer MOD = (1 << CW);
//  localparam [CW-1:0] LOAD_VAL = MOD - LAT;

//  wire cnt_en = en & busy;
//  wire cnt_load = accept;

//  ei_counter #(.WIDTH(CW)) u_cnt (
//    .clk        (sys_clk),
//    .rst        (rst),
//    .en         (cnt_en | accept),
//    .load_sel   (cnt_load),
//    .load_value (LOAD_VAL),
//    .q          (cnt_q),
//    .cout       (cnt_cout)
//  );

//  wire done_pulse = cnt_cout & cnt_en;

//  // -------------------------
//  // 3) FP16 adder pipeline
//  // -------------------------
//  wire [15:0] feedback_reg;
//  wire [15:0] sum_temp;

//  ei_adder_fp16 u_adder (
//    .sys_clk(sys_clk),
//    .rst    (rst),
//    .en     (en),
//    .a_in   (feedback_reg), // feedback_reg will hold bias initially
//    .b_in   (in_reg),
//    .sum_out(sum_temp)
//  );

//  // -------------------------
//  // 4) Commit feedback with BIAS initialization
//  // -------------------------
//  // We don't use regN here because regN typically resets to 0.
//  // This logic ensures the feedback starts at 'bias'.
//  reg [15:0] feedback_storage;
  
//  always @(posedge sys_clk) begin
//    if (rst || acc_clear) begin
//      feedback_storage <= bias;      // Load bias on reset/clear
//    end else if (en && done_pulse) begin
//      feedback_storage <= sum_temp;  // Update with new sum when finished
//    end
//  end
  
//  assign feedback_reg = feedback_storage;

//  // Output
//  assign sum_out   = sum_temp;
//  assign valid_out = done_pulse;

//  // -------------------------
//  // 5) busy + in_reg control
//  // -------------------------
//  always @(posedge sys_clk) begin
//    if (rst || acc_clear) begin
//      busy   <= 1'b0;
//      in_reg <= 16'h0000;
//    end else if (en) begin
//      if (accept) begin
//        in_reg <= a_in;
//        busy   <= 1'b1;
//      end else if (done_pulse) begin
//        busy   <= 1'b0;
//      end
//    end
//  end

//endmodule
`timescale 1ns/1ps
module ei_accumulator_fp16 #(
    parameter integer LAT   = 5,
    parameter integer CW    = 3  // counter width, ph?i ?? ch?a (2^CW > LAT)
)(
    input              sys_clk,
    input              rst,
    input              en,
    input              acc_clear,

    input      [15:0]  bias,      
    input      [15:0]  a_in,
    input              valid_in,

    output     [15:0]  sum_out,
    output             valid_out,
    output             ready_in 
);

  // -------------------------
  // 1) Input register
  // -------------------------
  reg [15:0] in_reg;

  // -------------------------
  // 2) busy + counter
  // -------------------------
  reg busy;
  wire accept = en & valid_in & ~busy;
  assign ready_in = ~busy;

  wire [CW-1:0] cnt_q;
  wire cnt_cout;
  localparam integer MOD = (1 << CW);
  localparam [CW-1:0] LOAD_VAL = MOD - LAT;

  wire cnt_en = en & busy;
  wire cnt_load = accept;

  ei_counter #(.WIDTH(CW)) u_cnt (
    .clk        (sys_clk),
    .rst        (rst),
    .en         (cnt_en | accept),
    .load_sel   (cnt_load),
    .load_value (LOAD_VAL),
    .q          (cnt_q),
    .cout       (cnt_cout)
  );

  wire done_pulse = cnt_cout & cnt_en;

  // -------------------------
  // 3) FP16 adder pipeline
  // -------------------------
  wire [15:0] feedback_reg;
  wire [15:0] sum_temp;

  ei_adder_fp16 u_adder (
    .sys_clk(sys_clk),
    .rst    (rst),
    .en     (en),
    .a_in   (feedback_reg), 
    .b_in   (in_reg),
    .sum_out(sum_temp)
  );

  // -------------------------
  // 4) Commit feedback with BIAS initialization
  // -------------------------
  reg [15:0] feedback_storage;
  
  always @(posedge sys_clk) begin
    if (rst) begin
      // S?A L?I 2: X�a acc_clear ? ?�y. ??a v? gi� tr? 0 khi reset to�n h? th?ng.
      feedback_storage <= 16'h0000;
    end else if (en) begin
      // CH? N?P bias khi th?t s? B?T ??U x? l� m?t ?i?m d? li?u m?i (accept == 1)
      if (accept && acc_clear) begin
        feedback_storage <= bias;
      end else if (done_pulse) begin
        feedback_storage <= sum_temp;
      end
    end
  end
  
  assign feedback_reg = feedback_storage;

  // Output
  assign sum_out   = sum_temp;
  assign valid_out = done_pulse;

  // -------------------------
  // 5) busy + in_reg control
  // -------------------------
  always @(posedge sys_clk) begin
    if (rst) begin 
      // S?A L?I 1: Tuy?t ??i kh�ng d�ng acc_clear ?? reset tr?ng th�i FSM (busy)
      busy   <= 1'b0;
      in_reg <= 16'h0000;
    end else if (en) begin
      if (accept) begin
        in_reg <= a_in;
        busy   <= 1'b1;
      end else if (done_pulse) begin
        busy   <= 1'b0;
      end
    end
  end

endmodule