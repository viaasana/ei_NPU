`timescale 1ns/1ps
module ei_pe #(
  parameter int LATENCY_MUL   = 4,
  parameter int LAT_TREE      = 16,
  parameter int LAT_TOTAL     = 29,
  parameter int WIDTH         = 16,
  parameter int DEPTH         = 8,

  parameter int ACC_LAT       = 5,
  parameter int ACC_CW        = 3,
  parameter int RES_VALID_LAT = 4
)(
  input  logic        sys_clk,
  input  logic        rst,
  input  logic        en,

  input  logic        valid_in,
  output logic        ready_in,

  input  logic        residual_en,

  input  logic [1:0]  pool_mode,
  input  logic [15:0] const_pool,
  input  logic [1:0]  act_mode,

  input  logic [15:0] bias,

  input  logic [15:0] x0,x1,x2,x3,x4,x5,x6,x7,x8,
  input  logic [15:0] w0,w1,w2,w3,w4,w5,w6,w7,w8,

  input  logic        acc_clear,

  // tag input for "this accepted launch is final-input-channel"
  input  logic        final_input_channel,

  output logic [15:0] sum_out,
  output logic        valid_out,

  // goes high only for launches whose input tag was final_input_channel=1
  output logic        final_input_channel_valid_out,

  output logic [15:0] pe_sum_out,

  // Parallel buffered outputs for residual mode
 output logic [15:0] residual_out0,
 output logic [15:0] residual_out1,
 output logic [15:0] residual_out2,
 output logic [15:0] residual_out3,
 output logic [15:0] residual_out4,
 output logic [15:0] residual_out5,
 output logic [15:0] residual_out6,
 output logic [15:0] residual_out7,
 output logic [15:0] residual_out8,
 output logic        residual_valid_out,
 output              test_signal
);

  localparam logic [1:0] PE_MODE_CONV = 2'b00;
  localparam logic [1:0] ACT_LINEAR   = 2'b00;

  // -----------------------------
  // 1) Launch routing
  // -----------------------------
  wire launch_fire      = valid_in && ready_in;
  wire conv_launch_fire = launch_fire; //&& !residual_en;
  wire res_launch_fire  = launch_fire;// &&  residual_en;

  // -----------------------------
  // 1b) Robust Tag FIFO cho MUXPOOL
  // -----------------------------
  logic [63:0] mux_tag_fifo_final;
  logic [63:0] mux_tag_fifo_clear;
  logic [5:0]  mux_tag_wr_ptr;
  logic [5:0]  mux_tag_rd_ptr;

  logic        pe_valid_out_conv;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      mux_tag_wr_ptr     <= '0;
      mux_tag_rd_ptr     <= '0;
      mux_tag_fifo_final <= '0;
      mux_tag_fifo_clear <= '0;
    end else if (en) begin
      // Đẩy cờ vào khi data bắt đầu vào MUXPOOL
      if (conv_launch_fire) begin
        mux_tag_fifo_final[mux_tag_wr_ptr] <= final_input_channel;
        mux_tag_fifo_clear[mux_tag_wr_ptr] <= acc_clear;
        mux_tag_wr_ptr <= mux_tag_wr_ptr + 1'b1;
      end
      
      // Chuyển con trỏ lấy cờ khi MUXPOOL tính xong
      if (pe_valid_out_conv) begin
        mux_tag_rd_ptr <= mux_tag_rd_ptr + 1'b1;
      end
    end
  end

  wire pe_final_input_channel = mux_tag_fifo_final[mux_tag_rd_ptr];
  wire pe_acc_clear           = mux_tag_fifo_clear[mux_tag_rd_ptr]; 
  assign test_signal = final_input_channel;
  // -----------------------------
  // 2) Normal PE mux/pool path
  // -----------------------------
  logic [15:0] pe_sum_out_conv;
  

  ei_pe_muxpool #(
    .LATENCY_MUL(LATENCY_MUL),
    .LAT_TREE   (LAT_TREE),
    .LAT_TOTAL  (20)
  ) u_pe_muxpool (
    .sys_clk   (sys_clk),
    .rst       (rst),
    .en        (en),
    .valid_in  (conv_launch_fire),

    .pool_mode (pool_mode),
    .const_pool(const_pool),

    .x0(x0),.x1(x1),.x2(x2),.x3(x3),.x4(x4),.x5(x5),.x6(x6),.x7(x7),.x8(x8),
    .w0(w0),.w1(w1),.w2(w2),.w3(w3),.w4(w4),.w5(w5),.w6(w6),.w7(w7),.w8(w8),

    .pool0(x0),.pool1(x1),.pool2(x2),
    .pool3(x3),.pool4(x4),.pool5(x5),
    .pool6(x6),.pool7(x7),.pool8(x8),

    .data_out  (pe_sum_out_conv),
    .valid_out (pe_valid_out_conv)
  );

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      pe_sum_out <= 16'h0000;
    end else if (en) begin
      pe_sum_out <= pe_sum_out_conv;
    end
  end

  // -----------------------------
  // 3) Residual connector
  // -----------------------------
 logic [15:0] res_s0, res_s1, res_s2, res_s3, res_s4, res_s5, res_s6, res_s7, res_s8;
 logic        res_core_valid_out;
 logic        res_pending;

 ei_residual_connector #(
   .VALID_LAT(RES_VALID_LAT)
 ) u_residual (
   .sys_clk  (sys_clk),
   .rst      (rst),
   .en       (en),
   .valid_in (res_launch_fire),
   .valid_out(res_core_valid_out),

   .a0(x0), .a1(x1), .a2(x2), .a3(x3), .a4(x4), .a5(x5), .a6(x6), .a7(x7), .a8(x8),
   .b0(w0), .b1(w1), .b2(w2), .b3(w3), .b4(w4), .b5(w5), .b6(w6), .b7(w7), .b8(w8),
   .s0(res_s0), .s1(res_s1), .s2(res_s2), .s3(res_s3), .s4(res_s4), .s5(res_s5), .s6(res_s6), .s7(res_s7), .s8(res_s8)
 );

 always_ff @(posedge sys_clk) begin
   if (rst) begin
     res_pending         <= 1'b0;
     residual_valid_out  <= 1'b0;
     residual_out0 <= '0; residual_out1 <= '0; residual_out2 <= '0;
     residual_out3 <= '0; residual_out4 <= '0; residual_out5 <= '0;
     residual_out6 <= '0; residual_out7 <= '0; residual_out8 <= '0;
   end else if (en) begin
     residual_valid_out <= 1'b0;
     if (res_launch_fire)
       res_pending <= 1'b1;

     if (res_core_valid_out) begin
       residual_out0 <= res_s0; residual_out1 <= res_s1; residual_out2 <= res_s2;
       residual_out3 <= res_s3; residual_out4 <= res_s4; residual_out5 <= res_s5;
       residual_out6 <= res_s6; residual_out7 <= res_s7; residual_out8 <= res_s8;
       residual_valid_out <= 1'b1;
       res_pending        <= 1'b0;
     end
   end
 end

  // -----------------------------
  // 4) Shift buffer
  // -----------------------------
  wire [WIDTH+1:0] sb_in_data  = {pe_acc_clear, pe_final_input_channel, pe_sum_out_conv};
  wire             sb_in_valid = pe_valid_out_conv;
  wire             sb_in_ready;

  wire [WIDTH+1:0] sb_out_data;
  wire             sb_out_valid;
  wire             sb_out_ready;

  ei_shift_buffer #(.WIDTH(WIDTH+2), .DEPTH(DEPTH)) u_buf (
    .clk       (sys_clk),
    .rst       (rst),
    .en        (en),
    .in_data   (sb_in_data),
    .in_valid  (sb_in_valid),
    .in_ready  (sb_in_ready),
    .out_data  (sb_out_data),
    .out_valid (sb_out_valid),
    .out_ready (sb_out_ready)
  );

  // -----------------------------
  // 5) Holding reg
  // -----------------------------
  logic [15:0] mid_data;
  logic        mid_valid;
  logic        mid_final_input_channel;
  logic        mid_acc_clear;

  wire acc_ready_in;
  wire acc_fire = en && mid_valid && acc_ready_in;

  assign sb_out_ready = en && (!mid_valid || acc_fire);
  wire sb_pop = en && sb_out_valid && sb_out_ready;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      mid_valid               <= 1'b0;
      mid_data                <= 16'b0;
      mid_final_input_channel <= 1'b0;
      mid_acc_clear           <= 1'b0;
    end else if (en) begin
      case ({sb_pop, acc_fire})
        2'b10, 2'b11: begin 
          mid_data                <= sb_out_data[WIDTH-1:0];
          mid_final_input_channel <= sb_out_data[WIDTH];
          mid_acc_clear           <= sb_out_data[WIDTH+1];
          mid_valid               <= 1'b1;
        end
        2'b01: begin
          mid_valid <= 1'b0;
        end
        default: ;
      endcase
    end
  end

  // -----------------------------
  // 6) Accumulator 
  // -----------------------------
  logic [15:0] acc_sum_out;
  logic        acc_valid_out;

  ei_accumulator_fp16 #(.LAT(ACC_LAT), .CW(ACC_CW)) u_acc (
    .sys_clk   (sys_clk),
    .rst       (rst),
    .en        (en),
    .a_in      (mid_data),
    .valid_in  (mid_valid),
    .bias      (bias),
    .acc_clear (mid_acc_clear), 
    .sum_out   (acc_sum_out),
    .valid_out (acc_valid_out),
    .ready_in  (acc_ready_in)
  );

  // Pipeline the tag by exactly ACC_LAT (5) cycles internally
  // -----------------------------
  // Robust Tag FIFO cho Accumulator
  // -----------------------------
  logic [31:0] acc_tag_fifo;
  logic [4:0]  acc_tag_wr_ptr;
  logic [4:0]  acc_tag_rd_ptr;

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      acc_tag_wr_ptr <= '0;
      acc_tag_rd_ptr <= '0;
      acc_tag_fifo   <= '0;
    end else if (en) begin
      // Đẩy cờ vào khi data bắt đầu vào bộ cộng
      if (acc_fire) begin
        acc_tag_fifo[acc_tag_wr_ptr] <= mid_final_input_channel;
        acc_tag_wr_ptr <= acc_tag_wr_ptr + 1'b1;
      end
      
      // Chuyển con trỏ lấy cờ khi bộ cộng tính xong
      if (acc_valid_out) begin
        acc_tag_rd_ptr <= acc_tag_rd_ptr + 1'b1;
      end
    end
  end

  wire acc_final_input_channel_synced = acc_tag_fifo[acc_tag_rd_ptr];
  // -----------------------------
  // 7) Activation
  // -----------------------------
  logic [1:0]  act_mode_eff;
  logic [15:0] act_sum_out;
  logic        valid_out_d;
  logic        final_input_channel_valid_out_d;

  always_comb begin
   if (residual_en || (pool_mode != PE_MODE_CONV))
     act_mode_eff = ACT_LINEAR;
   else
     act_mode_eff = act_mode;
      // if (pool_mode != PE_MODE_CONV)
      //   act_mode_eff = ACT_LINEAR;
      //  else
      //   act_mode_eff = act_mode;
  end

  ei_activation_selector u_activation (
    .sys_clk (sys_clk),
    .rst     (rst),
    .en      (en),
    .mode    (act_mode_eff),
    .data_in (acc_sum_out),
    .data_out(act_sum_out)
  );

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      valid_out                       <= 1'b0;
      valid_out_d                     <= 1'b0;
      final_input_channel_valid_out   <= 1'b0;
      final_input_channel_valid_out_d <= 1'b0;
    end else if (en) begin
      valid_out_d   <= acc_valid_out;
      valid_out     <= valid_out_d;

      final_input_channel_valid_out_d <= acc_valid_out && acc_final_input_channel_synced;
      final_input_channel_valid_out   <= final_input_channel_valid_out_d;
    end
  end

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      sum_out <= 16'h0000;
    end else if (en) begin
      sum_out <= act_sum_out; 
    end
  end

  // -----------------------------
  // 8) Credit control
  // -----------------------------
  localparam int LVW = (DEPTH <= 1) ? 1 : $clog2(DEPTH+1);
  logic [LVW-1:0] buf_level;
  logic [LVW-1:0] pending_cnt;

  wire push = en && sb_in_valid && sb_in_ready;
  wire pop  = en && sb_out_valid && sb_out_ready;

  logic ready_next;

  wire conv_ready_raw = (buf_level + pending_cnt < DEPTH);

  always_comb begin
   if (residual_en)
     ready_next = !res_pending;
   else
     ready_next = conv_ready_raw;
      //ready_next = conv_ready_raw;
  end

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      ready_in <= 1'b0;
    end else if (en) begin
      ready_in <= ready_next;
    end
  end

  always_ff @(posedge sys_clk) begin
    if (rst) begin
      buf_level   <= '0;
      pending_cnt <= '0;
    end else if (en) begin
      case ({push, pop})
        2'b10: if (buf_level < DEPTH[LVW-1:0]) buf_level <= buf_level + 1'b1;
        2'b01: if (buf_level != 0)             buf_level <= buf_level - 1'b1;
        default: ;
      endcase

      case ({conv_launch_fire, push})
        2'b10: pending_cnt <= pending_cnt + 1'b1;
        2'b01: pending_cnt <= pending_cnt - 1'b1;
        default: ;
      endcase
    end
  end


    // always @(posedge sys_clk) begin
    //     if(mid_acc_clear)
    //         $display("[pe] accumulator: %0h %0h", bias, acc_sum_out);
    // end

endmodule