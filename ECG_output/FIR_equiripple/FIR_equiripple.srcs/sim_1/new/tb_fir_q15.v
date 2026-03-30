`timescale 1ns/1ps
module tb_fir_q15;
    // ===== cấu hình =====
    localparam integer N         = 117;      // số TAP (khớp coeffs_hex.txt)
    localparam integer STIM_LEN  = 2500;     // số mẫu (khớp input_hex.txt)
    localparam integer IW=16, CW=16, FR=15, OW=40;

    // Độ trễ pipeline của FIR (nếu DUT trễ 1 ck thì đặt 1)
    localparam integer LAT = 2;

    // clock 100 MHz
    reg clk = 0; always #5 clk = ~clk;

    // reset & I/O
    reg  rst;
    reg         in_valid;
    reg  signed [IW-1:0] x_in;
    wire        out_valid;
    wire signed [IW-1:0] y_out;

    // DUT
    fir_q15 #(.N(N),.IW(IW),.CW(CW),.FR(FR),.OW(OW)) dut (
        .clk(clk), .rst(rst),
        .in_valid(in_valid),
        .x_in(x_in),
        .out_valid(out_valid),
        .y_out(y_out)
    );

    // memories
    reg signed [IW-1:0] stim_mem   [0:STIM_LEN-1];
    reg signed [CW-1:0] coeffs_mem [0:N-1];

    integer i, fin, fout;
    integer out_cnt, write_cnt;
    integer TARGET, WARM;

    // ===== Block 1: reset chủ động =====
    initial begin
        rst      = 1'b1;
        in_valid = 1'b0;
        x_in     = {IW{1'b0}};
        #100;  // 100 ns
        @(posedge clk);
        rst <= 1'b0;
        $display("[%0t] RESET deasserted", $time);
    end

    // ===== Block 2: nạp file + chạy feed =====
    initial begin
        // chờ reset nhả
        @(negedge rst);

        // ----- INPUT -----
        fin = $fopen("C:/Users/84788/Downloads/DA2/ECG_input/input_hex.txt","r");
        if (fin==0) $fatal(1,"input_hex.txt NOT found");
        $fclose(fin);
        $readmemh("C:/Users/84788/Downloads/DA2/ECG_input/input_hex.txt", stim_mem);
        $display("[%0t] input loaded. stim_mem[0]=%h stim_mem[1]=%h",
                 $time, stim_mem[0], stim_mem[1]);

        // ----- COEFFS (fallback IMPULSE nếu thiếu) -----
        fin = $fopen("C:/Users/84788/Downloads/DA2/ECG_input/coeffs_hex.txt","r");
        if (fin==0) begin
            $display("[%0t] WARN: coeffs_hex.txt not found -> using IMPULSE", $time);
            for (i=0;i<N;i=i+1) dut.h[i] = {CW{1'b0}};
            dut.h[0] = 16'sh7FFF; // ~1.0 Q1.15
        end else begin
            $fclose(fin);
            $readmemh("C:/Users/84788/Downloads/DA2/ECG_input/coeffs_hex.txt", coeffs_mem);
            for (i=0;i<N;i=i+1) dut.h[i] = coeffs_mem[i];
            $display("[%0t] coeffs loaded. h[0]=%h h[1]=%h", $time, coeffs_mem[0], coeffs_mem[1]);
        end

        // ----- OPEN OUTPUT (ghi đúng 2500 dòng) -----
        fout = $fopen("C:/Users/84788/Downloads/DA2/ECG_output/FIR_equiripple/FIR_equiripple.sim/sim_1/behav/xsim/output_hex.txt","w");
        if (fout==0) $fatal(1,"cannot open output_hex.txt for write");

        // Thiết lập bộ đếm
        out_cnt   = 0;                         // đếm mọi lần out_valid=1 (bao gồm quá độ)
        write_cnt = 0;                         // đã ghi bao nhiêu dòng vào file
        WARM      = (N-1) + LAT;               // số mẫu quá độ cần bỏ
        TARGET    = STIM_LEN;                  // CHỈ muốn ghi đúng 2500 mẫu

        // 1 chu kỳ "idle" sau reset
        @(posedge clk);

        // ----- FEED dữ liệu -----
        for (i=0; i<STIM_LEN; i=i+1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            x_in     <= stim_mem[i];

            if (out_valid) begin
                out_cnt = out_cnt + 1;
                if (out_cnt > WARM && write_cnt < TARGET) begin
                    $fdisplay(fout,"%h",$unsigned(y_out));
                    write_cnt = write_cnt + 1;
                end
            end
        end

        // ----- FLUSH: GIỮ in_valid=1 để đẩy đuôi (không ghi quá TARGET) -----
        repeat (N-1 + LAT + 2) begin
            @(posedge clk);
            in_valid <= 1'b1;
            x_in     <= {IW{1'b0}};
            if (out_valid) begin
                out_cnt = out_cnt + 1;
                if (out_cnt > WARM && write_cnt < TARGET) begin
                    $fdisplay(fout,"%h",$unsigned(y_out));
                    write_cnt = write_cnt + 1;
                end
            end
        end

        // Hạ cờ vài ck cho chắc (không ghi quá TARGET)
        repeat (2) begin
            @(posedge clk);
            in_valid <= 1'b0;
            x_in     <= {IW{1'b0}};
            if (out_valid) begin
                out_cnt = out_cnt + 1;
                if (out_cnt > WARM && write_cnt < TARGET) begin
                    $fdisplay(fout,"%h",$unsigned(y_out));
                    write_cnt = write_cnt + 1;
                end
            end
        end

        $fclose(fout);
        $display("[%0t] DONE. Wrote %0d lines (TARGET = %0d)", $time, write_cnt, TARGET);
        $finish;
    end
endmodule
