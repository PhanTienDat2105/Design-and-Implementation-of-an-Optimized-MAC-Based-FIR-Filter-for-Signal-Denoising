module MAC_16Bit_Top (
    input wire clk,
    input wire rst,
    
    // Input dữ liệu
    input wire signed [15:0] x_in,
    input wire signed [15:0] y_in,
    
    // Tín hiệu điều khiển
    // 0: Load (Reset Accumulator cho phép tính mới)
    // 1: Accumulate (Cộng dồn vào kết quả trước đó)
    input wire mode_acc_in,
    
    // Output kết quả: 32-bit đã bão hòa (Saturated)
    output wire signed [31:0] mac_result_out
);

    // --- 1. DÂY NỐI GIỮA 2 STAGE ---
    wire [31:0] bridge_sum;
    wire [31:0] bridge_carry;
    
    // --- 2. PIPELINE CHO TÍN HIỆU ĐIỀU KHIỂN ---
    // Dữ liệu mất 1 chu kỳ ở Stage 1, nên tín hiệu điều khiển 
    // cũng phải trễ 1 chu kỳ để đến Stage 2 đồng bộ với dữ liệu.
    reg mode_acc_delayed;
    
    always @(posedge clk or posedge rst) begin
        if (rst) 
            mode_acc_delayed <= 1'b0;
        else      
            mode_acc_delayed <= mode_acc_in;
    end

    // --- 3. KẾT NỐI STAGE 1 ---
    Stage1_Mac16Bit stage1_inst (
        .clk(clk),
        .rst(rst),
        .x(x_in),
        .y(y_in),
        .stage1_sum(bridge_sum),
        .stage1_carry(bridge_carry),
        // Các port debug không nối
        .x_delayed(),
        .y_delayed()
    );

    // --- 4. KẾT NỐI STAGE 2 ---
    // Sử dụng module Stage2_Mac16Bit_Hoang2010 (đã cung cấp ở phản hồi trước)
    Stage2_Mac16Bit_Hoang2010 stage2_inst (
        .clk(clk),
        .rst(rst),
        .stage1_sum(bridge_sum),
        .stage1_carry(bridge_carry),
        .mode_accumulate(mode_acc_delayed), // Dùng tín hiệu đã làm trễ
        .mac_output(mac_result_out)
    );

endmodule