clear; clc;

%% 1. CẤU HÌNH TÊN FILE
input_wav = '1.wav';          % Tên file âm thanh đầu vào
output_txt = 'audio_hex.txt'; % Tên file Hex đầu ra

%% 2. ĐỌC VÀ XỬ LÝ TÍN HIỆU
if ~isfile(input_wav)
    error('Khong tim thay file %s', input_wav);
end

[x, Fs] = audioread(input_wav);

% Chuyển sang Mono (nếu là Stereo) bằng cách lấy trung bình cộng
if size(x, 2) > 1
    x = mean(x, 2);
end

% Chuẩn hóa biên độ (Optional): Đảm bảo tín hiệu không quá nhỏ hoặc quá to
% x = x / max(abs(x)); 

%% 3. CHUYỂN ĐỔI SANG FIXED-POINT 16-BIT (Q1.15)
% Audio trong Matlab là Float [-1.0, 1.0]. 
% Cần nhân với 2^15 (32768) để ra số nguyên 16-bit [-32768, 32767]
x_fixed = round(x * 32768);

% Xử lý tràn số (Saturation) - Quan trọng!
% Nếu giá trị vượt quá giới hạn 16-bit, phải cắt bỏ để tránh lỗi đảo dấu
x_fixed(x_fixed > 32767) = 32767;
x_fixed(x_fixed < -32768) = -32768;

%% 4. CHUYỂN SANG HEX VÀ GHI FILE
% Sử dụng mod(..., 65536) để chuyển số âm sang mã bù 2 (Two's Complement)
% Ví dụ: -1 -> FFFF, -2 -> FFFE
x_hex = dec2hex(mod(x_fixed, 65536), 4);

% Ghi ra file text
fid = fopen(output_txt, 'w');
if fid == -1
    error('Khong the tao file output.');
end

% Ghi từng dòng (Mỗi dòng 1 mẫu Hex 4 ký tự)
for i = 1:size(x_hex, 1)
    fprintf(fid, '%s\r\n', x_hex(i, :));
end

fclose(fid);

%% 5. THÔNG BÁO
fprintf('------------------------------------------------\n');
fprintf('XU LY HOAN TAT!\n');
fprintf('File dau vao: %s (Fs = %d Hz)\n', input_wav, Fs);
fprintf('So luong mau: %d samples\n', length(x));
fprintf('File dau ra : %s\n', output_txt);
fprintf('Dinh dang   : 16-bit Hex (Signed 2''s Complement)\n');
fprintf('------------------------------------------------\n');

%% 2. THIẾT LẬP THÔNG SỐ (FIX SỐ TAP < 100)
% Để giảm tap, ta dùng phương pháp cửa sổ (Window) hoặc ép bậc.
% Ở đây tôi chọn ép bậc cố định là 80 (Filter Order = 80 -> 81 taps hoặc 80 taps tùy loại)
N_order = 80; 
F_cutoff = 1200; % Tần số cắt chung cho cả 2 bộ lọc

%% 3. TẠO BỘ LỌC LOW PASS (Lấy tiếng đàn)
% Dùng 'FilterOrder' để ép số lượng hệ số
d_lpf = designfilt('lowpassfir', ...
    'FilterOrder',      N_order, ...
    'CutoffFrequency',  F_cutoff, ... 
    'DesignMethod',     'window', ... % Dùng phương pháp cửa sổ cho gọn
    'SampleRate',       Fs);

% Lọc tín hiệu
y_guitar = filtfilt(d_lpf, x);

%% 4. TẠO BỘ LỌC HIGH PASS (Lấy tiếng chim)
d_hpf = designfilt('highpassfir', ...
    'FilterOrder',      N_order, ...
    'CutoffFrequency',  F_cutoff, ...
    'DesignMethod',     'window', ...
    'SampleRate',       Fs);

% Lọc tín hiệu
y_birds = filtfilt(d_hpf, x);

% %% 5. PHÁT NHẠC KIỂM TRA
% disp('-----------------------------------');
% disp('Dang phat: NHAC GOC');
% sound(x, Fs);
% pause(duration + 1);
% 
% disp('Dang phat: LOW PASS (Tieng dan)');
% sound(y_guitar, Fs);
% pause(duration + 1);
% 
% disp('Dang phat: HIGH PASS (Tieng chim)');
% sound(y_birds, Fs);
% 
% disp('-----------------------------------');

%% 6. XUẤT HỆ SỐ RA FILE VIVADO .COE
% Gọi hàm xuất file (Hàm được định nghĩa ở cuối script)
export_coeffs_to_coe(d_lpf, 'filter_lpf.coe'); 
export_coeffs_to_coe(d_hpf, 'filter_hpf.coe');

disp('HOAN TAT! Da xuat file .coe voi so luong tap nho (khoang 81 tap).');


% =========================================================
% HÀM HỖ TRỢ (PHẢI NẰM Ở CUỐI CÙNG CỦA FILE - SAU HẾT MỌI LỆNH)
% =========================================================
function export_coeffs_to_coe(filter_obj, filename)
    % 1. Lấy hệ số và chuyển sang Fixed-point 16-bit
    b = filter_obj.Coefficients;
    
    % Kiểm tra số lượng tap
    fprintf('Dang xuat file %s... So luong tap: %d\n', filename, length(b));
    
    % Nhân 2^15 (Q1.15)
    b_fixed = round(b * 32768); 
    
    % Xử lý tràn số (Saturation)
    b_fixed(b_fixed > 32767) = 32767;
    b_fixed(b_fixed < -32768) = -32768;
    
    % Chuyển sang Hex (Bù 2 cho số âm)
    b_hex = dec2hex(mod(b_fixed, 65536), 4);
    
    % 2. Ghi file đúng chuẩn .COE cho Vivado
    fid = fopen(filename, 'w');
    if fid == -1
        error('Khong the mo file: %s', filename);
    end
    
    % Ghi Header bắt buộc
    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');
    
    % Ghi dữ liệu
    num_coeffs = size(b_hex, 1);
    for i = 1:num_coeffs
        if i < num_coeffs
            % Các dòng giữa: Dấu phẩy (,) xuống dòng
            fprintf(fid, '%s,\n', b_hex(i, :));
        else
            % Dòng cuối cùng: Dấu chấm phẩy (;) kết thúc
            fprintf(fid, '%s;', b_hex(i, :));
        end
    end
    
    fclose(fid);
end