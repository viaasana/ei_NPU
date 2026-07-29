`timescale 1ns / 1ps

module ei_NPU#(
    parameter NUM_PE = 16
)(
    input  logic sys_clk,
    input  logic rst,

    // ==========================================
    // 1. CPU / System Control Interface (MMIO Bus)
    // ==========================================
    input  logic        bus_write_en,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_write_data,
    output logic        done,

    // ==========================================
    // 2. Memory Interface: Feature Map (Read)
    // ==========================================
    output logic        fm_mem_read_en,
    output logic [31:0] fm_mem_addr,
    input  logic [255:0] fm_mem_read_data, // [CẬP NHẬT]: �?�?c 1 lần 16 phần tử 16-bit = 256 bits

    // ==========================================
    // 3. Memory Interface: Weights & Bias (Read)
    // ==========================================
    output logic        w_mem_read_en,
    output logic [31:0] w_mem_addr,
    input  logic [159:0] w_mem_read_data,

    // ==========================================
    // 4. Memory Interface: Output Feature Map (Write)
    // ==========================================
    output logic [31:0] out_mem_write_en,
    output logic [31:0] out_mem_write_addr, 
    output logic [255:0] out_mem_write_data  
);

    // =========================================================================
    // KHAI B�?O DÂY KẾT N�?I NỘI BỘ (INTERNAL WIRES)
    // =========================================================================
    
    // Dây tín hiệu từ CSR Block
    logic npu_start_wire;
    logic is_pooling_op_wire;
    logic [1:0]  csr_pool_mode_wire;
    logic [1:0]  csr_act_mode_wire;
    logic [15:0] reg_max_x_wire, reg_max_y_wire, reg_max_c_wire, reg_max_k_wire;

    // Dây từ Controller -> Các khối khác
    logic [NUM_PE-1:0] valid_in_wire;
    logic [NUM_PE-1:0] acc_clear_wire;
    logic [NUM_PE-1:0] final_ic_wire;
    logic feed_done;
    logic writeback_done;
    
    // Dây cấu hình động cấp cho PE Array
    logic [1:0]  pool_mode_wire [0:NUM_PE-1];
    logic [15:0] const_pool_wire [0:NUM_PE-1];
    logic [1:0]  act_mode_wire [0:NUM_PE-1];
    logic [0:NUM_PE-1]  ready_all_wire;

    // Dây Datapath
    logic [15:0] x_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] w_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] b_to_pe [0:NUM_PE-1];
    logic [15:0]       pe_sum_wire [0:NUM_PE-1];
    logic [NUM_PE-1:0] conv_valid_out_wire;
    logic [NUM_PE-1:0] pool_valid_out_wire;
    logic [NUM_PE-1:0] pe_valid_out_wire;
    logic [15:0]       pe_conv_out [0:NUM_PE-1];
    logic [15:0]       pe_pool_out [0:NUM_PE-1];

    // Dây chứa Window Data (3x3) từ Controller mới xuất ra
    logic [15:0] pe_fm_data_wire [0:NUM_PE-1][0:2][0:2];

    // Dây phụ trợ cắt bus dữ liệu Weight
    logic [15:0] parsed_weight [0:8];
    
    genvar i;
    generate
        for (i = 0; i < 9; i++) begin : PARSE_WEIGHTS
            assign parsed_weight[i] = w_mem_read_data[i*16 +: 16];
        end
    endgenerate

    // =========================================================================
    // KHỞI TẠO C�?C MODULE CON (INSTANTIATIONS)
    // =========================================================================

    // ---------------------------------------------------------
    // 0. Control & Status Register (CSR Block)
    // ---------------------------------------------------------
    npu_csr_block u_csr (
        .sys_clk       (sys_clk),
        .sys_rst       (rst),
        
        .bus_write_en  (bus_write_en),
        .bus_addr      (bus_addr),
        .bus_write_data(bus_write_data),
        
        .npu_start     (npu_start_wire),
        .pool_mode     (csr_pool_mode_wire),
        .act_mode      (csr_act_mode_wire),
        .is_pooling_op (is_pooling_op_wire),
        
        .reg_max_x     (reg_max_x_wire),
        .reg_max_y     (reg_max_y_wire),
        .reg_max_c     (reg_max_c_wire),
        .reg_max_k     (reg_max_k_wire),
        
        .npu_done      (done)
    );

    // ---------------------------------------------------------
    // 1. Controller (Bộ Não - Tích hợp Data Router mới)
    // ---------------------------------------------------------
    ei_pe_controller #(
        .NUM_PE(NUM_PE) 
    ) u_controller (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        
        // Tín hiệu từ CSR
        .start               (npu_start_wire),
        .reg_max_x           (reg_max_x_wire),
        .reg_max_y           (reg_max_y_wire),
        .reg_max_c           (reg_max_c_wire),
        .reg_max_k           (reg_max_k_wire),
        .csr_act_mode        (csr_act_mode_wire),
        .csr_pool_mode       (csr_pool_mode_wire),
        .done                (feed_done),
        
        // Giao tiếp hệ thống & BRAM
        .ready_all           (ready_all_wire[0]), 
        .fm_mem_read_en      (fm_mem_read_en),
        .fm_mem_addr         (fm_mem_addr),
        .fm_bram_read_data   (fm_mem_read_data), // Nạp nguyên block 256-bit vào Controller
        
        .w_mem_read_en       (w_mem_read_en),
        .w_mem_addr          (w_mem_addr),
        
        // �?i�?u khiển luồng nội bộ
        .valid_in            (valid_in_wire),
        .acc_clear           (acc_clear_wire),
        .final_input_channel (final_ic_wire),
        
        // Cấu hình xuất ra PE
        .pool_mode           (pool_mode_wire),
        .const_pool          (const_pool_wire),
        .act_mode            (act_mode_wire),
        
        // Dữ liệu cấp trực tiếp cho PE (Data Router)
        .pe_fm_data          (pe_fm_data_wire)
    );

    // ---------------------------------------------------------
    // 2. Data Muxing & Broadcast Logic (Thay thế cho ei_pe_get_data cũ)
    // ---------------------------------------------------------
    always_comb begin
        for (int p = 0; p < NUM_PE; p++) begin
            // Broadcast Bias cho tất cả các PE
            b_to_pe[p] = w_mem_read_data[159:144];
            
            // Flatten mảng 3x3 Feature Map từ Router thành mảng 1D [0:8] cho PE 
            // và Broadcast Weight [0:8]
            for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                    x_to_pe[p][r*3 + c] = pe_fm_data_wire[p][r][c];
                    w_to_pe[p][r*3 + c] = parsed_weight[r*3 + c];
                end
            end
        end
    end

    // ---------------------------------------------------------
    // 3. PE Array (Bộ Cơ Bắp - Tính toán)
    // ---------------------------------------------------------
    ei_pe_array #(
        .NUM_PE(NUM_PE)
    ) u_pe_array (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        .en                  (1'b1), 
        
        .valid_in            (valid_in_wire),
        .pool_mode           (pool_mode_wire),
        .const_pool          (const_pool_wire),
        .act_mode            (act_mode_wire),
        .acc_clear           (acc_clear_wire),
        .final_input_channel (final_ic_wire),
        
        .bias_in             (b_to_pe),
        .x_in                (x_to_pe),
        .w_in                (w_to_pe),
        
        .sum_out             (pe_conv_out),
        .valid_out           (pool_valid_out_wire),
        
        .ready_in_per_pe     (), 
        .ready_all           (ready_all_wire[0]),
        .final_input_channel_valid_out (conv_valid_out_wire),
        .pe_sum_out          (pe_pool_out)
    );
    
    genvar pe_i;
    generate
        for(pe_i = 0; pe_i < NUM_PE; pe_i = pe_i + 1) begin : GEN_OUTPUT_MUX
            ei_muxN #(
                .WIDTH(16)
            ) u_select_out (
                .d0(pe_conv_out[pe_i]),
                .d1(pe_pool_out[pe_i]),
                .s (csr_pool_mode_wire[1]),
                .y (pe_sum_wire[pe_i])
            );
        end

        for(pe_i = 0; pe_i < NUM_PE; pe_i = pe_i + 1) begin : GEN_VALID_OUT_MUX
            ei_muxN #(
                .WIDTH(1)
            ) u_select_valid (
                .d0(conv_valid_out_wire[pe_i]),
                .d1(pool_valid_out_wire[pe_i]),
                .s (csr_pool_mode_wire[1]),
                .y (pe_valid_out_wire[pe_i])
            );
        end
    endgenerate

    // ---------------------------------------------------------
    // 4. Write-Back Controller (Bộ Ghi Dữ Liệu)
    // ---------------------------------------------------------
    ei_pe_write_back_controller #(
        .NUM_PE(NUM_PE)
    ) u_write_back (
        .sys_clk             (sys_clk),
        .rst                 (rst),
        
        // Kích thước động từ CSR
        .reg_max_x           (reg_max_x_wire),
        .reg_max_y           (reg_max_y_wire),
        .reg_max_k           (reg_max_k_wire),
        
        .pe_valid_out        (pe_valid_out_wire[0]), 
        .pe_sum_out          (pe_sum_wire),
        
        .write_enable        (out_mem_write_en),
        .write_base_address  (out_mem_write_addr),
        .write_data_bus      (out_mem_write_data),
        .done                (writeback_done)
    );

    always_comb begin
        done = writeback_done;
    end

    // always @(posedge sys_clk) begin
    //     if(conv_valid_out_wire[0])
    //         $display("[ei_NPU] [valid out] pool modeL: %0h sum_out: %0h", csr_pool_mode_wire[0], pe_sum_wire[0]);
    // end
    
endmodule