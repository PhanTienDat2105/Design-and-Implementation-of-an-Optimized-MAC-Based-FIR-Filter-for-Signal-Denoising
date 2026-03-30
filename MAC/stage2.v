module Stage2_Mac16Bit_Hoang2010 (
    input wire clk,
    input wire rst,
    input wire [31:0] stage1_sum,    // Vector S từ Stage 1
    input wire [31:0] stage1_carry,  // Vector C từ Stage 1
    input wire mode_accumulate,      // 1: Accumulate, 0: Reset/Load
    
    // Output R[2N-1:0] (32-bit)
    output reg signed [31:0] mac_output
);

    // --- THAM SỐ ---
    localparam N = 16;
    localparam Ng = 8; // Số bit Guard [cite: 2]
    
    // --- 1. CHUẨN BỊ DỮ LIỆU (DATA ALIGNMENT) ---
    // Vector Correction: Mô phỏng các bit '1' được chèn vào (Fig. 4) [cite: 204]
    // Thay vì nối dây thủ công từng cổng logic như Fig. 4, ta dùng vector hằng số
    // để cộng vào ở bước cuối, kết quả tương đương logic bù Baugh-Wooley.
    wire [39:0] correction = 40'hFF80010000;

    // Mở rộng input từ Stage 1 lên 40 bit
    wire [39:0] s_ext = {8'd0, stage1_sum};
    
    // Carry từ Stage 1 cần dịch trái 1 bit (vì bản chất nó là Carry)
    wire [39:0] c_ext = {8'd0, stage1_carry[30:0], 1'b0};
    
    // Lấy giá trị hồi tiếp từ thanh ghi Accumulate (F)
    reg signed [39:0] reg_accumulate;
    wire [39:0] feedback_f;
    
    // Nếu mode = 0 (Load) thì Feedback = 0, ngược lại là giá trị cũ
    assign feedback_f = (mode_accumulate) ? reg_accumulate : 40'd0;

    // --- 2. KHỐI CARRY-SAVE ADDER (CSA) - CỐT LÕI CỦA BÀI BÁO ---
    // Thay vì viết (s + c + f), ta tách rõ ra M và K như Fig. 2 [cite: 182, 183, 185]
    // CSA gồm các bộ Full Adder (3:2 Compressor) thực hiện song song từng bit.
    
    wire [39:0] M; // Vector Sum (từ CSA)
    wire [39:0] K; // Vector Carry (từ CSA)

    // Logic của Full Adder: Sum = A ^ B ^ C
    assign M = s_ext ^ c_ext ^ feedback_f;

    // Logic của Full Adder: Carry_out = (A&B) | (A&C) | (B&C)
    // Lưu ý: Carry output của CSA phải dịch trái 1 bit trước khi vào bộ cộng sau
    assign K = ((s_ext & c_ext) | (s_ext & feedback_f) | (c_ext & feedback_f)) << 1;

    // --- 3. KHỐI ACCUMULATE ADDER (Cộng lan truyền nhớ) ---
    // Đây là nơi duy nhất xảy ra cộng lan truyền (Carry Propagation) trong Stage 2.
    // Thực hiện cộng: G = M + K + Correction (Fig. 2 )
    
    wire signed [39:0] G;
    assign G = M + K + correction; 

    // --- 4. SATURATION UNIT (Khối Bão Hòa) ---
    // Thuật toán dựa trên logic mô tả ở trang 3074, cột trái [cite: 313]
    
    reg [31:0] saturated_result;
    wire [7:0] guard_bits = G[39:32]; // G[2N+Ng-1 : 2N]
    wire       sign_bit   = G[31];    // G[2N-1]
    
    // Tạo vector so sánh: Ng'b(sign_bit)
    wire [7:0] sign_extension_check = {8{sign_bit}};

    always @(*) begin
        // IF Guard Bits == Sign Bit (Extension) -> Không tràn
        if (guard_bits == sign_extension_check) begin
            saturated_result = G[31:0];
        end
        // ELSE IF Bit dấu cao nhất là '1' -> Tràn Âm (Underflow)
        else if (G[39] == 1'b1) begin
            // Min negative value: 100...00
            saturated_result = {1'b1, 31'd0}; 
        end
        // ELSE -> Tràn Dương (Overflow)
        else begin
            // Max positive value: 011...11
            saturated_result = {1'b0, {31{1'b1}}};
        end
    end

    // --- 5. THANH GHI OUTPUT & FEEDBACK ---
    // Cập nhật giá trị cho chu kỳ sau
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_accumulate <= 40'd0; // Reset F
            mac_output     <= 32'd0; // Reset R
        end else begin
            reg_accumulate <= G;                // Lưu G vào F (Fig. 2 [cite: 115, 116])
            mac_output     <= saturated_result; // Lưu kết quả bão hòa ra output R
        end
    end

endmodule