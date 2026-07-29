`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2026 09:40:49 PM
// Design Name: 
// Module Name: fp16_3num_comparator
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


module ei_fp16_3num_comparator#(
    parameter WIDTH = 16
    )(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input [WIDTH-1:0] c,
    output [WIDTH-1:0] compare
    );
    
    wire sign_a = a[WIDTH-1];
    wire sign_b = b[WIDTH-1];
    wire sign_c = c[WIDTH-1];
    
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [4:0] exp_c = c[14:10];
    
    wire [9:0] man_a = a[9:0];
    wire [9:0] man_b = b[9:0];
    wire [9:0] man_c = c[9:0];
    
    //reg a_is_max, b_is_max, c_is_max;
    
    //KTRA A>=B
    //wire sign_ab = (~sign_a & sign_b) | (~(sign_a ^ sign_b));
    
    wire exp_ab_gt = (exp_a[4] & ~exp_b[4]) |
                    ((exp_a[4] ~^ exp_b[4]) & (exp_a[3] & ~exp_b[3])) |
                    ((exp_a[4:3] == exp_b[4:3]) & (exp_a[2] & ~exp_b[2])) | 
                    ((exp_a[4:2] == exp_b[4:2]) & (exp_a[1] & ~exp_b[1])) |
                    ((exp_a[4:1] == exp_b[4:1]) & (exp_a[0] & ~exp_b[0]));
    wire exp_ab_eq = (exp_a == exp_b);
                    
    wire man_ab_ge = (man_a[9] & ~man_b[9]) |
                    ((man_a[9] ~^ man_b[9]) & (man_a[8] & ~man_b[8])) |
                    ((man_a[9:8] == man_b[9:8]) & (man_a[7] & ~man_b[7])) | 
                    ((man_a[9:7] == man_b[9:7]) & (man_a[6] & ~man_b[6])) |
                    ((man_a[9:6] == man_b[9:6]) & (man_a[5] & ~man_b[5])) |
                    ((man_a[9:5] == man_b[9:5]) & (man_a[4] & ~man_b[4])) | 
                    ((man_a[9:4] == man_b[9:4]) & (man_a[3] & ~man_b[3])) |
                    ((man_a[9:3] == man_b[9:3]) & (man_a[2] & ~man_b[2])) |
                    ((man_a[9:2] == man_b[9:2]) & (man_a[1] & ~man_b[1])) |
                    ((man_a[9:1] == man_b[9:1]) & (man_a[0] & ~man_b[0])) |
                    (man_a == man_b);
                    
    wire a_ge_b = (~sign_a & sign_b) |
                    ((~sign_a & ~sign_b) & (exp_ab_gt | (exp_ab_eq & man_ab_ge))) |
                    ((sign_a & sign_b) & (~exp_ab_gt | (exp_ab_eq & ~man_ab_ge)));
                    
    //KTRA A>=C
    
     wire exp_ac_gt = (exp_a[4] & ~exp_c[4]) |
                    ((exp_a[4] ~^ exp_c[4]) & (exp_a[3] & ~exp_c[3])) |
                    ((exp_a[4:3] == exp_c[4:3]) & (exp_a[2] & ~exp_c[2])) | 
                    ((exp_a[4:2] == exp_c[4:2]) & (exp_a[1] & ~exp_c[1])) |
                    ((exp_a[4:1] == exp_c[4:1]) & (exp_a[0] & ~exp_c[0]));
    wire exp_ac_eq = (exp_a == exp_c);
                    
    wire man_ac_ge = (man_a[9] & ~man_c[9]) |
                    ((man_a[9] ~^ man_c[9]) & (man_a[8] & ~man_c[8])) |
                    ((man_a[9:8] == man_c[9:8]) & (man_a[7] & ~man_c[7])) | 
                    ((man_a[9:7] == man_c[9:7]) & (man_a[6] & ~man_c[6])) |
                    ((man_a[9:6] == man_c[9:6]) & (man_a[5] & ~man_c[5])) |
                    ((man_a[9:5] == man_c[9:5]) & (man_a[4] & ~man_c[4])) | 
                    ((man_a[9:4] == man_c[9:4]) & (man_a[3] & ~man_c[3])) |
                    ((man_a[9:3] == man_c[9:3]) & (man_a[2] & ~man_c[2])) |
                    ((man_a[9:2] == man_c[9:2]) & (man_a[1] & ~man_c[1])) |
                    ((man_a[9:1] == man_c[9:1]) & (man_a[0] & ~man_c[0])) |
                    (man_a == man_c);
                    
    wire a_ge_c = (~sign_a & sign_c) |
                    ((~sign_a & ~sign_c) & (exp_ac_gt | (exp_ac_eq & man_ac_ge))) |
                    ((sign_a & sign_c) & (~exp_ac_gt | (exp_ac_eq & ~man_ac_ge)));
    
    //KTRA B>=C
    
     wire exp_bc_gt = (exp_b[4] & ~exp_c[4]) |
                    ((exp_b[4] ~^ exp_c[4]) & (exp_b[3] & ~exp_c[3])) |
                    ((exp_b[4:3] == exp_c[4:3]) & (exp_b[2] & ~exp_c[2])) | 
                    ((exp_b[4:2] == exp_c[4:2]) & (exp_b[1] & ~exp_c[1])) |
                    ((exp_b[4:1] == exp_c[4:1]) & (exp_b[0] & ~exp_c[0]));
    wire exp_bc_eq = (exp_b == exp_c);
                    
    wire man_bc_ge = (man_b[9] & ~man_c[9]) |
                    ((man_b[9] ~^ man_c[9]) & (man_b[8] & ~man_c[8])) |
                    ((man_b[9:8] == man_c[9:8]) & (man_b[7] & ~man_c[7])) | 
                    ((man_b[9:7] == man_c[9:7]) & (man_b[6] & ~man_c[6])) |
                    ((man_b[9:6] == man_c[9:6]) & (man_b[5] & ~man_c[5])) |
                    ((man_b[9:5] == man_c[9:5]) & (man_b[4] & ~man_c[4])) | 
                    ((man_b[9:4] == man_c[9:4]) & (man_b[3] & ~man_c[3])) |
                    ((man_b[9:3] == man_c[9:3]) & (man_b[2] & ~man_c[2])) |
                    ((man_b[9:2] == man_c[9:2]) & (man_b[1] & ~man_c[1])) |
                    ((man_b[9:1] == man_c[9:1]) & (man_b[0] & ~man_c[0])) |
                    (man_b == man_c);
                    
    wire b_ge_c = (~sign_b & sign_c) |
                    ((~sign_b & ~sign_c) & (exp_bc_gt | (exp_bc_eq & man_bc_ge))) |
                    ((sign_b & sign_c) & (~exp_bc_gt | (exp_bc_eq & ~man_bc_ge)));
                    
    ///LARGEST NUMBER
    wire a_is_max = a_ge_b & a_ge_c;
    wire b_is_max = (~a_ge_b) & b_ge_c;
    wire c_is_max = (~a_ge_c) & (~b_ge_c); 
    
    //OUTPUT 
    assign compare =
      ({WIDTH{a_is_max}} & a)
    | ({WIDTH{b_is_max}} & b)
    | ({WIDTH{c_is_max}} & c);
                    
                    
                    
endmodule
