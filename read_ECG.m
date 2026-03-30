clc;
clear;
close all;

% --- 1. Cấu hình đường dẫn file (Theo yêu cầu của bạn) ---
input_file_path  = 'C:/Users/84788/Downloads/DO_AN_2/DA2/ECG/ecg_input.txt';
output_file_path = 'C:/Users/84788/Downloads/DO_AN_2/DA2/ECG/ecg_output.txt';

% --- 2. Đọc file ECG Input (Dạng HEX) ---
% Mở file
fid_in = fopen(input_file_path, 'r');
if fid_in == -1
    error('Không thể mở file Input. Vui lòng kiểm tra lại đường dẫn.');
end

% Đọc dữ liệu Hex dưới dạng chuỗi
raw_hex = textscan(fid_in, '%s');
fclose(fid_in);
hex_values = raw_hex{1};

% Chuyển đổi Hex sang Decimal (Unsigned)
input_signal = hex2dec(hex_values);

% Xử lý số có dấu 16-bit (Signed 16-bit Two's Complement)
% Nếu giá trị >= 0x8000 (32768), nó là số âm
idx_neg = input_signal >= 32768; 
input_signal(idx_neg) = input_signal(idx_neg) - 65536;

% --- 3. Đọc file ECG Output (Dạng Decimal) ---
% File output thường là số thập phân có dấu sẵn
try
    output_signal = load(output_file_path);
catch
    % Trường hợp load() lỗi do định dạng, dùng textscan an toàn hơn
    fid_out = fopen(output_file_path, 'r');
    if fid_out == -1
        error('Không thể mở file Output. Vui lòng kiểm tra lại đường dẫn.');
    end
    raw_out = textscan(fid_out, '%f');
    fclose(fid_out);
    output_signal = raw_out{1};
end

% --- 4. Vẽ đồ thị (Plot) ---
figure('Name', 'ECG Signal Verification', 'Color', 'w');

% Subplot 211: Input
subplot(2, 1, 1);
plot(input_signal, 'b', 'LineWidth', 1);
title('ECG Input (Hex parsed to Signed 16-bit)');
ylabel('Amplitude');
grid on;
xlim([1 length(input_signal)]);

% Subplot 212: Output
subplot(2, 1, 2);
plot(output_signal, 'r', 'LineWidth', 1);
title('ECG Output (Processed Signal)');
xlabel('Sample Index');
ylabel('Amplitude');
grid on;
xlim([1 length(output_signal)]);

fprintf('Đã vẽ xong tín hiệu!\n');
fprintf('Số mẫu Input: %d\n', length(input_signal));
fprintf('Số mẫu Output: %d\n', length(output_signal));