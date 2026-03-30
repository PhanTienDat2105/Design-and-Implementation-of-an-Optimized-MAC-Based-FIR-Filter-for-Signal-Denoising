(* use_dsp = "no" *)
module MAC_Normal (
    input clk, rst,
    input signed [15:0] x, y,
    input mode,
    output signed [31:0] out
);
    // 1. THÊM THANH GHI ĐỆM ĐẦU VÀO (Input Registers)
    reg signed [15:0] r_x, r_y;
    
    // 2. CÁC THANH GHI CŨ
    reg signed [31:0] product_reg;
    reg signed [31:0] acc_reg;
    
    // Buffer đầu vào (Để biến phép nhân thành đường nội bộ)
    always @(posedge clk) begin
        r_x <= x;
        r_y <= y;
    end

    // Stage 1: Nhân (Bây giờ là từ r_x, r_y -> product_reg)
    // Vivado SẼ PHẢI báo cáo delay của đoạn này!
    always @(posedge clk or posedge rst) begin
        if(rst) product_reg <= 0;
        else    product_reg <= r_x * r_y; 
    end

    // Stage 2: Cộng dồn (Giữ nguyên)
    always @(posedge clk or posedge rst) begin
        if(rst) acc_reg <= 0;
        else begin
            if(!mode) acc_reg <= product_reg;
            else      acc_reg <= acc_reg + product_reg;
        end
    end
    
    assign out = acc_reg;
endmodule