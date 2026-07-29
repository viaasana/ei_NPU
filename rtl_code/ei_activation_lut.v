`timescale 1ns / 1ps

module ei_activation_lut #(
    // Tham s? ???ng d?n file hex (M?c ??nh tr? t?i file 1024 dòng)
    parameter INIT_FILE = "/data/Documents/python/sigmoid_fp16_1024.hex" 
)(
    input  wire        sys_clk,
    input  wire        ce,      // Chip Enable (1: Ho?t ??ng, 0: Gi? tr?ng thái c?)
    input  wire [9:0]  addr_in, // Input 10-bit ?óng vai trò là ??a ch? (?ã nén)
    output reg  [15:0] data_out // Output FP16 l?y t? B?ng tra
);

    // Khai báo RAM: 1024 ph?n t? x 16 bit (?ã gi?m t? 65536 xu?ng 1024)
    (* rom_style = "block" *) // G?i ý cho tool t?ng h?p dùng BlockRAM (n?u dùng Vivado)
    reg [15:0] rom [0:1023];

    // N?p d? li?u t? file hex khi kh?i ??ng
    initial begin
        if (INIT_FILE != "") begin
            $display("Loading LUT from: %s", INIT_FILE);
            $readmemh(INIT_FILE, rom);
        end else begin
            $display("Error: INIT_FILE parameter is empty!");
        end
    end

    // ??c ??ng b? (Synchronous Read) -> Latency = 1 Clock Cycle
    always @(posedge sys_clk) begin
        if (ce) begin
            data_out <= rom[addr_in];
        end
    end

endmodule