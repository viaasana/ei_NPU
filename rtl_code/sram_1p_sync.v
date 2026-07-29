module sram_1p_sync #(
    parameter AW = 10,            // address width
    parameter DW = 32,            // data width
    parameter DEPTH = (1<<AW)
)(
    input  wire           clk,
    input  wire           en,
    input  wire           we,
    input  wire [AW-1:0]  addr,
    input  wire [DW-1:0]  wdata,
    output reg  [DW-1:0]  rdata
);
    reg [DW-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (en) begin
            if (we) mem[addr] <= wdata;
            rdata <= mem[addr];
        end
    end
endmodule
