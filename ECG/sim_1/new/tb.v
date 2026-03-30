`timescale 1ns / 1ps

module tb_FIR_Filter_Top;

    // --- 1. KHAI BÁO THAM SỐ VÀ FILE ---
    parameter TAPS = 54;
    parameter DATA_WIDTH = 16;
    
    // Đường dẫn file (Lưu ý: Dùng dấu gạch chéo '/' thay vì '\')
    localparam IN_FILE_NAME  = "D:/Do_An_2/ECG/ecg_input.txt";
    localparam OUT_FILE_NAME = "D:/Do_An_2/ECG/ecg_output.txt";

    // --- 2. KHAI BÁO TÍN HIỆU KẾT NỐI DUT (Device Under Test) ---
    reg clk;
    reg rst;
    
    // Tín hiệu vào
    reg input_valid;
    reg signed [DATA_WIDTH-1:0] sample_in;
    
    // Tín hiệu ra
    wire output_valid;
    wire signed [31:0] data_out;

    // Biến hỗ trợ đọc/ghi file
    integer in_file;
    integer out_file;
    integer read_status;
    reg [DATA_WIDTH-1:0] temp_read_data; // Biến tạm để đọc hex từ file

    // --- 3. INSTANTIATE MODULE CHÍNH ---
    FIR_Filter_Top #(
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .input_valid(input_valid),
        .sample_in(sample_in),
        .output_valid(output_valid),
        .data_out(data_out)
    );

    // --- 4. TẠO CLOCK ---
    // Tạo clock 100MHz (Chu kỳ 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- 5. KHỐI XỬ LÝ CHÍNH (STIMULUS) ---
    initial begin
        // A. Khởi tạo giá trị ban đầu
        rst = 1;            // Đang giữ reset
        input_valid = 0;
        sample_in = 0;
        
        // B. Mở file
        in_file = $fopen(IN_FILE_NAME, "r");
        out_file = $fopen(OUT_FILE_NAME, "w");

        // Kiểm tra xem file có mở được không
        if (in_file == 0) begin
            $display("LOI: Khong the mo file input tai %s", IN_FILE_NAME);
            $stop;
        end
        if (out_file == 0) begin
            $display("LOI: Khong the tao file output tai %s", OUT_FILE_NAME);
            $stop;
        end

        // C. Reset hệ thống
        $display("Dang reset he thong...");
        #100;           // Đợi 100ns
        rst = 0;        // Thả reset
        #50;            // Đợi ổn định

        // D. Vòng lặp đọc và xử lý dữ liệu
        $display("Bat dau xu ly du lieu ECG...");
        
        while (!$feof(in_file)) begin
            // Đọc dữ liệu hex từ file (%h: hex, %d: decimal)
            // Giả sử file chứa mã hex dạng: 00A1
            read_status = $fscanf(in_file, "%h\n", temp_read_data);

            if (read_status == 1) begin
                // 1. Đồng bộ với cạnh lên clock
                @(posedge clk);
                
                // 2. Gửi dữ liệu vào Module
                sample_in <= temp_read_data;
                input_valid <= 1'b1; // Báo hiệu có mẫu mới

                // 3. Giữ tín hiệu input_valid trong 1 chu kỳ clock
                @(posedge clk);
                input_valid <= 1'b0; // Hạ cờ sau khi gửi xong

                // 4. Đợi Module xử lý xong (Chờ tín hiệu output_valid lên 1)
                // Lưu ý: Module FIR cần chạy 117 vòng lặp nên sẽ tốn thời gian
                wait(output_valid == 1'b1);
                
                // 5. Ghi kết quả ra file
                // Ghi dưới dạng số nguyên có dấu (Signed Decimal) để dễ vẽ đồ thị
                $fdisplay(out_file, "%d", data_out);
                
                // (Tùy chọn) In ra màn hình console để debug vài mẫu đầu
                // $display("Input: %h -> Output: %d", temp_read_data, data_out);

                // 6. Đợi output_valid hạ xuống (để chuẩn bị cho mẫu tiếp theo)
                @(negedge output_valid);
                
                // Thêm một khoảng delay nhỏ giữa các mẫu (giả lập tốc độ lấy mẫu thực tế)
                // Nếu muốn chạy nhanh nhất có thể thì comment dòng dưới
                #20; 
            end
        end

        // E. Kết thúc mô phỏng
        $display("Xu ly xong! Ket qua luu tai: %s", OUT_FILE_NAME);
        $fclose(in_file);
        $fclose(out_file);
        #100;
        $stop;
    end

endmodule