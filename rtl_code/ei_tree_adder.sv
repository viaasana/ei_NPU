`timescale 1ps/1ps

module ei_tree_adder (
    input  wire         sys_clk,
    input  wire         rst,
    input  wire         en,
    // 9 đầu vào FP16 riêng biệt
    input  wire [15:0]  in0, in1, in2, in3, in4, in5, in6, in7, in8,
    output wire [15:0]  sum_out
);

    // =========================================================
    // CẤU HÌNH ĐỘ TRỄ
    // =========================================================
    // Mỗi bộ cộng ei_adder_fp16 có latency = 4
    localparam ADDER_LATENCY = 4;
    
    // Input 8 cần chờ qua 3 tầng cộng (L1, L2, L3) = 12 cycles
    // Ta sẽ dùng một chuỗi các thanh ghi để delay đúng số cycle này.
    localparam IN8_DELAY_CYCLES = 3 * ADDER_LATENCY; // = 12

    // =========================================================
    // TẦNG 1: Cộng 8 đầu vào đầu tiên (4 bộ cộng)
    // Latency tích lũy: 4
    // =========================================================
    wire [15:0] l1_sum01, l1_sum23, l1_sum45, l1_sum67;

    ei_adder_fp16 u_add_l1_0 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(in0), .b_in(in1), .sum_out(l1_sum01));
    ei_adder_fp16 u_add_l1_1 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(in2), .b_in(in3), .sum_out(l1_sum23));
    ei_adder_fp16 u_add_l1_2 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(in4), .b_in(in5), .sum_out(l1_sum45));
    ei_adder_fp16 u_add_l1_3 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(in6), .b_in(in7), .sum_out(l1_sum67));

    // =========================================================
    // TẦNG 2: Cộng kết quả tầng 1 (2 bộ cộng)
    // Latency tích lũy: 4 + 4 = 8
    // =========================================================
    wire [15:0] l2_sum_A, l2_sum_B;

    ei_adder_fp16 u_add_l2_0 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(l1_sum01), .b_in(l1_sum23), .sum_out(l2_sum_A));
    ei_adder_fp16 u_add_l2_1 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(l1_sum45), .b_in(l1_sum67), .sum_out(l2_sum_B));

    // =========================================================
    // TẦNG 3: Cộng kết quả tầng 2 (1 bộ cộng)
    // Latency tích lũy: 8 + 4 = 12
    // =========================================================
    wire [15:0] l3_sum_0to7;

    ei_adder_fp16 u_add_l3_0 (.sys_clk(sys_clk), .rst(rst), .en(en), .a_in(l2_sum_A), .b_in(l2_sum_B), .sum_out(l3_sum_0to7));

    // =========================================================
    // DELAY LINE CHO INPUT 8 (SỬ DỤNG MODULE regN)
    // =========================================================
    // Cần delay đúng 12 chu kỳ clock.
    // Ta tạo một chuỗi nối tiếp các dây: delay_wire[0] -> delay_wire[12]
    
    wire [15:0] delay_stage [0:IN8_DELAY_CYCLES]; // 0..12
    
    assign delay_stage[0] = in8; // Đầu vào chuỗi delay

    genvar i;
    generate
        for (i = 0; i < IN8_DELAY_CYCLES; i = i + 1) begin : gen_delay_line
            regN #(.WIDTH(16)) u_delay_reg (
                .clk (sys_clk),
                .rst (rst),
                .en  (en),
                .d   (delay_stage[i]),
                .q   (delay_stage[i+1])
            );
        end
    endgenerate

    // Đầu ra sau khi đã trễ đúng 12 chu kỳ
    wire [15:0] in8_delayed = delay_stage[IN8_DELAY_CYCLES];

    // =========================================================
    // TẦNG 4 (FINAL): Cộng Sum(0..7) với Input 8 (đã delay)
    // Latency tích lũy: 12 + 4 = 16
    // =========================================================
    
    ei_adder_fp16 u_add_l4_final (
        .sys_clk(sys_clk), .rst(rst), .en(en),
        .a_in(l3_sum_0to7), 
        .b_in(in8_delayed), // Bây giờ tín hiệu này đã đồng bộ hoàn hảo với l3_sum_0to7
        .sum_out(sum_out)
    );

endmodule