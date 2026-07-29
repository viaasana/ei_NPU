`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 02:52:23 PM
// Design Name: 
// Module Name: ei_pe_get_data
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
module ei_pe_get_data #(
    parameter int NUM_PE = 16
)(
    input  logic sys_clk,
    input  logic rst,

    // ==========================================
    // Tín hiệu điều khiển từ Controller
    // ==========================================
    input  logic shift_en, // Cho phép dịch dữ liệu (bơm dữ liệu mới)

    // ==========================================
    // Dữ liệu luồng (Streaming Data) từ Controller/Line Buffers
    // ==========================================
    // Controller đọc SRAM và cấp 3 pixel của 1 cột (tương ứng 3 hàng của cửa sổ 3x3)
    input  logic [15:0] fm_row_0_in, 
    input  logic [15:0] fm_row_1_in, 
    input  logic [15:0] fm_row_2_in, 

    // Controller cấp 9 Weight và 1 Bias cho toàn bộ PEs (Giữ nguyên trong lúc tính 1 Channel)
    input  logic [15:0] weight_in [0:8],
    input  logic [15:0] bias_in,

    // ==========================================
    // Ngõ ra kết nối trực tiếp vào ei_pe_array
    // ==========================================
    // Mảng 2 chiều: [PE_Index][Input_Index]
    output logic [15:0] x_out [0:NUM_PE-1][0:8],
    output logic [15:0] w_out [0:NUM_PE-1][0:8],
    output logic [15:0] b_out [0:NUM_PE-1]
);

    // ---------------------------------------------------------
    // Khai báo Mảng Thanh ghi dịch (Shift Registers)
    // Cửa sổ 3x3 và 16 PE -> Cần thanh ghi độ dài 16 + 3 - 1 = 18 cho mỗi hàng
    // ---------------------------------------------------------
    localparam SR_LENGTH = NUM_PE + 2; 

    logic [15:0] sr_row_0 [0:SR_LENGTH-1];
    logic [15:0] sr_row_1 [0:SR_LENGTH-1];
    logic [15:0] sr_row_2 [0:SR_LENGTH-1];

    // ---------------------------------------------------------
    // Khối Sequential: Dịch dữ liệu mỗi nhịp Clock
    // ---------------------------------------------------------
    always_ff @(posedge sys_clk) begin
        if (rst) begin
            for (int i = 0; i < SR_LENGTH; i++) begin
                sr_row_0[i] <= 16'd0;
                sr_row_1[i] <= 16'd0;
                sr_row_2[i] <= 16'd0;
            end
        end else if (shift_en) begin
            // Đẩy pixel mới vào vị trí cuối cùng (bên phải)
            sr_row_0[SR_LENGTH-1] <= fm_row_0_in;
            sr_row_1[SR_LENGTH-1] <= fm_row_1_in;
            sr_row_2[SR_LENGTH-1] <= fm_row_2_in;

            // Dịch toàn bộ dữ liệu cũ sang trái 1 bước
            for (int i = 0; i < SR_LENGTH-1; i++) begin
                sr_row_0[i] <= sr_row_0[i+1];
                sr_row_1[i] <= sr_row_1[i+1];
                sr_row_2[i] <= sr_row_2[i+1];
            end
        end
    end

    // ---------------------------------------------------------
    // Khối Tổ hợp (Generate): Trích xuất Data và Broadcast
    // ---------------------------------------------------------
    genvar p;
    generate
        for (p = 0; p < NUM_PE; p++) begin : ASSIGN_DATA_TO_PE
            
            // 1. Chia Data Feature Map (Tái sử dụng dữ liệu chồng chéo)
            // PE[p] sẽ lấy 3 cột bắt đầu từ vị trí p
            
            // --- Hàng 0 ---
            assign x_out[p][0] = sr_row_0[p];     // Cột trái
            assign x_out[p][1] = sr_row_0[p+1];   // Cột giữa
            assign x_out[p][2] = sr_row_0[p+2];   // Cột phải

            // --- Hàng 1 ---
            assign x_out[p][3] = sr_row_1[p];
            assign x_out[p][4] = sr_row_1[p+1];
            assign x_out[p][5] = sr_row_1[p+2];

            // --- Hàng 2 ---
            assign x_out[p][6] = sr_row_2[p];
            assign x_out[p][7] = sr_row_2[p+1];
            assign x_out[p][8] = sr_row_2[p+2];

            // 2. Broadcast Weights (Phát 9 weight chung cho toàn bộ PE)
            assign w_out[p][0] = weight_in[0];
            assign w_out[p][1] = weight_in[1];
            assign w_out[p][2] = weight_in[2];
            assign w_out[p][3] = weight_in[3];
            assign w_out[p][4] = weight_in[4];
            assign w_out[p][5] = weight_in[5];
            assign w_out[p][6] = weight_in[6];
            assign w_out[p][7] = weight_in[7];
            assign w_out[p][8] = weight_in[8];

            // 3. Broadcast Bias
            assign b_out[p] = bias_in;

        end
    endgenerate

endmodule