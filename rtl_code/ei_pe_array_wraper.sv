module ei_pe_array_wrapper
(
    input clk,
    input rst,

    input logic [15:0] win_data [0:8],
    input logic [15:0] wt_data  [0:15][0:8],
    input logic [15:0] bias_data[0:15],

    input logic start,

    output logic done,

    output logic [15:0] result [0:15]
);

    

endmodule