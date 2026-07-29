`timescale 1ns/1ps

module ei_unsigned_multiple_16bit (
    input         sys_clk,
    input         rst,      
    input         en,       
    input         valid_in, // <-- Tín hiệu Valid ngõ vào
    input  [15:0] a_in,
    input  [15:0] b_in,
    output [31:0] c_out,
    output logic  valid_out // <-- Tín hiệu Valid ngõ ra
);

    // =====================================
    // Logic đồng bộ tín hiệu Valid (3 chu kỳ)
    // =====================================
    logic valid_s0;
    logic valid_s1;

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            valid_s0  <= 1'b0;
            valid_s1  <= 1'b0;
            valid_out <= 1'b0;
        end else if (en) begin
            valid_s0  <= valid_in;  // Đồng bộ với chốt ngõ vào (Stage 0)
            valid_s1  <= valid_s0;  // Đồng bộ với pipeline Stage 1
            valid_out <= valid_s1;  // Đồng bộ với ngõ ra (Stage 2)
        end
    end

    // =====================================
    // Stage 0: Chốt ngõ vào
    // =====================================
    wire [15:0] a_s0;
    wire [15:0] b_s0;

    regN #(.WIDTH(16)) reg_a (.clk(sys_clk), .rst(rst), .en(en), .d(a_in), .q(a_s0));
    regN #(.WIDTH(16)) reg_b (.clk(sys_clk), .rst(rst), .en(en), .d(b_in), .q(b_s0));

    // =====================================
    // Stage 1: Dịch, MUX và Cộng chặng 1
    // =====================================
    wire [31:0] r [0:15]; 
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin: gen_partial_products
            wire [31:0] shifted_a = {{(16-i){1'b0}}, a_s0} << i; 
            assign r[i] = (b_s0[i] == 1'b1) ? shifted_a : 32'b0;
        end
    endgenerate

    wire [31:0] t0 = r[0]  + r[1];
    wire [31:0] t1 = r[2]  + r[3];
    wire [31:0] t2 = r[4]  + r[5];
    wire [31:0] t3 = r[6]  + r[7];
    wire [31:0] t4 = r[8]  + r[9];
    wire [31:0] t5 = r[10] + r[11];
    wire [31:0] t6 = r[12] + r[13];
    wire [31:0] t7 = r[14] + r[15];

    wire [31:0] u0_s1 = t0 + t1;
    wire [31:0] u1_s1 = t2 + t3;
    wire [31:0] u2_s1 = t4 + t5;
    wire [31:0] u3_s1 = t6 + t7;

    // =====================================
    // Reg giữa Stage 1 -> Stage 2
    // =====================================
    wire [31:0] u0_s2, u1_s2, u2_s2, u3_s2;

    regN #(.WIDTH(32)) reg_u0 (.clk(sys_clk), .rst(rst), .en(en), .d(u0_s1), .q(u0_s2));
    regN #(.WIDTH(32)) reg_u1 (.clk(sys_clk), .rst(rst), .en(en), .d(u1_s1), .q(u1_s2));
    regN #(.WIDTH(32)) reg_u2 (.clk(sys_clk), .rst(rst), .en(en), .d(u2_s1), .q(u2_s2));
    regN #(.WIDTH(32)) reg_u3 (.clk(sys_clk), .rst(rst), .en(en), .d(u3_s1), .q(u3_s2));

    // =====================================
    // Stage 2: Cộng chặng cuối & Reg Ngõ ra
    // =====================================
    wire [31:0] v0_s2 = u0_s2 + u1_s2;
    wire [31:0] v1_s2 = u2_s2 + u3_s2;
    wire [31:0] c_s2  = v0_s2 + v1_s2;

    regN #(.WIDTH(32)) reg_c (.clk(sys_clk), .rst(rst), .en(en), .d(c_s2), .q(c_out));

endmodule