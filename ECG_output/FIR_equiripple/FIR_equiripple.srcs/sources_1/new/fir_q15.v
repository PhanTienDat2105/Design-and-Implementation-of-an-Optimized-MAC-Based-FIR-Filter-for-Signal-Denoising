`timescale 1ns/1ps
module fir_q15 #(
    parameter integer N  = 117,   // số tap (khớp với coeffs_hex.txt)
    parameter integer IW = 16,    // input width
    parameter integer CW = 16,    // coeff width
    parameter integer FR = 15,    // fractional bits Q1.15
    parameter integer OW = 40     // output accumulator width
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    in_valid,
    input  wire signed [IW-1:0]    x_in,
    output reg                     out_valid,
    output reg  signed [IW-1:0]    y_out
);
    // ============ MEMORY FOR COEFFS ============
    reg signed [CW-1:0] h [0:N-1];

    // ============ SHIFT REGISTER ===============
    reg signed [IW-1:0] x_reg [0:N-1];
    integer i;

    // ============ MAC ==========================
    reg signed [OW-1:0] acc;
    reg signed [OW-1:0] mac_temp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i=0; i<N; i=i+1)
                x_reg[i] <= 0;
            acc       <= 0;
            y_out     <= 0;
            out_valid <= 0;
        end else begin
            if (in_valid) begin
                // shift input
                for (i=N-1; i>0; i=i-1)
                    x_reg[i] <= x_reg[i-1];
                x_reg[0] <= x_in;

                // multiply-accumulate
                mac_temp = 0;
                for (i=0; i<N; i=i+1)
                    mac_temp = mac_temp + x_reg[i] * h[i];

                // scale về Q1.15 (giảm FR bit)
                acc = mac_temp >>> FR;

                // saturation về 16-bit signed
                if (acc > 32767)
                    y_out <= 32767;
                else if (acc < -32768)
                    y_out <= -32768;
                else
                    y_out <= acc[15:0];

                out_valid <= 1'b1;
            end else begin
                out_valid <= 1'b0;
            end
        end
    end
endmodule
