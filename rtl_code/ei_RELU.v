module ei_RELU (
    input  wire [15:0] data_in,
    output wire [15:0] data_out
);

    // Hằng số 0 (16-bit) cho trường hợp số âm
    wire [15:0] zero_val = 16'h0000;

    // Sử dụng ei_muxN đã có
    // Logic:
    // - s (select) nối vào data_in[15] (bit dấu)
    // - Nếu bit dấu = 0 (dương) -> Mux chọn d0 -> Output là data_in
    // - Nếu bit dấu = 1 (âm)    -> Mux chọn d1 -> Output là zero_val
    
    ei_muxN #(
        .WIDTH(16) // FP16 nên độ rộng là 16 bit
    ) u_mux_relu (
        .d0 (data_in),      // Ngõ vào 0: Giữ nguyên giá trị
        .d1 (zero_val),     // Ngõ vào 1: Giá trị 0
        .s  (data_in[15]),  // Tín hiệu chọn: Bit dấu của FP16
        .y  (data_out)      // Ngõ ra
    );

endmodule