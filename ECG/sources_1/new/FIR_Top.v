module FIR_Filter_Top #(
    parameter TAPS = 117,      // Số lượng hệ số (Tap)
    parameter DATA_WIDTH = 16  // Độ rộng dữ liệu
)(
    input wire clk,
    input wire rst,
    
    // Interface tín hiệu vào
    input wire input_valid,               // Báo hiệu có mẫu ECG mới
    input wire signed [DATA_WIDTH-1:0] sample_in, // Mẫu ECG mới
    
    // Interface tín hiệu ra
    output reg output_valid,              // Báo hiệu đã lọc xong
    output reg signed [31:0] data_out     // Kết quả lọc
);

    // --- 1. KHAI BÁO TÍN HIỆU NỘI ---
    
    // Quản lý trạng thái
    reg [1:0] state;
    localparam IDLE  = 2'b00;
    localparam SHIFT = 2'b01;
    localparam CALC  = 2'b10;
    localparam DONE  = 2'b11;

    // Bộ đếm vòng lặp (Counter)
    reg [7:0] cnt; // Đủ để đếm đến 117

    // Bộ nhớ đệm dữ liệu ECG (Delay Line) - Dùng Distributed RAM
    reg signed [DATA_WIDTH-1:0] data_buffer [0:TAPS-1];
    integer i;

    // Tín hiệu kết nối module con
    reg signed [DATA_WIDTH-1:0] mac_x_reg;    // X input cho MAC (đã delay 1 clk)
    wire signed [DATA_WIDTH-1:0] mac_y_wire;  // Y input (Hệ số từ BRAM)
    reg mac_mode_reg;                         // Mode cho MAC (đã delay 1 clk)
    wire signed [31:0] mac_result_wire;       // Output từ MAC
    
    // Tín hiệu điều khiển BRAM
    wire [6:0] bram_addr;
    assign bram_addr = cnt[6:0]; // Gán địa chỉ đọc BRAM bằng giá trị biến đếm

    // --- 2. INSTANTIATE CÁC MODULE CON ---

    // A. Block RAM chứa hệ số (IP Core)
    blk_mem_gen_0 inst_coeff_rom (
        .clka(clk),           // Clock
        .ena(1'b1),           // Luôn cho phép (Enable)
        .wea(1'b0),           // Không ghi (Write Enable = 0)
        .addra(bram_addr),    // Địa chỉ đọc (từ counter)
        .dina(16'b0),         // Dữ liệu ghi (không dùng)
        .douta(mac_y_wire)    // -> Nối vào Y của MAC
    );

    // B. MAC Unit (Module của bạn)
    MAC_16Bit_Top inst_mac (
        .clk(clk),
        .rst(rst),
        .x_in(mac_x_reg),        // Dữ liệu ECG (từ logic delay bên dưới)
        .y_in(mac_y_wire),       // Hệ số (từ BRAM)
        .mode_acc_in(mac_mode_reg), // 0: Load, 1: Accumulate
        .mac_result_out(mac_result_wire)
    );

    // --- 3. LOGIC ĐIỀU KHIỂN (FSM) ---

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            cnt <= 0;
            output_valid <= 0;
            data_out <= 0;
            mac_x_reg <= 0;
            mac_mode_reg <= 0;
            // Reset buffer (Optional, tốn logic nên có thể bỏ qua nếu chấp nhận rác ban đầu)
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
                        state <= SHIFT;
                    end
                end

                // Trạng thái cập nhật Delay Line (Dịch dữ liệu)
                SHIFT: begin
                    // Dịch toàn bộ mảng sang phải 1 vị trí: x[n] -> x[n-1]
                    for (i = TAPS-1; i > 0; i = i - 1) begin
                        data_buffer[i] <= data_buffer[i-1];
                    end
                    // Nạp mẫu mới nhất vào đầu hàng
                    data_buffer[0] <= sample_in;
                    
                    state <= CALC;
                    cnt <= 0; // Reset biến đếm để bắt đầu tính toán
                end

                // Trạng thái Tính toán (Chạy vòng lặp MAC)
                CALC: begin
                    // Pipeline Stage 1: Fetch Data & Align Logic
                    
                    if (cnt < TAPS) begin
                        // 1. Lấy dữ liệu từ buffer đưa vào thanh ghi đệm
                        mac_x_reg <= data_buffer[cnt]; // <-- SỬA TẠI ĐÂY (mac_x_reg)
                        
                        // 2. Điều khiển chế độ MAC
                        // Nếu là mẫu đầu tiên (cnt=0) -> mode = 0 (Load/Reset)
                        // Các mẫu sau -> mode = 1 (Accumulate)
                        if (cnt == 0) 
                            mac_mode_reg <= 1'b0; 
                        else 
                            mac_mode_reg <= 1'b1;
                        
                        // Tăng biến đếm
                        cnt <= cnt + 1;
                    end 
                    else begin
                        // Khi đã duyệt hết 117 mẫu (cnt = 117)
                        // Cần đợi vài clock để Pipeline của MAC xả hết dữ liệu ra
                        // MAC của bạn có Stage 1 và Stage 2 -> Cần đợi thêm khoảng 2-3 clock
                        // Ở đây ta chuyển sang DONE, việc chuyển state cũng tốn 1 clock rồi
                        state <= DONE;
                    end
                end

                // Trạng thái Kết thúc
                DONE: begin
                    // Tại thời điểm này, MAC đã tính xong giá trị cuối cùng
                    data_out <= mac_result_wire;
                    output_valid <= 1;
                    state <= IDLE; // Quay về chờ mẫu tiếp theo
                end
            endcase
        end
    end

endmodule