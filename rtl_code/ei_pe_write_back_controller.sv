`timescale 1ns / 1ps

module ei_pe_write_back_controller #(
    parameter NUM_PE = 16
)(
    input  logic sys_clk,
    input  logic rst,
    input  logic start, 

    // Kích thước động nhận từ khối CSR
    input  logic [15:0] reg_max_x,
    input  logic [15:0] reg_max_y,
    input  logic [15:0] reg_max_k, 

    // Tín hiệu từ PE Array
    input  logic pe_valid_out, 
    input  logic [15:0] pe_sum_out [0:NUM_PE-1],

    // Giao tiếp với bộ nhớ SRAM Output
    output logic [31:0]          write_enable, 
    output logic [31:0]          write_base_address, 
    output logic [(NUM_PE*16)-1:0] write_data_bus,

    output logic done      
);

    // ==========================================================
    // 1. Linear Address Counter & Shadow Coordinates
    // ==========================================================
    logic [31:0] current_chunk_idx;
    logic [15:0] out_x;
    logic [15:0] out_y;
    logic [15:0] out_k;

    always_ff @(posedge sys_clk) begin
        if (rst || start) begin
            current_chunk_idx <= 0;
            out_x <= 0;
            out_y <= 0;
            out_k <= 0;
            done  <= 1'b0;
        end else if (pe_valid_out) begin
            current_chunk_idx <= current_chunk_idx + 1;
            
            // ĐÃ FIX LỖI UNDERFLOW BẰNG PHÉP CỘNG
            if ((out_x + NUM_PE) >= reg_max_x) begin
                out_x <= 0; 
                
                if (out_y == reg_max_y - 1) begin
                    out_y <= 0; 
                    
                    if (out_k == reg_max_k - 1) begin
                        out_k <= 0; 
                        done  <= 1'b1; // Phát cờ done ngay tại nhịp cuối cùng
                    end else begin
                        out_k <= out_k + 1;
                    end
                end else begin
                    out_y <= out_y + 1; 
                end
            end else begin
                out_x <= out_x + NUM_PE; 
            end
        end else begin
            // Chỉ xóa done khi không có valid_out
            done <= 1'b0;
        end
    end

    // ==========================================================
    // 2. Tạo Mask an toàn (Tránh lỗi dịch bit << 32)
    // ==========================================================
    logic [31:0] mask_in;
    logic [15:0] valid_pe_count;
    
    always_comb begin
        if (out_x + NUM_PE > reg_max_x) begin
            valid_pe_count = reg_max_x - out_x;
            mask_in = (32'h1 << (valid_pe_count * 2)) - 1;
        end else begin
            // Bật toàn bộ 32 bit Write Enable cho 16 PE
            mask_in = 32'hFFFF_FFFF;
        end
    end

    // ==========================================================
    // 3. Đóng gói dữ liệu và Ghi thẳng ra RAM
    // ==========================================================
    logic [(NUM_PE*16)-1:0] packed_data_in;
    genvar i;
    generate
        for (i = 0; i < NUM_PE; i++) begin : PACK_WRITE_DATA
            assign packed_data_in[(i*16) +: 16] = pe_sum_out[i];
        end
    endgenerate

    // Mạch tổ hợp ghi ngay lập tức không cần trễ (Zero Delay)
    assign write_enable       = pe_valid_out ? mask_in : 32'h0000_0000;
    assign write_base_address = current_chunk_idx << 5; // << 5 chuẩn Vivado Byte-address
    assign write_data_bus     = packed_data_in;

endmodule