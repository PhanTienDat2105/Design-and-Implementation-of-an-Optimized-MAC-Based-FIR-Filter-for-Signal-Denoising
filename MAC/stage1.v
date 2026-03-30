module Stage1_Mac16Bit (
    input wire clk,
    input wire rst,
    input wire signed [15:0] x, // Input 16-bit
    input wire signed [15:0] y, // Input 16-bit
    
    // Output 2 vector đã nén (chuẩn bị cho Stage 2)
    // Độ rộng vector khoảng 32 bit cho tích 16x16
    output reg [31:0] stage1_sum,
    output reg [31:0] stage1_carry,
    
    // Debug signals (Pipeline delay)
    output reg signed [15:0] x_delayed,
    output reg signed [15:0] y_delayed
);

    // --- 1. TẠO TÍCH RIÊNG (PARTIAL PRODUCT GENERATION - PPG) ---
    // Ma trận 16x16 bit
    wire [15:0] pp [15:0]; 
    
    genvar i, j;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ROW
            for (j = 0; j < 16; j = j + 1) begin : COL
                if (i == 15 && j == 15)
                    assign pp[i][j] = x[i] & y[j];      // Bit dấu x Bit dấu: Giữ nguyên
                else if (i == 15 || j == 15)
                    assign pp[i][j] = ~(x[i] & y[j]);   // Hàng/Cột chứa bit dấu: Đảo (NAND)
                else
                    assign pp[i][j] = x[i] & y[j];      // Các bit khác: AND
            end
        end
    endgenerate

    // --- 2. NÉN TÍCH RIÊNG (LINEAR CSA REDUCTION TREE) ---
    // Chúng ta cần cộng 16 hàng số (mỗi hàng dịch trái tương ứng trọng số)
    // Tôi dùng mảng 'rows' để biểu diễn các hàng số này (đã mở rộng lên 32 bit)
    wire [31:0] rows [15:0];
    
    generate
        for (i = 0; i < 16; i = i + 1) begin : SHIFT_ROWS
            assign rows[i] = {16'b0, pp[i]} << i; // Dịch hàng i sang trái i bit
        end
    endgenerate

    // Mảng trung gian để lưu Sum và Carry qua từng lớp nén
    // Cần nén 16 hàng -> cần 14 lớp CSA (mỗi lớp nén thêm 1 hàng mới vào)
    wire [31:0] temp_sum [14:0];
    wire [31:0] temp_carry [14:0];

    // Lớp đầu tiên: Nén 3 hàng đầu (Row 0, 1, 2)
    assign temp_sum[0]   = rows[0] ^ rows[1] ^ rows[2];
    assign temp_carry[0] = (rows[0] & rows[1]) | (rows[0] & rows[2]) | (rows[1] & rows[2]);

    // Các lớp tiếp theo: Nén (Sum cũ, Carry cũ << 1, Row mới)
    generate
        for (i = 1; i < 14; i = i + 1) begin : CSA_LAYERS
            wire [31:0] in_a = temp_sum[i-1];
            wire [31:0] in_b = {temp_carry[i-1][30:0], 1'b0}; // Carry phải dịch trái 1 bit
            wire [31:0] in_c = rows[i+2]; // Row tiếp theo (bắt đầu từ row 3)

            assign temp_sum[i]   = in_a ^ in_b ^ in_c;
            assign temp_carry[i] = (in_a & in_b) | (in_a & in_c) | (in_b & in_c);
        end
    endgenerate
    
    // --- 3. PIPELINE REGISTERS ---
    // Chốt kết quả của lớp nén cuối cùng (lớp 13)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage1_sum   <= 32'd0;
            stage1_carry <= 32'd0;
            x_delayed    <= 16'd0;
            y_delayed    <= 16'd0;
        end else begin
            stage1_sum   <= temp_sum[13];
            stage1_carry <= temp_carry[13]; // Lưu raw carry (sẽ dịch ở Stage 2)
            x_delayed    <= x;
            y_delayed    <= y;
        end
    end

endmodule