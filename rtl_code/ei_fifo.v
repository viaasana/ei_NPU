`timescale 1ns/1ps
module ei_fifo #(
    parameter WIDTH = 16,
    parameter DEPTH = 8
)(
    input clk,
    input rst,
    input en,
    input [WIDTH-1:0] data_in,  // Dữ liệu đầu vào
    input valid_in,              // Tín hiệu hợp lệ dữ liệu đầu vào
    input [2:0] num_values_to_accumulate, // Tín hiệu điều khiển số giá trị cần cộng dồn (3 hoặc 6)
    output reg [WIDTH-1:0] data_out, // Dữ liệu đầu ra
    output reg valid_out         // Tín hiệu hợp lệ dữ liệu đầu ra
);

    reg [WIDTH-1:0] fifo_mem [0:DEPTH-1]; // Mảng FIFO
    reg [2:0] write_ptr, read_ptr;         // Con trỏ đọc và ghi
    reg [2:0] fifo_count;                  // Đếm số lượng dữ liệu trong FIFO

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr <= 0;
            fifo_count <= 0;
            valid_out <= 0;
        end else if (en) begin
            // Ghi dữ liệu vào FIFO khi có tín hiệu valid_in
            if (valid_in && fifo_count < DEPTH) begin
                fifo_mem[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
                fifo_count <= fifo_count + 1;
            end

            // Đọc dữ liệu từ FIFO theo số lượng giá trị cần cộng dồn (num_values_to_accumulate)
            if (fifo_count >= num_values_to_accumulate) begin
                data_out <= fifo_mem[read_ptr];
                valid_out <= 1; // Dữ liệu đã sẵn sàng
                read_ptr <= read_ptr + 1;
                fifo_count <= fifo_count - 1;
            end else begin
                valid_out <= 0; // Nếu chưa đủ số lượng cần thiết, không có dữ liệu hợp lệ
            end
        end
    end

endmodule
