`timescale 1ns / 1ps

module ei_activation_selector #(
    parameter SIGMOID_FILE = "/data/users/s23520966/data/sigmoid_fp16.hex",
    parameter TANH_FILE    = "/data/users/s23520966/data/tanh_fp16_1024.hex",
    parameter SOFTMAX_FILE    = "/data/users/s23520966/data/softmax_fp16_1024.hex"
)(
    input  wire        sys_clk,
    input  wire        rst,
    input  wire        en,
    input  wire [1:0]  mode,    // 00: Linear, 01: ReLU6, 10: Sigmoid, 11: Tanh
    input  wire [15:0] data_in,
    output logic [15:0] data_out
);

    // --- ??NH NGH?A H?NG S? FP16 ---
    localparam logic [15:0] FP16_ZERO    = 16'h0000; // 0.0
    localparam logic [15:0] FP16_ONE     = 16'h3C00; // 1.0
    localparam logic [15:0] FP16_NEG_ONE = 16'hBC00; // -1.0
    localparam logic [15:0] FP16_SIX     = 16'h4600; // 6.0
    localparam logic [15:0] FP16_NEG_SIX = 16'hC600; // -6.0

    // =========================================================================
    // 1. KI?M TRA NaN (D?a tr�n module c?a b?n)
    // =========================================================================
    wire is_nan_in;
    ei_fp16_is_nan check_nan (
        .x(data_in), 
        .is_nan(is_nan_in)
    );

    // =========================================================================
    // 2. G?I MODULE SO S�NH (COMPARE) 
    // =========================================================================
    wire [15:0] max_with_6;
    ei_fp16_2num_comparator comp6 (
        .a(data_in), 
        .b(FP16_SIX), 
        .max_val(max_with_6)
    );

    wire [15:0] max_with_neg6;
    ei_fp16_2num_comparator comp_neg6 (
        .a(data_in), 
        .b(FP16_NEG_SIX), 
        .max_val(max_with_neg6)
    );

    wire [15:0] max_with_0;
    ei_fp16_2num_comparator comp0 (
        .a(data_in), 
        .b(FP16_ZERO), 
        .max_val(max_with_0)
    );

    // =========================================================================
    // 3. T?O C? B�O H�A (SATURATION FLAGS)
    // =========================================================================
    // N?u max(x, 6.0) == x -> x >= 6.0 (V� ph?i lo?i tr? NaN)
    wire is_sat_pos = (max_with_6 == data_in) && !is_nan_in;
    
    // N?u max(x, -6.0) == -6.0 -> x <= -6.0 (V� ph?i lo?i tr? NaN)
    wire is_sat_neg = (max_with_neg6 == FP16_NEG_SIX) && !is_nan_in;

    // Pipeline c? b�o h�a tr? 1 chu k? ?? ??ng b? v?i ?? tr? ??c BRAM c?a LUT
    logic is_sat_pos_reg;
    logic is_sat_neg_reg;

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            is_sat_pos_reg <= 1'b0;
            is_sat_neg_reg <= 1'b0;
        end else if (en) begin
            is_sat_pos_reg <= is_sat_pos;
            is_sat_neg_reg <= is_sat_neg;
        end
    end

    // =========================================================================
    // 4. ???NG D?N LINEAR V� RELU6
    // =========================================================================
    logic [15:0] linear_out;
    logic [15:0] relu6_out;
    logic [15:0] relu6_comb;

    always_comb begin
        if (is_nan_in)
            relu6_comb = FP16_ZERO; // X? l� an to�n n?u d? li?u l?i
        else if (is_sat_pos)
            relu6_comb = FP16_SIX;   // Ch?n tr�n ? m?c 6.0
        else
            relu6_comb = max_with_0; // B?n th�n b? max_with_0 ?� c?t s?n ph?n �m (ReLU)
    end

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            linear_out <= FP16_ZERO;
            relu6_out  <= FP16_ZERO;
        end else if (en) begin
            linear_out <= data_in;
            relu6_out  <= relu6_comb;
        end
    end

    // =========================================================================
    // 5. ???NG D?N TRA B?NG LUT (10-BIT ?� N�N)
    // =========================================================================
    // �p ??a ch? xu?ng 10 bit: {bit_d?u, 9_bit_cao_nh?t_c?a_??_l?n}
    wire [9:0] lut_addr = {data_in[15], data_in[14:6]};
    
    wire [15:0] sigmoid_lut_out;
    wire [15:0] tanh_lut_out;

//    ei_activation_lut #(.INIT_FILE(SIGMOID_FILE)) u_lut_sigmoid (
//        .sys_clk (sys_clk),
//        .ce      (en),
//        .addr_in (lut_addr),
//        .data_out(sigmoid_lut_out)
//    );
    
    ei_activation_lut #(.INIT_FILE(SOFTMAX_FILE)) u_lut_softmax (
        .sys_clk (sys_clk),
        .ce      (en),
        .addr_in (lut_addr),
        .data_out(sigmoid_lut_out)
    );

    ei_activation_lut #(.INIT_FILE(TANH_FILE)) u_lut_tanh (
        .sys_clk (sys_clk),
        .ce      (en),
        .addr_in (lut_addr),
        .data_out(tanh_lut_out)
    );

    // =========================================================================
    // 6. K?T H?P B�O H�A V� LUT MUX
    // =========================================================================
    logic [15:0] final_sigmoid;
    logic [15:0] final_tanh;

    always_comb begin
//        // --- Sigmoid ---
//        if (is_sat_pos_reg)
//            final_sigmoid = FP16_ONE;
//        else if (is_sat_neg_reg)
//            final_sigmoid = FP16_ZERO;
//        else
//            final_sigmoid = sigmoid_lut_out;

        // --- Softmax ---
        if (is_sat_pos_reg)
            final_sigmoid = FP16_ONE;
        else if (is_sat_neg_reg)
            final_sigmoid = FP16_ZERO;
        else
            final_sigmoid = sigmoid_lut_out;

        // --- Tanh ---
        if (is_sat_pos_reg)
            final_tanh = FP16_ONE;
        else if (is_sat_neg_reg)
            final_tanh = FP16_NEG_ONE;
        else
            final_tanh = tanh_lut_out;
    end

    // =========================================================================
    // 7. XU?T T�N HI?U (OUTPUT SELECTOR)
    // =========================================================================
    always_comb begin
        unique case (mode)
            2'b00: data_out = linear_out;
            2'b01: data_out = relu6_out;
            2'b10: data_out = final_sigmoid;
            2'b11: data_out = final_tanh;
            default: data_out = linear_out;
        endcase
    end

    //// test
    // logic [15:0] data_in_d;
    // logic [1:0]  mode_d;

    // always_ff @(posedge sys_clk) begin
    //     if (rst) begin
    //         data_in_d <= 16'h0;
    //         mode_d    <= 2'b0;
    //     end
    //     else if (en) begin
    //         data_in_d <= data_in;
    //         mode_d    <= mode;

    //         $display("mode=%0d input=%h output=%h",
    //                 mode_d, data_in_d, data_out);
    //     end
    // end

endmodule