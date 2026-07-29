`timescale 1ns / 1ps

module ei_pe_controller #(
    parameter NUM_PE = 16
)(
    input  logic sys_clk,
    input  logic rst,
    
    input  logic start,
    output logic done,
    input  logic ready_all,

    input  logic [15:0] reg_max_x,
    input  logic [15:0] reg_max_y,
    input  logic [15:0] reg_max_c,
    input  logic [15:0] reg_max_k,
    input  logic [1:0]  csr_act_mode,
    input  logic [1:0]  csr_pool_mode,

    // Giao tiếp BRAM
    output logic        fm_mem_read_en,
    output logic [31:0] fm_mem_addr,
    input  logic [255:0] fm_bram_read_data, // 16 phần tử 16-bit FP
    
    output logic        w_mem_read_en,
    output logic [31:0] w_mem_addr,

    // Tín hiệu điều khiển & Data tới PE Array
    output logic [NUM_PE-1:0] valid_in,
    output logic [NUM_PE-1:0] acc_clear,
    output logic [NUM_PE-1:0] final_input_channel,
    output logic [1:0]  pool_mode [0:NUM_PE-1],
    output logic [15:0] const_pool [0:NUM_PE-1],
    output logic [1:0]  act_mode [0:NUM_PE-1],
    
    // Data Router Output (Truyền 3x3 Window cho mỗi PE)
    output logic [15:0] pe_fm_data [0:NUM_PE-1][0:2][0:2]
);

    typedef enum logic [3:0] {
        S_IDLE, 
        S_CALC_LAYER, S_WAIT_LAYER, 
        S_WAIT_READY, S_CALC_ADDR, S_WAIT_ADDR, 
        S_INIT_FETCH, S_COMPUTE, S_UPDATE_COUNTERS, S_DONE
    } state_t;

    state_t current_state, next_state;

    logic [15:0] count_x, count_y, count_ic, count_oc;
    logic [3:0]  fetch_cnt; 

    logic [15:0] in_max_x;
    logic [15:0] in_max_y;
    assign in_max_x = reg_max_x;
    assign in_max_y = reg_max_y;

    // =================================================================
    // 1. MODULE TÍNH TOÁN ĐỊA CHỈ
    // =================================================================
    logic mult_en = 1'b1;
    logic valid_in_layer, valid_out_layer;
    logic [31:0] out_layer_size;
    logic [31:0] reg_fm_layer_size; 

    ei_unsigned_multiple_16bit mult_layer (
        .sys_clk(sys_clk), .rst(rst), .en(mult_en),
        .valid_in(valid_in_layer), .a_in(in_max_x), .b_in(in_max_y),
        .valid_out(valid_out_layer), .c_out(out_layer_size)
    );

    logic valid_in_addr, valid_out_w, valid_out_y, valid_out_ic;
    logic [31:0] out_w_offset, out_y_offset, out_ic_offset;
    
    ei_unsigned_multiple_16bit mult_w (
        .sys_clk(sys_clk), .rst(rst), .en(mult_en),
        .valid_in(valid_in_addr), .a_in(count_oc), .b_in(reg_max_c),
        .valid_out(valid_out_w), .c_out(out_w_offset)
    );

    ei_unsigned_multiple_16bit mult_y (
        .sys_clk(sys_clk), .rst(rst), .en(mult_en),
        .valid_in(valid_in_addr), .a_in(count_y), .b_in(in_max_x),
        .valid_out(valid_out_y), .c_out(out_y_offset)
    );

    ei_unsigned_multiple_16bit mult_ic (
        .sys_clk(sys_clk), .rst(rst), .en(mult_en),
        .valid_in(valid_in_addr), .a_in(count_ic), .b_in(reg_fm_layer_size[15:0]), 
        .valid_out(valid_out_ic), .c_out(out_ic_offset)
    );

    logic [31:0] base_w_addr;
    logic [31:0] current_fm_offset;

    // =================================================================
    // 2. DATA ROUTER & WINDOW BUFFER
    // =================================================================
    logic [15:0] window_left  [0:2][0:15];
    logic [15:0] window_right [0:2][0:15];
    logic [15:0] window_full  [0:2][0:31];
    
    always_comb begin
        for (int r = 0; r < 3; r++) begin
            for (int c = 0; c < 16; c++) begin
                window_full[r][c]    = window_left[r][c];
                window_full[r][c+16] = window_right[r][c];
            end
        end
    end

    always_comb begin
        for (int i = 0; i < NUM_PE; i++) begin
            for (int r = 0; r < 3; r++) begin
                if (csr_pool_mode == 2'b00) begin 
                    pe_fm_data[i][r][0] = window_full[r][i];
                    pe_fm_data[i][r][1] = window_full[r][i+1];
                    pe_fm_data[i][r][2] = window_full[r][i+2];
                end else begin 
                    pe_fm_data[i][r][0] = window_full[r][i*2];
                    pe_fm_data[i][r][1] = window_full[r][i*2+1];
                    pe_fm_data[i][r][2] = 16'd0; 
                end
            end
        end
    end

    logic [15:0] fm_bram_unpacked [0:15];
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            fm_bram_unpacked[i] = fm_bram_read_data[i*16 +: 16];
        end
    end

    // =================================================================
    // 3. FSM LOGIC & DATAPATH
    // =================================================================
    always_ff @(posedge sys_clk) begin
        if (rst) current_state <= S_IDLE;
        else     current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            S_IDLE:            if (start) next_state = S_CALC_LAYER;
            S_CALC_LAYER:      next_state = S_WAIT_LAYER;
            S_WAIT_LAYER:      if (valid_out_layer) next_state = S_WAIT_READY;
            
            S_WAIT_READY:      if (ready_all) next_state = S_CALC_ADDR;
            S_CALC_ADDR:       next_state = S_WAIT_ADDR;
            S_WAIT_ADDR:       if (valid_out_w) next_state = S_INIT_FETCH; 
            
            S_INIT_FETCH:      if (fetch_cnt == 6) next_state = S_COMPUTE;
            
            S_COMPUTE:         next_state = S_UPDATE_COUNTERS;
            
            // Xóa S_SHIFT_FETCH, luôn quay về S_WAIT_READY để tính lại địa chỉ mới
            S_UPDATE_COUNTERS: begin
                if (count_ic == reg_max_c - 1 && (count_x + NUM_PE) >= reg_max_x && count_y == reg_max_y - 1 && count_oc == reg_max_k - 1)
                    next_state = S_DONE;
                else
                    next_state = S_WAIT_READY; 
            end
            
            S_DONE:            next_state = S_IDLE;
            default:           next_state = S_IDLE;
        endcase
    end

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            count_x <= 0; count_y <= 0; count_ic <= 0; count_oc <= 0; done <= 0;
            valid_in <= '0; acc_clear <= '0; final_input_channel <= '0;
            fm_mem_read_en <= 0; w_mem_read_en <= 0; fm_mem_addr <= 0; w_mem_addr <= 0;
            valid_in_layer <= 0; valid_in_addr <= 0; reg_fm_layer_size <= 0;
            base_w_addr <= 0; fetch_cnt <= 0; current_fm_offset <= 0;
            for (int r=0; r<3; r++) begin
                for (int c=0; c<16; c++) begin
                    window_left[r][c] <= 16'd0;
                    window_right[r][c] <= 16'd0;
                end
            end
        end else begin
            valid_in <= '0; acc_clear <= '0; final_input_channel <= '0;
            fm_mem_read_en <= 0; w_mem_read_en <= 0;
            valid_in_layer <= 0; valid_in_addr <= 0;

            case (current_state)
                S_IDLE: begin
                    count_x <= 0; count_y <= 0; count_ic <= 0; count_oc <= 0; fetch_cnt <= 0; done <= 0;
                end
                
                S_CALC_LAYER: valid_in_layer <= 1'b1;
                S_WAIT_LAYER: if (valid_out_layer) reg_fm_layer_size <= out_layer_size;
                S_WAIT_READY: fetch_cnt <= 0;
                S_CALC_ADDR:  valid_in_addr <= 1'b1;
                
                S_WAIT_ADDR: begin
                    if (valid_out_w) begin
                        base_w_addr       <= out_w_offset + count_ic;
                        current_fm_offset <= out_ic_offset + out_y_offset + count_x; 
                    end
                end

                S_INIT_FETCH: begin
                    if (fetch_cnt < 6) fm_mem_read_en <= 1'b1;

                    // [FIX VIVADO]: Địa chỉ Byte = Index điểm ảnh * 2 Bytes (<< 1)
                    case (fetch_cnt)
                        0: fm_mem_addr <= (current_fm_offset + 0 * in_max_x) << 1;           
                        1: fm_mem_addr <= (current_fm_offset + 0 * in_max_x + 16) << 1;      
                        2: fm_mem_addr <= (current_fm_offset + 1 * in_max_x) << 1;           
                        3: fm_mem_addr <= (current_fm_offset + 1 * in_max_x + 16) << 1;      
                        4: fm_mem_addr <= (current_fm_offset + 2 * in_max_x) << 1;           
                        5: fm_mem_addr <= (current_fm_offset + 2 * in_max_x + 16) << 1;      
                    endcase

                    if (fetch_cnt == 0) begin
                        w_mem_read_en <= 1'b1;
                        w_mem_addr    <= base_w_addr; 
                    end

                    case (fetch_cnt)
                        1: window_left[0]  <= fm_bram_unpacked;
                        2: window_right[0] <= fm_bram_unpacked;
                        3: window_left[1]  <= fm_bram_unpacked;
                        4: window_right[1] <= fm_bram_unpacked;
                        5: window_left[2]  <= fm_bram_unpacked;
                        6: window_right[2] <= fm_bram_unpacked;
                    endcase

                    fetch_cnt <= fetch_cnt + 1;
                end
                
                S_COMPUTE: begin
                    for (int i = 0; i < NUM_PE; i++) begin
                        if ((count_x + i) < reg_max_x) begin
                            valid_in[i] <= 1'b1;
                            
                            // Gán acc_clear ở IC đầu tiên và final_channel ở IC cuối cùng cho từng PE hợp lệ
                            if (count_ic == 0) acc_clear[i] <= 1'b1;
                            else acc_clear[i] <= 1'b0;
                            
                            if (count_ic == reg_max_c - 1) final_input_channel[i] <= 1'b1;
                            else final_input_channel[i] <= 1'b0;
                            
                        end else begin
                            valid_in[i] <= 1'b0;
                            acc_clear[i] <= 1'b0;
                            final_input_channel[i] <= 1'b0;
                        end
                        
                        act_mode[i]   <= csr_act_mode;
                        pool_mode[i]  <= csr_pool_mode;
                        const_pool[i] <= 16'd0;
                    end
                end
                
                S_UPDATE_COUNTERS: begin
                    fetch_cnt <= 0;
                    if (count_ic == reg_max_c - 1) begin
                        count_ic <= 0; 
                        if (count_x + NUM_PE >= reg_max_x) begin
                            count_x <= 0; 
                            if (count_y == reg_max_y - 1) begin
                                count_y <= 0; 
                                if (count_oc != reg_max_k - 1) count_oc <= count_oc + 1;
                            end else begin
                                count_y <= count_y + 1;
                            end
                        end else begin
                            count_x <= count_x + NUM_PE; 
                        end
                    end else begin
                        count_ic <= count_ic + 1; 
                    end
                end
                
                S_DONE: done <= 1;
            endcase
        end
    end

    // Log kiểm tra trên console
    always @(posedge sys_clk) begin
        if(final_input_channel[0])
            $display("Time %0t: [ei_pe_controller] final_input_channel ASSERTED for X=%0d, Y=%0d, OC=%0d", $time, count_x, count_y, count_oc);
    end

endmodule