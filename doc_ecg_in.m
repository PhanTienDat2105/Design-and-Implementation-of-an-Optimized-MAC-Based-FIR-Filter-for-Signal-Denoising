%% Đọc input_hex.txt (ECG Q1.15)
clc; clear; close all;

base = 'C:\Users\84788\Downloads\DA2\ECG_input';  % thư mục chứa file
FR = 15;                 % Q1.15
scale = 2^FR;

% Đọc file HEX, bỏ dòng trống
raw_hex = strip(readlines(fullfile(base,'input_hex.txt')));
raw_hex = raw_hex(strlength(raw_hex) > 0);

% Chuyển HEX → int16 → double
x_q15 = double(typecast(uint16(hex2dec(raw_hex)), 'int16')) / scale;

% In thông tin cơ bản
fprintf('✅ Đọc %d mẫu ECG từ input_hex.txt\n', numel(x_q15));
fprintf('  Min = %.4f,  Max = %.4f\n', min(x_q15), max(x_q15));

% (Tuỳ chọn) Vẽ nhanh để xem dạng sóng
figure('Color','w');
plot(x_q15, 'r'); grid on;
title('ECG đọc từ input\_hex.txt');
xlabel('Sample index'); ylabel('Amplitude (Q1.15)');

