module FIR_Filter_Top #(
    parameter TAPS = 83,       // <--- ĐÃ SỬA: Giảm xuống 83 tap
    parameter DATA_WIDTH = 16  // Độ rộng dữ liệu
)(
    input wire clk,
    input wire rst,
    input wire [1:0] sw,              // <--- ĐÃ THÊM: Switch chọn chế độ (00: Gốc, 01: LPF, 10: HPF)
    
    // Interface tín hiệu vào
    input wire input_valid,           // Báo hiệu có mẫu ECG mới
    input wire signed [DATA_WIDTH-1:0] sample_in, // Mẫu ECG mới
    
    // Interface tín hiệu ra
    output reg output_valid,          // Báo hiệu đã lọc xong
    output reg signed [31:0] data_out // Kết quả lọc
);

    // --- 1. KHAI BÁO TÍN HIỆU NỘI ---
    
    // Quản lý trạng thái
    reg [1:0] state;
    localparam IDLE  = 2'b00;
    localparam SHIFT = 2'b01;
    localparam CALC  = 2'b10;
    localparam DONE  = 2'b11;

    // Bộ đếm vòng lặp (Counter)
    reg [7:0] cnt; 

    // Bộ nhớ đệm dữ liệu ECG (Delay Line)
    reg signed [DATA_WIDTH-1:0] data_buffer [0:TAPS-1];
    integer i;

    // Tín hiệu kết nối module con
    reg signed [DATA_WIDTH-1:0] mac_x_reg;    
    wire signed [DATA_WIDTH-1:0] mac_y_wire;  // Đây là dây chọn hệ số cuối cùng
    reg mac_mode_reg;                         
    wire signed [31:0] mac_result_wire;       
    
    // Dây nối từ 2 khối BRAM
    wire signed [15:0] coeff_lpf_wire; // Hệ số từ LPF
    wire signed [15:0] coeff_hpf_wire; // Hệ số từ HPF

    // Tín hiệu điều khiển BRAM
    wire [6:0] bram_addr;
    assign bram_addr = cnt[6:0]; 

    // --- 2. LOGIC CHỌN HỆ SỐ (MUX) ---
    // Dựa vào switch để chọn dây nào nối vào MAC
    // sw = 01: Chọn LPF
    // sw = 10: Chọn HPF
    // Các trường hợp khác: 0 (hoặc giữ nguyên, nhưng ở đây set 0 cho an toàn)
    assign mac_y_wire = (sw == 2'b01) ? coeff_lpf_wire : 
                        (sw == 2'b10) ? coeff_hpf_wire : 16'd0;

    // --- 3. INSTANTIATE CÁC MODULE CON ---

    // A. Block RAM chứa hệ số HPF (High Pass)
    blk_mem_gen_hpf inst_hpf_rom (
        .clka(clk),      
        .ena(1'b1),      
        .wea(1'b0),      
        .addra(bram_addr), 
        .dina(16'b0),    
        .douta(coeff_hpf_wire) // Output ra dây riêng của HPF
    );

    // B. Block RAM chứa hệ số LPF (Low Pass)
    blk_mem_gen_lpf inst_lpf_rom (
        .clka(clk),      
        .ena(1'b1),      
        .wea(1'b0),      
        .addra(bram_addr), 
        .dina(16'b0),    
        .douta(coeff_lpf_wire) // Output ra dây riêng của LPF
    );

    // C. MAC Unit
    MAC_16Bit_Top inst_mac (
        .clk(clk),
        .rst(rst),
        .x_in(mac_x_reg),        
        .y_in(mac_y_wire),       // Đã được chọn bởi logic MUX ở trên
        .mode_acc_in(mac_mode_reg), 
        .mac_result_out(mac_result_wire)
    );

    // --- 4. LOGIC ĐIỀU KHIỂN (FSM) ---

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            cnt <= 0;
            output_valid <= 0;
            data_out <= 0;
            mac_x_reg <= 0;
            mac_mode_reg <= 0;
            for (i = 0; i < TAPS; i = i + 1) begin
                data_buffer[i] <= 0;
            end
        end else begin
            case (state)
                // Trạng thái chờ mẫu mới
                IDLE: begin
                    output_valid <= 0;
                    cnt <= 0;
                    
                    if (input_valid) begin
                        // KIỂM TRA SWITCH:
                        if (sw == 2'b00) begin
                            // --- CHẾ ĐỘ BYPASS (Tín hiệu gốc) ---
                            // Xuất thẳng input ra output (Sign extension từ 16 bit -> 32 bit)
                            data_out <= {{16{sample_in[15]}}, sample_in}; 
                            output_valid <= 1;
                            // Vẫn giữ ở trạng thái IDLE để chờ mẫu tiếp theo
                        end else begin
                            // --- CHẾ ĐỘ LỌC (LPF hoặc HPF) ---
                            // Chuyển sang SHIFT để bắt đầu quy trình lọc
                            state <= SHIFT;
                        end
                    end
                end

                // Trạng thái cập nhật Delay Line
                SHIFT: begin
                    for (i = TAPS-1; i > 0; i = i - 1) begin
                        data_buffer[i] <= data_buffer[i-1];
                    end
                    data_buffer[0] <= sample_in;
                    
                    state <= CALC;
                    cnt <= 0; 
                end

                // Trạng thái Tính toán MAC
                CALC: begin
                    if (cnt < TAPS) begin
                        // 1. Lấy dữ liệu
                        mac_x_reg <= data_buffer[cnt]; 
                        
                        // 2. Điều khiển chế độ MAC
                        if (cnt == 0) 
                            mac_mode_reg <= 1'b0; 
                        else 
                            mac_mode_reg <= 1'b1;
                        
                        cnt <= cnt + 1;
                    end 
                    else begin
                        // Đã chạy hết 83 taps
                        state <= DONE;
                    end
                end

                // Trạng thái Kết thúc
                DONE: begin
                    data_out <= mac_result_wire;
                    output_valid <= 1;
                    state <= IDLE; 
                end
            endcase
        end
    end

endmodule