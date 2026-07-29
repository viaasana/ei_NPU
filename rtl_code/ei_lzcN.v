module ei_lzcN #(
    parameter integer WIDTH   = 14,
    parameter integer COUNT_W = $clog2(WIDTH+1)
)(
    input  wire [WIDTH-1:0] x,
    output reg  [COUNT_W-1:0] count
);
    integer i;
    reg found;

    always @* begin
        count = WIDTH;   // nếu x == 0 => count = WIDTH (tự truncate vào COUNT_W bit)
        found = 1'b0;

        // i = số bit 0 liên tiếp từ MSB
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (!found && x[WIDTH-1-i]) begin
                count = i[COUNT_W-1:0]; // dòng này OK vì i là integer, slice trên biến
                found = 1'b1;
            end
        end
    end
endmodule
