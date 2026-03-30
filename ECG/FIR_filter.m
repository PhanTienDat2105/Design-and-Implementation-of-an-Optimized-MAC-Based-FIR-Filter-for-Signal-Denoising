clc; clear; close all;
%% Setup
dbDir   = 'D:\Do_An_2\ecg-id-database-1.0.0';
person  = 'Person_05';
record  = 'rec_2';
secs    = 5;             

%% Read file 
oldDir = pwd;
% Kiểm tra xem thư mục có tồn tại không trước khi cd
if exist(fullfile(dbDir, person), 'dir')
    cd(fullfile(dbDir, person));
    [ecg, Fs, tm] = rdsamp(record, [], secs*500);
    cd(oldDir);
else
    error('Không tìm thấy thư mục dữ liệu!');
end

x = ecg(:,1);   % raw ECG (lead 1)

% DB Filtered (Lấy tín hiệu mẫu đã lọc của database để so sánh)
if size(ecg,2) >= 2
    x_filtered_db = ecg(:,2);
else
    x_filtered_db = [];
end

%% BƯỚC 1: FIR Equiripple LPF (Lọc nhiễu tần số cao > 30-50Hz)
% Giữ nguyên code của bạn đoạn này
Fp  = 30;    
Fst = 50;    
Rp  = 0.5;   
Ast = 50;    
d = designfilt('lowpassfir', ...
    'PassbandFrequency',   Fp, ...
    'StopbandFrequency',   Fst, ...
    'PassbandRipple',      Rp, ...
    'StopbandAttenuation', Ast, ...
    'DesignMethod',        'equiripple', ...
    'SampleRate',          Fs);
b = d.Coefficients;

fprintf('Số lượng taps FIR LPF: %d\n', length(b)); 

% Lọc lần 1: Loại bỏ nhiễu điện/nhiễu cao tần
y_lpf = filtfilt(b, 1, x); 

%% BƯỚC 2: Baseline Removal dùng Moving Average (Thay cho High-pass Filter)
% Mục tiêu: Loại bỏ trôi đường nền (< 0.5 Hz)
% Cửa sổ trượt (Window size) cần đủ lớn để bao phủ chu kỳ của tần số thấp nhất.
% Tần số cắt mong muốn Fc = 0.5Hz -> Chu kỳ T = 2s.
% Số mẫu tương ứng = 2 * Fs. Tuy nhiên với Moving Average, cửa sổ tầm 0.7s - 1s
% thường cho kết quả tốt để ước lượng baseline mà không làm méo sóng P, T.
window_width_sec = 1.0; % Độ rộng cửa sổ tính bằng giây (bạn có thể chỉnh cái này)
window_len = round(window_width_sec * Fs); 

% Tính đường nền (Baseline)
baseline = movmean(y_lpf, window_len);

% Trừ đường nền để ra tín hiệu sạch (tương đương High-pass)
y_final = y_lpf - baseline;

%% Plot kết quả
figure('Color','w');
subplot(3,1,1);
plot(tm, x, 'b'); grid on;
title('1. Raw ECG'); ylabel('mV');

subplot(3,1,2);
plot(tm, y_lpf, 'k'); hold on;
plot(tm, baseline, 'r', 'LineWidth', 1.5);
grid on; legend('LPF Signal', 'Estimated Baseline');
title('2. After LPF & Baseline Detection'); ylabel('mV');

subplot(3,1,3);
plot(tm, y_final, 'r'); grid on;
title('3. Final Result (LPF + Baseline Removed)'); 
xlabel('Time (s)'); ylabel('mV');

%% Compare with filtered DB 
if ~isempty(x_filtered_db)
    figure('Color','w');
    plot(tm, x_filtered_db,'g','LineWidth',1.5); hold on;
    plot(tm, y_final,'r','LineWidth',1);
    grid on;
    xlabel('Time (s)'); ylabel('ECG (mV)');
    legend('DB Filtered (Reference)','Our Processed');
    title([person '/' record ' — Comparison'],'Interpreter','none');
end

%% SNR & MSE Calculation
if ~isempty(x_filtered_db)
    L = min(length(x_filtered_db), length(y_final));
    d_ref = x_filtered_db(1:L);
    y_out = y_final(1:L);
    
    MSE = mean((d_ref - y_out).^2);
    SNR_ref = 10*log10(sum(d_ref.^2) / sum((d_ref - y_out).^2));
    
    fprintf('--------------------------------------\n');
    fprintf('SNR & MSE (So với tín hiệu chuẩn của DB)\n');
    fprintf('MSE = %.6f\n', MSE);
    fprintf('SNR = %.2f dB\n', SNR_ref);
    fprintf('--------------------------------------\n');
end

%% Frequency Spectrum Analysis 
N = length(x);
f = (0:N-1)*(Fs/N);
f_low = 0.1; % Chỉnh lại để xem rõ vùng tần số thấp
f_high = 1
idx = f >= f_low & f <= f_high;

X_raw  = abs(fft(x));
Y_final  = abs(fft(y_final));

figure('Color','w');
subplot(2,1,1);
plot(f(idx), 20*log10(X_raw(idx)/max(X_raw)), 'b');
grid on; title('Spectrum: Raw Signal'); ylabel('dB');

subplot(2,1,2);
plot(f(idx), 20*log10(Y_final(idx)/max(Y_final)), 'r');
grid on; title('Spectrum: Final Signal (LPF + Baseline Removed)'); 
xlabel('Frequency (Hz)'); ylabel('dB');