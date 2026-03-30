clc; clear; close all;

% --- ĐƯỜNG DẪN OUTPUT CỦA VIVADO ---
fout = 'C:\Users\84788\Downloads\DA2\ECG_output\FIR_equiripple\FIR_equiripple.sim\sim_1\behav\xsim\output_hex.txt';

FR = 15;                      % Q1.15
scale = 2^FR;

% Đọc file HEX, bỏ dòng trống
assert(isfile(fout), 'Không tìm thấy file: %s', fout);
raw = strip(readlines(fout));
raw = raw(strlength(raw) > 0);

% Chuyển HEX -> int16 (2’s complement) -> double [-1, 1)
y_q15 = double(typecast(uint16(hex2dec(raw)), 'int16')) / scale;

fprintf('✅ Đọc %d mẫu từ:\n  %s\n', numel(y_q15), fout);
fprintf('   Min = %.4f,  Max = %.4f\n', min(y_q15), max(y_q15));

% Vẽ
figure('Color','w');
plot(y_q15); grid on;
xlabel('Sample index'); ylabel('Amplitude (Q1.15)');
title('ECG Output từ FIR (Vivado)');
