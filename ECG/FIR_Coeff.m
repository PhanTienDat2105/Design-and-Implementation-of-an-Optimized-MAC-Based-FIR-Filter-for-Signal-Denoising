clc; clear; close all;

%% Setup
dbDir   = 'D:\Do_An_2\ecg-id-database-1.0.0';
person  = 'Person_01';
record  = 'rec_2';
secs    = 5;             

%% Read file 
oldDir = pwd;
cd(fullfile(dbDir, person));
[ecg, Fs, tm] = rdsamp(record, [], secs*500);
cd(oldDir);

x = ecg(:,1);   % raw ECG (lead 1)

% DB Filtered
if size(ecg,2) >= 2
    x_filtered_db = ecg(:,2);
else
    x_filtered_db = [];
end

%% FIR Equiripple LPF (Optimized for fewer taps)
Fp  = 30;    % Giảm Fp xuống 30Hz để nới rộng vùng chuyển tiếp
Fst = 50;    % Giữ nguyên 50Hz để cắt nhiễu điện
Rp  = 0.5;   
Ast = 50;    % Giảm Ast xuống 50dB (vẫn đủ tốt để lọc nhiễu)

d = designfilt('lowpassfir', ...
    'PassbandFrequency',   Fp, ...
    'StopbandFrequency',   Fst, ...
    'PassbandRipple',      Rp, ...
    'StopbandAttenuation', Ast, ...
    'DesignMethod',        'equiripple', ...
    'SampleRate',          Fs);

b = d.Coefficients;
% Kiểm tra số lượng taps
fprintf('Số lượng taps mới: %d\n', length(b)); 

y_hp = filter(b, 1, x);

%% ==========================================================
%% PHẦN BỔ SUNG: XUẤT FILE HEX VÀ COE
%% ==========================================================

% Cấu hình độ rộng bit cho FPGA (thường là 16-bit)
BIT_WIDTH = 16;
% Hệ số nhân để chuyển từ số thực sang số nguyên (Q1.15)
% Phạm vi biểu diễn: -32768 đến +32767
SCALE_FACTOR = 2^(BIT_WIDTH-1) - 1; 

%% 1. Xuất file Input (ecg_input.txt) giống định dạng ecg_raw_hex.txt
% Tín hiệu x hiện tại là đơn vị mV (float). Cần scale lên để thành số nguyên.
% Ta sẽ chuẩn hóa x về khoảng -1 đến 1 trước, sau đó nhân với SCALE_FACTOR.
max_val = max(abs(x));
if max_val == 0
    max_val = 1; % Tránh chia cho 0
end
x_norm = x / max_val;             % Đưa về khoảng -1...1
x_fixed = round(x_norm * 0.9 * SCALE_FACTOR); % Nhân hệ số, nhân 0.9 để giữ khoảng dự trữ (headroom)

% Chuyển sang int16
x_int16 = int16(x_fixed);

filename_input = 'ecg_input.txt';
fid_in = fopen(filename_input, 'w');

fprintf('Đang xuất file input: %s ...\n', filename_input);
for i = 1:length(x_int16)
    % typecast chuyển int16 sang uint16 để dec2hex hiểu được số âm (bù 2)
    hex_val = dec2hex(typecast(x_int16(i), 'uint16'), 4);
    fprintf(fid_in, '%s\n', hex_val);
end
fclose(fid_in);
fprintf('-> Xong. Đã lưu file input.\n');

%% 2. Xuất file Hệ số bộ lọc (filter_coeffs.coe) - Đã sửa cho Block Memory Generator
% Hệ số b thường rất nhỏ, nhân với SCALE_FACTOR
b_fixed = round(b * SCALE_FACTOR);
b_int16 = int16(b_fixed);

filename_coe = 'filter_coeffs.coe';
fid_coe = fopen(filename_coe, 'w');

fprintf('Đang xuất file hệ số: %s ...\n', filename_coe);

% --- SỬA ĐỔI QUAN TRỌNG Ở ĐÂY ---
% Định dạng chuẩn cho Xilinx Block Memory Generator
fprintf(fid_coe, 'memory_initialization_radix=16;\n');
fprintf(fid_coe, 'memory_initialization_vector=\n');
% ---------------------------------

for i = 1:length(b_int16)
    hex_val = dec2hex(typecast(b_int16(i), 'uint16'), 4);
    
    if i == length(b_int16)
        % Hệ số cuối cùng kết thúc bằng dấu chấm phẩy
        fprintf(fid_coe, '%s;', hex_val);
    else
        % Các hệ số khác ngăn cách bằng dấu phẩy và xuống dòng
        fprintf(fid_coe, '%s,\n', hex_val);
    end
end
fclose(fid_coe);
fprintf('-> Xong. Đã lưu file COE đúng chuẩn Block Memory.\n');

%% Kiểm tra lại dữ liệu xuất (Plot thử để chắc chắn không bị tràn số)
figure('Color','w');
plot(x_fixed); grid on;
title('Dữ liệu đã Quantize (Fixed-point) chuẩn bị đưa vào FPGA');
ylabel('Amplitude (Integer 16-bit)');
xlabel('Sample');