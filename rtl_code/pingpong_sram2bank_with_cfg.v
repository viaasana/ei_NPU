`timescale 1ns/1ps 
module pingpong_sram2bank_with_cfg #(
    parameter AW_DATA = 10,  // depth = 2^AW_DATA
    parameter DW_DATA = 32,

    parameter AW_CFG  = 8,
    parameter DW_CFG  = 32
)(
    input  wire sys_clk,
    input  wire rst,

    // =========================
    // WRITER side (CPU/DMA)
    // =========================
    input  wire           w_req_en,
    input  wire           w_req_we,          // 1=write, 0=read
    input  wire [AW_DATA-1:0] w_req_addr,
    input  wire [DW_DATA-1:0] w_req_wdata,
    output wire [DW_DATA-1:0] w_req_rdata,

    // WRITER access CFG shared
    input  wire           w_cfg_en,
    input  wire           w_cfg_we,
    input  wire [AW_CFG-1:0]  w_cfg_addr,
    input  wire [DW_CFG-1:0]  w_cfg_wdata,
    output wire [DW_CFG-1:0]  w_cfg_rdata,

    // WRITER handshake for frame/block completion
    input  wire           fill_done_pulse,   // 1 clk pulse when writer finished filling current fill bank
    output reg            fill_ack,           // optional ack back

    // =========================
    // READER side (NPU/PE)
    // =========================
    input  wire           r_req_en,
    input  wire [AW_DATA-1:0] r_req_addr,
    output wire [DW_DATA-1:0] r_req_rdata,

    // READER access CFG shared (often read-only)
    input  wire           r_cfg_en,
    input  wire [AW_CFG-1:0]  r_cfg_addr,
    output wire [DW_CFG-1:0]  r_cfg_rdata,

    // READER handshake for consumption completion
    input  wire           use_done_pulse,    // 1 clk pulse when NPU finished consuming current use bank
    output reg            use_ack,           // optional ack back

    // =========================
    // Status/Control
    // =========================
    output reg            use_bank,          // 0 or 1: bank used by reader
    output wire           fill_bank,         // bank used by writer
    output reg            swap_pulse          // 1 clk when bank swapped
);

    assign fill_bank = ~use_bank;

    // ----------------------------------------------------------------
    // Two data banks (SRAM)
    // NOTE: each bank is 1-port. We'll MUX writer/read accesses by time
    //       OR you can make it 2-port if you want true parallel.
    // Here: simple arbitration: reader has priority (configurable).
    // ----------------------------------------------------------------

    // Bank0 ports
    wire b0_en;
    wire b0_we;
    wire [AW_DATA-1:0] b0_addr;
    wire [DW_DATA-1:0] b0_wdata;
    wire [DW_DATA-1:0] b0_rdata;

    // Bank1 ports
    wire b1_en;
    wire b1_we;
    wire [AW_DATA-1:0] b1_addr;
    wire [DW_DATA-1:0] b1_wdata;
    wire [DW_DATA-1:0] b1_rdata;

    // ----------------------------------------------------------------
    // Arbitration / MUX policy:
    // - Reader accesses "use_bank"
    // - Writer accesses "fill_bank"
    // Because each bank is independent, we can allow reader and writer
    // concurrently if they target different banks (which is always true
    // in ping-pong normal operation).
    //
    // So mapping is straightforward:
    // - If use_bank==0 => reader -> bank0, writer -> bank1
    // - If use_bank==1 => reader -> bank1, writer -> bank0
    // ----------------------------------------------------------------

    // Reader to bank selection
    wire r_to_b0 = (use_bank == 1'b0);
    wire r_to_b1 = (use_bank == 1'b1);

    // Writer to bank selection
    wire w_to_b0 = (fill_bank == 1'b0);
    wire w_to_b1 = (fill_bank == 1'b1);

    // Connect bank0
    assign b0_en    = (r_req_en && r_to_b0) || (w_req_en && w_to_b0);
    assign b0_we    = (w_req_en && w_to_b0 && w_req_we);     // reader read-only
    assign b0_addr  = (r_req_en && r_to_b0) ? r_req_addr : w_req_addr;
    assign b0_wdata = w_req_wdata;

    // Connect bank1
    assign b1_en    = (r_req_en && r_to_b1) || (w_req_en && w_to_b1);
    assign b1_we    = (w_req_en && w_to_b1 && w_req_we);
    assign b1_addr  = (r_req_en && r_to_b1) ? r_req_addr : w_req_addr;
    assign b1_wdata = w_req_wdata;

    // Instantiate SRAM banks
    sram_1p_sync #(.AW(AW_DATA), .DW(DW_DATA)) u_bank0 (
        .clk(clk), .en(b0_en), .we(b0_we), .addr(b0_addr), .wdata(b0_wdata), .rdata(b0_rdata)
    );

    sram_1p_sync #(.AW(AW_DATA), .DW(DW_DATA)) u_bank1 (
        .clk(clk), .en(b1_en), .we(b1_we), .addr(b1_addr), .wdata(b1_wdata), .rdata(b1_rdata)
    );

    // Read data routing back to reader/writer
    // (sram is sync-read, so rdata shows one clk later)
    assign r_req_rdata = (use_bank == 1'b0) ? b0_rdata : b1_rdata;
    assign w_req_rdata = (fill_bank == 1'b0) ? b0_rdata : b1_rdata;

    // ----------------------------------------------------------------
    // Shared Config SRAM (independent memory, no ping-pong)
    // We'll arbitrate if both w_cfg_en and r_cfg_en occur same cycle.
    // Simple priority: writer > reader (or swap it).
    // ----------------------------------------------------------------

    wire cfg_en  = w_cfg_en || r_cfg_en;
    wire cfg_we  = w_cfg_en && w_cfg_we;
    wire [AW_CFG-1:0]  cfg_addr  = w_cfg_en ? w_cfg_addr  : r_cfg_addr;
    wire [DW_CFG-1:0]  cfg_wdata = w_cfg_wdata;
    wire [DW_CFG-1:0]  cfg_rdata;

    sram_1p_sync #(.AW(AW_CFG), .DW(DW_CFG)) u_cfg (
        .clk(sys_clk), .en(cfg_en), .we(cfg_we), .addr(cfg_addr), .wdata(cfg_wdata), .rdata(cfg_rdata)
    );

    assign w_cfg_rdata = cfg_rdata;
    assign r_cfg_rdata = cfg_rdata;

    // ----------------------------------------------------------------
    // Swap controller: swap when BOTH sides done
    // ----------------------------------------------------------------
    reg fill_done_latched;
    reg use_done_latched;

    always @(posedge sys_clk or posedge rst) begin
        if (rst) begin
            use_bank          <= 1'b0;
            fill_done_latched <= 1'b0;
            use_done_latched  <= 1'b0;
            swap_pulse        <= 1'b0;
            fill_ack          <= 1'b0;
            use_ack           <= 1'b0;
        end else begin
            swap_pulse <= 1'b0;
            fill_ack   <= 1'b0;
            use_ack    <= 1'b0;

            // latch done pulses
            if (fill_done_pulse) begin
                fill_done_latched <= 1'b1;
                fill_ack <= 1'b1;
            end
            if (use_done_pulse) begin
                use_done_latched <= 1'b1;
                use_ack <= 1'b1;
            end

            // swap condition
            if (fill_done_latched && use_done_latched) begin
                use_bank          <= ~use_bank;
                fill_done_latched <= 1'b0;
                use_done_latched  <= 1'b0;
                swap_pulse        <= 1'b1; // 1 clk pulse indicates swap event
            end
        end
    end

endmodule

