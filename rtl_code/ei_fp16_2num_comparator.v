`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 10:30:04 AM
// Design Name: 
// Module Name: fp16_2num_comparator
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

module ei_fp16_2num_comparator#(
    parameter WIDTH = 16
)(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    output [WIDTH-1:0] max_val
);

    // =========================================================================
    // LUỒNG 1: KIỂM TRA NaN (Chạy song song)
    // =========================================================================
    wire nan_a, nan_b;
    
    // Gọi module của bạn vào đây
    ei_fp16_is_nan check_nan_a (.x(a), .is_nan(nan_a));
    ei_fp16_is_nan check_nan_b (.x(b), .is_nan(nan_b));


    // =========================================================================
    // LUỒNG 2: SO SÁNH ĐỘ LỚN BẰNG "TUYỆT CHIÊU 15-BIT" (Chạy song song)
    // =========================================================================
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [14:0] mag_a = a[14:0];
    wire [14:0] mag_b = b[14:0];
    
    reg [WIDTH-1:0] normal_max;

    always @(*) begin
        case({sign_a, sign_b})
            2'b01: normal_max = a; // a dương, b âm
            2'b10: normal_max = b; // a âm, b dương
            2'b00: normal_max = (mag_a >= mag_b) ? a : b; // Cùng dương
            2'b11: normal_max = (mag_a <= mag_b) ? a : b; // Cùng âm
            default: normal_max = a; // Chống sinh chốt (latch)
        endcase
    end

    assign max_val = nan_a ? b : 
                     nan_b ? a : 
                     normal_max;

endmodule