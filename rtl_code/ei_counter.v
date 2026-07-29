`timescale 1ns/1ps

module ei_counter #(
    parameter WIDTH = 6
)(
    input                  clk,
    input                  rst,        // reset đồng bộ, active-high
    input                  en,         // enable cập nhật
    input                  load_sel,   // =1: nạp load_value, =0: đếm lên
    input      [WIDTH-1:0] load_value, // giá trị cần nạp
    output     [WIDTH-1:0] q,
    output                 cout        // carry-out khi tràn
);

    wire [WIDTH-1:0] q_next;
    wire [WIDTH-1:0] q_plus1;

    // q_plus1 = q + 1
    ei_adderN #(.WIDTH(WIDTH)) u_adder (
        .a   (q),
        .b   ({{(WIDTH-1){1'b0}}, 1'b1}),
        .sum (q_plus1),
        .cout(cout)
    );

    // mux chọn giá trị đưa vào counter
    // load_sel = 0 -> đếm
    // load_sel = 1 -> nạp
    ei_muxN #(.WIDTH(WIDTH)) u_mux (
        .d0(q_plus1),
        .d1(load_value),
        .s (load_sel),
        .y (q_next)
    );

    // thanh ghi trạng thái counter
    regN #(.WIDTH(WIDTH)) u_reg (
        .clk(clk),
        .rst(rst),
        .en (en),
        .d  (q_next),
        .q  (q)
    );

endmodule
