`timescale 1ns / 1ps

module tb_MAC_16Bit_Top;

    // Inputs
    reg clk;
    reg rst;
    reg signed [15:0] x_in;
    reg signed [15:0] y_in;
    reg mode_acc_in;

    // Outputs
    wire signed [31:0] mac_result_out;

    // Instantiate the Unit Under Test (UUT)
    MAC_16Bit_Top uut (
        .clk(clk), 
        .rst(rst), 
        .x_in(x_in), 
        .y_in(y_in), 
        .mode_acc_in(mode_acc_in), 
        .mac_result_out(mac_result_out)
    );

    // Tạo Clock (Chu kỳ 10ns -> 100MHz)
    always #5 clk = ~clk;

    initial begin
        // Khởi tạo
        clk = 0;
        rst = 1;
        x_in = 0;
        y_in = 0;
        mode_acc_in = 0;

        // Reset hệ thống
        #20;
        rst = 0;
        #10;

        // ==========================================
        // TEST CASE 1: PHÉP NHÂN ĐƠN LẺ (Load Mode)
        // Tính: 10 * 20 = 200
        // ==========================================
        $display("--- TEST 1: Multiply 10 * 20 ---");
        
        // Cycle 0: Input
        x_in = 16'd10;
        y_in = 16'd20;
        mode_acc_in = 1'b0; // 0 = Load (Không cộng kết quả cũ)
        
        #10; // Chờ 1 chu kỳ (Clock edge)
        
        // Cycle 1: Dữ liệu đang ở Stage 1. Input tiếp theo (Dummy)
        x_in = 16'd0;
        y_in = 16'd0;
        mode_acc_in = 1'b0;
        
        #10; // Chờ 1 chu kỳ
        
        // Cycle 2: Kết quả xuất hiện ở Output
        #1; // Delay nhỏ để ổn định tín hiệu hiển thị
        $display("Time: %t | Inputs: 10*20 | Result: %d (Expected: 200)", $time, mac_result_out);
        
        
        // ==========================================
        // TEST CASE 2: MULTIPLY-ACCUMULATE (MAC)
        // Tính: (100 * 5) + (200 * 2) + (50 * 4) = 500 + 400 + 200 = 1100
        // ==========================================
        $display("\n--- TEST 2: MAC Sequence (500 + 400 + 200) ---");
        
        // Step 1: 100 * 5 (Load - Reset acc cũ)
        x_in = 16'd100; y_in = 16'd5; mode_acc_in = 1'b0; // Reset
        #10;
        
        // Step 2: 200 * 2 (Acc - Cộng dồn)
        x_in = 16'd200; y_in = 16'd2; mode_acc_in = 1'b1; // Accumulate
        #10;
        
        // Step 3: 50 * 4 (Acc)
        x_in = 16'd50;  y_in = 16'd4; mode_acc_in = 1'b1; // Accumulate
        #10;
        
        // Step 4: Dummy input để đẩy kết quả ra
        x_in = 0; y_in = 0; mode_acc_in = 1'b1;
        #10; // Đợi Pipeline Stage 1
        #10; // Đợi Pipeline Stage 2 (Lúc này kết quả của Step 3 mới ra)
        
        // Lúc này output phải là tổng tích lũy
        $display("Time: %t | MAC Result: %d (Expected: 1100)", $time, mac_result_out);


        // ==========================================
        // TEST CASE 3: SATURATION (BÃO HÒA)
        // Tính: Max_Int16 * Max_Int16 cộng dồn nhiều lần để tràn 32-bit
        // Max 16-bit signed = 32767.
        // 32767 * 32767 approx 1 tỷ. Max 32-bit signed approx 2.14 tỷ.
        // Cộng 3 lần sẽ tràn.
        // ==========================================
        $display("\n--- TEST 3: Saturation Logic ---");
        
        // Lần 1: Số dương lớn
        x_in = 16'd32767; y_in = 16'd32767; mode_acc_in = 1'b0; // Reset
        #10;
        
        // Lần 2: Cộng thêm số dương lớn
        x_in = 16'd32767; y_in = 16'd32767; mode_acc_in = 1'b1; // Acc
        #10;
        
        // Lần 3: Cộng tiếp (Sẽ tràn)
        x_in = 16'd32767; y_in = 16'd32767; mode_acc_in = 1'b1; // Acc
        #10;
        
        // Chờ kết quả lan truyền ra
        x_in = 0; y_in = 0; mode_acc_in = 1;
        #10;
        #10; 
        
        #1;
        // Kết quả mong đợi: 2147483647 (Max 32-bit signed)
        $display("Time: %t | Saturated Result: %d", $time, mac_result_out);
        if (mac_result_out == 2147483647)
            $display(">> SUCCESS: Output saturated correctly at MAX_INT.");
        else
            $display(">> FAILURE: Output did not saturate correctly.");

        #20;
        $finish;
    end

endmodule