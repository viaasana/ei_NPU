`timescale 1ns/1ps

module ei_mac_fp16 #(
    parameter LATENCY_MUL = 4 // Độ trễ của bộ nhân (Phải khớp với ei_multiplier_fp16)
)(
    input          sys_clk,
    input          rst,       // Sync reset, active-high
    input          en,
    input  [15:0]  a_in,      // Input A
    input  [15:0]  b_in,      // Input B
    input  [15:0]  c_in,      // Input C (Số hạng cộng)
    output [15:0]  mac_out    // Result = (A * B) + C
);

    // =================================================================
    // 1. MULTIPLIER INSTANCE (A * B)
    // =================================================================
    wire [15:0] prod_result;

    ei_multiplier_fp16 u_multiplier (
        .sys_clk (sys_clk),
        .rst     (rst),
        .en      (en),
        .a_in    (a_in),
        .b_in    (b_in),
        .c_out   (prod_result) // Kết quả này bị trễ 3 clock
    );

    // =================================================================
    // 2. DELAY LINE FOR C (Shift Register)
    // =================================================================
    // Cần giữ giá trị C lại đúng bằng thời gian bộ nhân chạy (LATENCY_MUL)
    // Sử dụng generate để tạo chuỗi thanh ghi linh hoạt
    
    wire [15:0] c_delay_wire [0:LATENCY_MUL];
    
    assign c_delay_wire[0] = c_in; // Đầu vào chuỗi delay

    genvar i;
    generate
        for (i = 0; i < LATENCY_MUL; i = i + 1) begin : C_DELAY_CHAIN
            regN #(.WIDTH(16)) u_reg_c_delay (
                .clk (sys_clk),
                .rst (rst),
                .en  (en),
                .d   (c_delay_wire[i]),
                .q   (c_delay_wire[i+1])
            );
        end
    endgenerate

    // Lấy C sau khi đã delay đủ số nhịp
    wire [15:0] c_aligned = c_delay_wire[LATENCY_MUL];

    // =================================================================
    // 3. ADDER INSTANCE (Product + C_aligned)
    // =================================================================
    // Adder này có latency riêng (ví dụ 4 clock), nhưng không ảnh hưởng
    // đến việc đồng bộ ngõ vào của nó.
    
    ei_adder_fp16 u_adder (
        .sys_clk (sys_clk),
        .rst     (rst),
        .en      (en),
        .a_in    (prod_result), // Kết quả nhân
        .b_in    (c_aligned),   // C đã đồng bộ
        .sum_out (mac_out)      // Kết quả cuối cùng
    );

endmodule