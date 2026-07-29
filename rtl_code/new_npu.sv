`timescale 1ns / 1ps

module npu_top #(
    parameter DATA_WIDTH   = 16,
    parameter WEIGHT_WIDTH = 16,
    parameter OUT_WIDTH    = 16,
    parameter NUM_PE       = 16,
    parameter AXI_ADDR_W   = 32,
    parameter AXI_DATA_W   = 32
)(
    input  logic sys_clk,
    input  logic sys_rst_n, // AXI thường dùng reset tích cực mức thấp (active-low)

    // ==========================================
    // 1. AXI4-Lite Interface (Dành cho Cấu hình - Config)
    // ==========================================
    // Write Address Channel
    input  logic [AXI_ADDR_W-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,
    // Write Data Channel
    input  logic [AXI_DATA_W-1:0] s_axi_wdata,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,
    // Write Response Channel
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,
    // Read Address Channel
    input  logic [AXI_ADDR_W-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,
    // Read Data Channel
    output logic [AXI_DATA_W-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    // ==========================================
    // 2. AXI4-Stream Interface: INPUT DATA (Từ DMA)
    // ==========================================
    input  logic [47:0]           s_axis_data_tdata,  // Đọc 3 pixel 16-bit cùng lúc
    input  logic                  s_axis_data_tvalid,
    output logic                  s_axis_data_tready,
    input  logic                  s_axis_data_tlast,  // Báo hiệu kết thúc 1 frame/hàng

    // ==========================================
    // 3. AXI4-Stream Interface: INPUT WEIGHT (Từ DMA)
    // ==========================================
    input  logic [159:0]          s_axis_weight_tdata, // Đọc 9 weight + 1 bias
    input  logic                  s_axis_weight_tvalid,
    output logic                  s_axis_weight_tready,
    input  logic                  s_axis_weight_tlast,

    // ==========================================
    // 4. AXI4-Stream Interface: OUTPUT RESULT (Đẩy ra DMA)
    // ==========================================
    output logic [255:0]          m_axis_out_tdata,    // 16 PE x 16-bit
    output logic                  m_axis_out_tvalid,
    input  logic                  m_axis_out_tready,
    output logic                  m_axis_out_tlast,
    
    // Interrupt
    output logic                  irq_done
);

    // =========================================================================
    // KHAI BÁO DÂY KẾT NỐI NỘI BỘ
    // =========================================================================
    
    // Tín hiệu cấu hình từ AXI-Lite Wrapper
    logic        start_npu;
    logic [15:0] reg_max_x, reg_max_y, reg_max_c, reg_max_k;
    logic [1:0]  reg_pool_mode, reg_act_mode;

    // Tín hiệu từ FIFO đi vào Scheduler
    logic        data_fifo_empty, weight_fifo_empty;
    logic        data_fifo_read, weight_fifo_read;
    logic [47:0] data_from_fifo;
    logic [159:0] weight_from_fifo;

    // Tín hiệu từ Scheduler đi vào PE Array
    logic [15:0] x_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] w_to_pe [0:NUM_PE-1][0:8];
    logic [15:0] b_to_pe [0:NUM_PE-1];
    logic [NUM_PE-1:0] valid_in_to_pe;
    logic        acc_clear;
    logic        final_ic;
    
    // Tín hiệu từ PE Array đi ra Output FIFO
    logic [15:0] pe_out_data [0:NUM_PE-1];
    logic [NUM_PE-1:0] pe_out_valid;
    
    // Tín hiệu đóng gói ghi vào Output FIFO
    logic        out_fifo_write;
    logic        out_fifo_full;
    logic [255:0] data_to_out_fifo;

    // =========================================================================
    // INSTANTIATION CÁC MODULE CON (ROADMAP)
    // =========================================================================

    // 1. Khối cấu hình AXI-Lite (Thay thế u_csr cũ)
    // Nhận lệnh từ CPU và xuất ra các thanh ghi cấu hình (start, max_x, max_y...)
    /*
    npu_axi_lite_slave u_axi_lite_slave (
        ...
    );
    */

    // 2. Data Input FIFO
    // Chuyển đổi chuẩn AXI-Stream (TVALID, TREADY) thành chuẩn FIFO cơ bản (empty, read)
    /*
    axis_to_fifo #( .WIDTH(48) ) u_data_fifo (
        ...
    );
    */

    // 3. Weight Input FIFO
    /*
    axis_to_fifo #( .WIDTH(160) ) u_weight_fifo (
        ...
    );
    */

    // 4. Scheduler (Bộ não mới - Thay thế Controller & Data Feeder cũ)
    // Đọc FIFO -> Phân tách dữ liệu -> Đẩy vào PE
    /*
    npu_scheduler #( .NUM_PE(NUM_PE) ) u_scheduler (
        ...
    );
    */

    // 5. PE Array (Bộ cơ bắp - Cơ bản giữ nguyên, chỉ sửa lại tín hiệu giao tiếp)
    /*
    ei_pe_array #( .NUM_PE(NUM_PE) ) u_pe_array (
        ...
    );
    */

    // 6. Output FIFO
    // Nhận dữ liệu từ PE -> Lưu vào FIFO -> Đẩy ra chuẩn AXI-Stream
    /*
    fifo_to_axis #( .WIDTH(256) ) u_output_fifo (
        ...
    );
    */

endmodule