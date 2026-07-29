`timescale 1ns/1ps

module ei_pe_array #(
    parameter int NUM_PE        = 16,
    parameter int LATENCY_MUL   = 4,
    parameter int LAT_TREE      = 16,
    parameter int LAT_TOTAL     = 29,
    parameter int WIDTH         = 16,
    parameter int DEPTH         = 8,
    parameter int ACC_LAT       = 5,
    parameter int ACC_CW        = 3,
    parameter int RES_VALID_LAT = 4
)(
    input  logic                sys_clk,
    input  logic                rst,
    input  logic                en,

    // ==========================================
    // Broadcast Control (Sent to ALL PEs)
    // ==========================================
    input  logic [NUM_PE-1:0]       valid_in,
    //input  logic [NUM_PE-1:0]       residual_en,
    input  logic [1:0]              pool_mode [0:NUM_PE-1],
    input  logic [15:0]             const_pool [0:NUM_PE-1],
    input  logic [1:0]              act_mode [0:NUM_PE-1],
    input  logic [NUM_PE-1:0]       acc_clear,
    input  logic [NUM_PE-1:0]       final_input_channel,

    // ==========================================
    // Aggregate Ready Signals
    // ==========================================
    output logic [NUM_PE-1:0] ready_in_per_pe, // Individual ready states
    output logic              ready_all,       // Goes high only if ALL PEs are ready

    // ==========================================
    // Vectorized Data Inputs (Unique per PE)
    // ==========================================
    // bias[16]
    input  logic [15:0] bias_in [0:NUM_PE-1],
    
    // x_in[16 PEs][9 inputs each]
    input  logic [15:0] x_in    [0:NUM_PE-1][0:8], 
    
    // w_in[16 PEs][9 inputs each]
    input  logic [15:0] w_in    [0:NUM_PE-1][0:8], 

    // ==========================================
    // Vectorized Data Outputs (Unique per PE)
    // ==========================================
    output logic [15:0]         sum_out                       [0:NUM_PE-1],
    output logic [NUM_PE-1:0]   valid_out,
    output logic [NUM_PE-1:0]   final_input_channel_valid_out,
    output logic [15:0]         pe_sum_out                    [0:NUM_PE-1]

    // Vectorized Residual Outputs: residual_out[16 PEs][9 outputs each]
    //output logic [15:0]         residual_out                  [0:NUM_PE-1][0:8],
    //output logic [NUM_PE-1:0]   residual_valid_out
);

    // ---------------------------------------------------------
    // Aggregate the "Ready" signal
    // Use a bitwise AND reduction operator (&). 
    // ready_all is 1 ONLY if every single bit in ready_in_per_pe is 1.
    // ---------------------------------------------------------
    assign ready_all = &ready_in_per_pe;

    // ---------------------------------------------------------
    // Generate Block: Instantiate 16 PEs
    // ---------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < NUM_PE; i = i + 1) begin : GEN_PE_ARRAY
            
            ei_pe #(
                .LATENCY_MUL   (LATENCY_MUL),
                .LAT_TREE      (LAT_TREE),
                .LAT_TOTAL     (LAT_TOTAL),
                .WIDTH         (WIDTH),
                .DEPTH         (DEPTH),
                .ACC_LAT       (ACC_LAT),
                .ACC_CW        (ACC_CW),
                .RES_VALID_LAT (RES_VALID_LAT)
            ) u_pe_inst (
                .sys_clk       (sys_clk),
                .rst           (rst),
                .en            (en),
                
                // Control
                .valid_in      (valid_in[i]),
                .ready_in      (ready_in_per_pe[i]),
                //.residual_en   (residual_en[i]),
                .pool_mode     (pool_mode[i]),
                .const_pool    (const_pool[i]),
                .act_mode      (act_mode[i]),
                .acc_clear     (acc_clear[i]),
                .final_input_channel (final_input_channel[i]),
                
                // Unique Inputs mapped from 2D Arrays
                .bias          (bias_in[i]),
                .x0(x_in[i][0]), .x1(x_in[i][1]), .x2(x_in[i][2]), 
                .x3(x_in[i][3]), .x4(x_in[i][4]), .x5(x_in[i][5]), 
                .x6(x_in[i][6]), .x7(x_in[i][7]), .x8(x_in[i][8]),
                
                .w0(w_in[i][0]), .w1(w_in[i][1]), .w2(w_in[i][2]), 
                .w3(w_in[i][3]), .w4(w_in[i][4]), .w5(w_in[i][5]), 
                .w6(w_in[i][6]), .w7(w_in[i][7]), .w8(w_in[i][8]),
                
                // Unique Outputs mapped to Arrays
                .sum_out                       (sum_out[i]),
                .valid_out                     (valid_out[i]),
                .final_input_channel_valid_out (final_input_channel_valid_out[i]),
                .pe_sum_out                    (pe_sum_out[i])
                
                // Residual Outputs mapped to 2D Array
//                .residual_out0 (residual_out[i][0]), .residual_out1 (residual_out[i][1]), .residual_out2 (residual_out[i][2]),
//                .residual_out3 (residual_out[i][3]), .residual_out4 (residual_out[i][4]), .residual_out5 (residual_out[i][5]),
//                .residual_out6 (residual_out[i][6]), .residual_out7 (residual_out[i][7]), .residual_out8 (residual_out[i][8]),
                
//                .residual_valid_out            (residual_valid_out[i]),
//                .test_signal                   () // Leave unconnected if not tracking individually
            );

        end
    endgenerate

    // always @(posedge sys_clk) begin
    //     if(valid_in[0])
    //         $display("[pe_aray] x_in: %0h", pe_sum_out[0]);
    // end

endmodule