`timescale 1ns / 1ps

module ei_axi_data_mover #(
    parameter C_M_AXI_ADDR_WIDTH = 32,
    parameter C_M_AXI_DATA_WIDTH = 256
)(
    input  logic sys_clk,
    input  logic rst,

    // ==========================================
    // CSR & Control Inputs
    // ==========================================
    input  logic [15:0] reg_max_x,
    input  logic [15:0] reg_max_y,
    input  logic [15:0] reg_max_c,
    input  logic [15:0] reg_max_k,
    input  logic        npu_start,

    // ==========================================
    // Controller Interface (Line Buffers)
    // ==========================================
    output logic        lb_data_ready,
    input  logic        req_next_data,
    
    // Line Buffer outputs (Flattened for Controller)
    output logic [15:0] lb_window_left  [0:2][0:15],
    output logic [15:0] lb_window_right [0:2][0:15],
    output logic [159:0] current_weight_bias,

    // ==========================================
    // Write-Back Interface
    // ==========================================
    input  logic        wb_req,
    input  logic [31:0] wb_addr,
    input  logic [255:0] wb_data,

    // ==========================================
    // AXI4 Master Interface Ports
    // ==========================================
    // (AR, R, AW, W, B channels matched with top module)
    output logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                    m_axi_arlen,
    output logic [2:0]                    m_axi_arsize,
    output logic [1:0]                    m_axi_arburst,
    output logic                          m_axi_arvalid,
    input  logic                          m_axi_arready,

    input  logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]                    m_axi_rresp,
    input  logic                          m_axi_rlast,
    input  logic                          m_axi_rvalid,
    output logic                          m_axi_rready,

    output logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]                    m_axi_awlen,
    output logic [2:0]                    m_axi_awsize,
    output logic [1:0]                    m_axi_awburst,
    output logic                          m_axi_awvalid,
    input  logic                          m_axi_awready,

    output logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic                          m_axi_wlast,
    output logic                          m_axi_wvalid,
    input  logic                          m_axi_wready,

    input  logic [1:0]                    m_axi_bresp,
    input  logic                          m_axi_bvalid,
    output logic                          m_axi_bready
);

    // =========================================================
    // 1. MEMORY MAP BASES (Hardcoded or from CSR)
    // =========================================================
    localparam BASE_ADDR_FM     = 32'h1000_0000;
    localparam BASE_ADDR_WEIGHT = 32'h2000_0000;

    // =========================================================
    // 2. INTERNAL REGISTERS & BUFFERS
    // =========================================================
    // Represents the 3 rows of the Line Buffer
    logic [255:0] line_buffer_0;
    logic [255:0] line_buffer_1;
    logic [255:0] line_buffer_2;

    // Unpacking logic to match Controller interface
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            lb_window_left[0][i]  = line_buffer_0[i*16 +: 16];
            lb_window_left[1][i]  = line_buffer_1[i*16 +: 16];
            lb_window_left[2][i]  = line_buffer_2[i*16 +: 16];
            
            // In a full circular buffer, right window comes from next burst
            // Simplified here for structural mapping
            lb_window_right[0][i] = 16'd0; 
            lb_window_right[1][i] = 16'd0;
            lb_window_right[2][i] = 16'd0;
        end
    end

    // =========================================================
    // 3. READ FSM (Fetch Weights & Feature Maps)
    // =========================================================
    typedef enum logic [3:0] {
        R_IDLE,
        R_CALC_ADDR,
        R_REQ_WEIGHT,
        R_WAIT_WEIGHT,
        R_REQ_ROW_0,
        R_WAIT_ROW_0,
        R_REQ_ROW_1,
        R_WAIT_ROW_1,
        R_REQ_ROW_2,
        R_WAIT_ROW_2,
        R_DATA_READY,
        R_WAIT_NEXT
    } read_state_t;

    read_state_t r_state, r_next;
    
    // Address tracking
    logic [31:0] current_ic_offset;
    
    always_ff @(posedge sys_clk) begin
        if (rst) r_state <= R_IDLE;
        else     r_state <= r_next;
    end

    always_comb begin
        r_next = r_state;
        m_axi_arvalid = 1'b0;
        m_axi_rready  = 1'b0;
        lb_data_ready = 1'b0;

        case (r_state)
            R_IDLE: begin
                if (npu_start) r_next = R_CALC_ADDR;
            end

            R_CALC_ADDR: begin
                r_next = R_REQ_WEIGHT;
            end

            // --- Fetch Weights ---
            R_REQ_WEIGHT: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) r_next = R_WAIT_WEIGHT;
            end
            
            R_WAIT_WEIGHT: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid) r_next = R_REQ_ROW_0;
            end

            // --- Fetch Feature Map Row 0 ---
            R_REQ_ROW_0: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) r_next = R_WAIT_ROW_0;
            end
            
            R_WAIT_ROW_0: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid && m_axi_rlast) r_next = R_REQ_ROW_1;
            end

            // --- Fetch Feature Map Row 1 ---
            R_REQ_ROW_1: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) r_next = R_WAIT_ROW_1;
            end
            
            R_WAIT_ROW_1: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid && m_axi_rlast) r_next = R_REQ_ROW_2;
            end

            // --- Fetch Feature Map Row 2 ---
            R_REQ_ROW_2: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) r_next = R_WAIT_ROW_2;
            end
            
            R_WAIT_ROW_2: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid && m_axi_rlast) r_next = R_DATA_READY;
            end

            // --- Handshake with Controller ---
            R_DATA_READY: begin
                lb_data_ready = 1'b1; // Tell PE Controller data is ready
                r_next = R_WAIT_NEXT;
            end

            R_WAIT_NEXT: begin
                if (req_next_data) begin
                    r_next = R_CALC_ADDR; // Loop to fetch next IC chunk
                end
            end
        endcase
    end

    // Sequential logic to capture AXI Read Data
    always_ff @(posedge sys_clk) begin
        if (rst) begin
            line_buffer_0 <= '0;
            line_buffer_1 <= '0;
            line_buffer_2 <= '0;
            current_weight_bias <= '0;
        end else begin
            if (m_axi_rvalid && m_axi_rready) begin
                if (r_state == R_WAIT_WEIGHT) current_weight_bias <= m_axi_rdata[159:0];
                if (r_state == R_WAIT_ROW_0)  line_buffer_0       <= m_axi_rdata;
                if (r_state == R_WAIT_ROW_1)  line_buffer_1       <= m_axi_rdata;
                if (r_state == R_WAIT_ROW_2)  line_buffer_2       <= m_axi_rdata;
            end
        end
    end

    // =========================================================
    // 4. WRITE FSM (Write-Back Computed Data)
    // =========================================================
    typedef enum logic [2:0] {
        W_IDLE,
        W_REQ_ADDR,
        W_WRITE_DATA,
        W_WAIT_RESP
    } write_state_t;
    
    write_state_t w_state, w_next;
    
    always_ff @(posedge sys_clk) begin
        if (rst) w_state <= W_IDLE;
        else     w_state <= w_next;
    end

    always_comb begin
        w_next = w_state;
        m_axi_awvalid = 1'b0;
        m_axi_wvalid  = 1'b0;
        m_axi_bready  = 1'b0;

        case (w_state)
            W_IDLE: begin
                if (wb_req) w_next = W_REQ_ADDR;
            end

            W_REQ_ADDR: begin
                m_axi_awvalid = 1'b1;
                if (m_axi_awready) w_next = W_WRITE_DATA;
            end

            W_WRITE_DATA: begin
                m_axi_wvalid = 1'b1;
                if (m_axi_wready) w_next = W_WAIT_RESP;
            end

            W_WAIT_RESP: begin
                m_axi_bready = 1'b1;
                if (m_axi_bvalid) w_next = W_IDLE;
            end
        endcase
    end

    // Assign Write channels
    assign m_axi_awaddr  = wb_addr;
    assign m_axi_wdata   = wb_data;
    assign m_axi_wstrb   = {(C_M_AXI_DATA_WIDTH/8){1'b1}}; // Write all bytes
    assign m_axi_wlast   = 1'b1; // Assuming single beat burst for write-back

    // AXI static configurations
    assign m_axi_arlen   = 8'd0; // 1 beat per burst (simplified)
    assign m_axi_arsize  = 3'b101; // 32 bytes (256 bits)
    assign m_axi_arburst = 2'b01; // INCR
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = 3'b101;
    assign m_axi_awburst = 2'b01;

endmodule