`timescale 1ns / 1ps

module tb_FIR_Filter;

    // =========================================================================
    // 1. CẤU HÌNH THAM SỐ (USER SETTINGS)
    // =========================================================================
    
    // Đường dẫn file (Tuyệt đối chính xác)
    parameter IN_FILE_NAME  = "D:/Do_An_2/audio_hex.txt";
    parameter OUT_FILE_NAME = "D:/Do_An_2/audio_out.txt";
    
    // Tần số lấy mẫu
    parameter SAMPLE_RATE   = 44100; 
    
    // [QUAN TRỌNG 1]: Thời gian test cho mỗi chế độ
    // Để 0.5 giây (22050 mẫu) để chạy nhanh mà vẫn nghe được sự thay đổi
    parameter TIME_PER_MODE = 22050; 

    // [QUAN TRỌNG 2]: Điểm bắt đầu đọc file
    // Bắt đầu từ 3000 để BỎ QUA đoạn im lặng (toàn số 0) ở đầu file
    parameter START_INDEX   = 3000; 

    // Giới hạn bộ nhớ đệm
    parameter MAX_SAMPLES   = 1000000; 

    // =========================================================================
    // 2. KHAI BÁO TÍN HIỆU
    // =========================================================================
    reg clk;
    reg rst;
    reg [1:0] sw;
    reg input_valid;
    reg signed [15:0] sample_in;
    
    wire output_valid;
    wire signed [31:0] data_out;

    // Bộ nhớ và biến nội bộ
    reg [15:0] memory [0:MAX_SAMPLES-1]; 
    integer file_out;                    
    integer i;
    integer output_count;

    // =========================================================================
    // 3. KẾT NỐI MODULE CHÍNH (DUT)
    // =========================================================================
    FIR_Filter_Top #(
        .TAPS(83), 
        .DATA_WIDTH(16)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .sw(sw), 
        .input_valid(input_valid), 
        .sample_in(sample_in), 
        .output_valid(output_valid), 
        .data_out(data_out)
    );

    // =========================================================================
    // 4. TẠO CLOCK (50 MHz)
    // =========================================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk; 
    end

    // =========================================================================
    // 5. KHỐI GHI FILE OUTPUT (ĐỘC LẬP)
    // =========================================================================
    initial begin
        file_out = $fopen(OUT_FILE_NAME, "w");
        if (file_out == 0) begin
            $display("Error: Khong the tao file output tai %s", OUT_FILE_NAME);
            $finish;
        end
        output_count = 0;
    end

    always @(posedge clk) begin
        if (output_valid) begin
            // Ghi dữ liệu ra file (Hex 32-bit)
            $fdisplay(file_out, "%h", data_out);
            output_count = output_count + 1;
            
            // Chỉ in ra Console mỗi 5000 mẫu để đỡ lag máy
            if (output_count % 5000 == 0) begin
                $display("Status: Da ghi %d mau | Time: %t", output_count, $time);
            end
        end
    end

    // =========================================================================
    // 6. LUỒNG ĐIỀU KHIỂN CHÍNH (MAIN STIMULUS)
    // =========================================================================
    initial begin
        // A. Khởi tạo giá trị ban đầu
        rst = 1;
        sw = 2'b00;
        input_valid = 0;
        sample_in = 0;
        
        // B. Đọc file input vào RAM mô phỏng
        $display("-----------------------------------------");
        $display("Dang load file input: %s", IN_FILE_NAME);
        $readmemh(IN_FILE_NAME, memory); 
        
        // C. Reset mạch
        #100;
        rst = 0;
        #100;

        $display("BAT DAU MO PHONG (Skip %d mau dau tien)...", START_INDEX);

        // D. Vòng lặp cấp dữ liệu
        // Bắt đầu từ START_INDEX (3000) thay vì 0
        for (i = START_INDEX; i < MAX_SAMPLES; i = i + 1) begin
            
            // Nếu gặp giá trị rác (hết file) thì thoát ngay
            if (memory[i] === 16'bx) begin
                $display("Da doc het du lieu input tai dong: %d", i);
                i = MAX_SAMPLES; // Break loop
            end else begin
                
                // --- LOGIC ĐIỀU KHIỂN SWITCH THEO THỜI GIAN ---
                // Do ta bắt đầu i = 3000, mà TIME_PER_MODE = 22050
                // Nên ban đầu vẫn vào case đầu tiên (Bypass) đúng như ý muốn.
                
                if (i < TIME_PER_MODE) begin
                    sw = 2'b00; // Gốc (Bypass) - Đoạn đầu
                end else if (i < 2 * TIME_PER_MODE) begin
                    sw = 2'b01; // LPF (Low Pass) - Đoạn giữa
                end else begin
                    sw = 2'b10; // HPF (High Pass) - Đoạn cuối
                end

                // --- 1. CẤP MẪU MỚI (INPUT) ---
                sample_in = memory[i];
                input_valid = 1;
                
                @(posedge clk); 
                input_valid = 0; // Xung valid chỉ kéo dài 1 chu kỳ

                // --- 2. CHỜ MẠCH XỬ LÝ (HANDSHAKE) ---
                // Phải đợi cho đến khi mạch báo output_valid = 1
                // Nếu không đợi, Testbench chạy quá nhanh sẽ làm mất dữ liệu
                while (output_valid == 0) begin
                    @(posedge clk);
                end
                
                // Đợi thêm 1 nhịp để ổn định trước khi cấp mẫu tiếp theo
                @(posedge clk);
            end
        end

        // E. Kết thúc mô phỏng
        #1000; // Đợi chút cho mẫu cuối cùng được ghi
        $fclose(file_out);
        $display("-----------------------------------------");
        $display("MO PHONG HOAN TAT!");
        $display("File output da duoc luu tai: %s", OUT_FILE_NAME);
        $display("-----------------------------------------");
        $stop; // Dừng mô phỏng
    end

endmodule