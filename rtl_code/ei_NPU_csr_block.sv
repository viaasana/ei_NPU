`timescale 1ns/1ps

module npu_csr_block (
    input  logic        sys_clk,
    input  logic        sys_rst,

    // ==========================================
    // Giao tiếp Bus Đơn giản (Đại diện cho AXI4-Lite/APB)
    // ==========================================
    input  logic        bus_write_en,
    input  logic [31:0] bus_addr,      // Địa chỉ ghi
    input  logic [31:0] bus_write_data,// Dữ liệu cấu hình từ phần mềm
    
    // (Tùy chọn) Có thể thêm bus_read để phần mềm đọc trạng thái

    // ==========================================
    // Tín hiệu xuất ra cho Controller và PE Array
    // ==========================================
    output logic        npu_start,
    output logic [1:0]  pool_mode,
    output logic [1:0]  act_mode,
    output logic        is_pooling_op, // 1: Chạy Max/Avg Pool, 0: Chạy Conv
    output logic [15:0] reg_max_x,
    output logic [15:0] reg_max_y,
    output logic [15:0] reg_max_c,
    output logic [15:0] reg_max_k,

    // Tín hiệu từ Controller phản hồi về (Read-only)
    input  logic        npu_done
);

    // Khai báo các thanh ghi vật lý nội bộ
    logic [31:0] cmd_reg;
    logic [31:0] cfg_reg;
    logic [31:0] dim_reg_1;
    logic [31:0] dim_reg_2;

    // 1. Quá trình GHI cấu hình từ Phần mềm (CPU) vào NPU
    always_ff @(posedge sys_clk) begin
        if (sys_rst) begin
            cmd_reg   <= 32'd0;
            cfg_reg   <= 32'd0;
            dim_reg_1 <= 32'd0; // Bạn có thể gán giá trị mặc định (VD: 32x32)
            dim_reg_2 <= 32'd0;
        end else begin
            // Xóa xung start (chỉ giữ 1 chu kỳ để kích hoạt FSM)
            cmd_reg[0] <= 1'b0; 

            if (bus_write_en) begin
                case (bus_addr[7:0]) // Lấy 8 bit cuối của địa chỉ để giải mã
                    8'h00: cmd_reg   <= bus_write_data;
                    8'h04: cfg_reg   <= bus_write_data;
                    8'h08: dim_reg_1 <= bus_write_data;
                    8'h0C: dim_reg_2 <= bus_write_data;
                    default: ; // Không làm gì cả
                endcase
            end
        end
    end

    // 2. Trích xuất (Slice) các bit cấu hình đưa ra ngoài hệ thống
    assign npu_start     = cmd_reg[0];
    
    // Trích xuất cấu hình (CFG_REG)
    assign pool_mode     = cfg_reg[1:0]; // 2 bit đầu
    assign act_mode      = cfg_reg[3:2]; // 2 bit tiếp theo
    assign is_pooling_op = cfg_reg[4];   // 1 bit
    
    // Trích xuất kích thước (DIM_REG_1 & DIM_REG_2)
    assign reg_max_x     = dim_reg_1[15:0];
    assign reg_max_y     = dim_reg_1[31:16];
    assign reg_max_c     = dim_reg_2[15:0];
    assign reg_max_k     = dim_reg_2[31:16];

    always @(posedge sys_clk) begin
        if(npu_start)
            $display("[CSR block] reg_max_x: %0d, reg_max_y: %0d, reg_max_c: %0d, reg_max_k: %0d", reg_max_x, reg_max_y, reg_max_c, reg_max_k);
    end

endmodule