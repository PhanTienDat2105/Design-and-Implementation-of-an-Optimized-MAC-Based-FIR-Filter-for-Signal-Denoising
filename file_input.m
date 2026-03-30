clc; clear; close all;

%% Setup
dbDir   = 'C:\Users\84788\Downloads\databaseECG\ecg-id-database-1.0.0';
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

%% FIR Equiripple LPF 
Fp  = 40;    % Hz
Fst = 50;    % Hz
Rp  = 0.5;   % dB passband ripple
Ast = 60;    % dB stopband attenuation

d = designfilt('lowpassfir', ...
    'PassbandFrequency',   Fp, ...
    'StopbandFrequency',   Fst, ...
    'PassbandRipple',      Rp, ...
    'StopbandAttenuation', Ast, ...
    'DesignMethod',        'equiripple', ...
    'SampleRate',          Fs);

b = d.Coefficients;

% Lọc zero-phase
y_hp = filtfilt(b, 1, x);

%% Plot raw vs our filter 
figure('Color','w');
subplot(2,1,1);
plot(tm, x,'b'); grid on;
title('ECG gốc (Raw)'); xlabel('Time (s)'); ylabel('Amplitude (mV)');

subplot(2,1,2);
plot(tm, y_hp,'r'); grid on;
title(sprintf('ECG sau lọc Equiripple FIR (Fp=%.0f Hz, Fst=%.0f Hz, Rp=%.1f dB, Ast=%.0f dB)', Fp, Fst, Rp, Ast));
xlabel('Time (s)'); ylabel('Amplitude (mV)');

%% Compare with filtered DB 
if ~isempty(x_filtered_db)
    figure('Color','w');
    plot(tm, x_filtered_db,'g','LineWidth',1.2); hold on;
    plot(tm, y_hp,'r','LineWidth',1.2);
    grid on;
    xlabel('Time (s)'); ylabel('ECG (mV)');
    legend('Filter DB','Our Filter');
    title([person '/' record ' — Filter DB vs Our Filter'],'Interpreter','none');

    figure('Color','w');
    subplot(2,1,1);
    plot(tm, x_filtered_db,'g','LineWidth',1.2); grid on;
    xlabel('Time (s)'); ylabel('ECG (mV)');
    title([person '/' record ' — Filter DB'],'Interpreter','none');

    subplot(2,1,2);
    plot(tm, y_hp,'r','LineWidth',1.2); grid on;
    xlabel('Time (s)'); ylabel('ECG (mV)');
    title([person '/' record ' — Our Filter'],'Interpreter','none');
end

%% Đáp ứng tần số 
figure('Color','w');
freqz(b,1,2048,Fs);
title('Đáp ứng tần số FIR Equiripple');

%% SNR & MSE vs DB
if ~isempty(x_filtered_db)
    L = min(length(x_filtered_db), length(y_hp));
    d_ref = x_filtered_db(1:L);
    y_out = y_hp(1:L);

    MSE = mean((d_ref - y_out).^2);
    SNR_ref = 10*log10(sum(d_ref.^2) / sum((d_ref - y_out).^2));

    fprintf('SNR, MSE of Our filter vs Filter DB \n');
    fprintf('MSE = %.6f\n', MSE);
    fprintf('SNR = %.2f dB\n', SNR_ref);
end
%% ===== EXPORT ECG INPUT FOR VIVADO (Q1.15) =====
saveDir = 'C:\Users\84788\Downloads\DA2\ECG_input';   % nơi lưu 2 file 
FR = 15;                                    % Q1.15
FSnorm = true;                              % true: normalise full-scale để tránh bão hoà

x_ecg = x;                                  % dùng kênh raw đã đọc ở trên

% (tuỳ chọn) scale full-scale để tận dụng hết Q1.15
if FSnorm
    s = max(abs(x_ecg));
    if s < 1e-12, s = 1; end
    x_ecg = x_ecg / s;                      % đưa về khoảng ~[-1,1]
end

% Clip an toàn rồi lượng tử sang Q1.15
x_ecg = max(min(x_ecg, 0.9999695), -1.0);   % tránh +1.0 gây tràn
x_q15  = round(x_ecg * 2^FR);
x_q15  = min(max(x_q15, -32768), 32767);    % giới hạn 16-bit signed

% === Ghi file ===
f_dec = fullfile(saveDir, 'input_dec.txt');
f_hex = fullfile(saveDir, 'input_hex.txt');

% 1) decimal (mỗi dòng 1 số nguyên Q1.15)
writematrix(x_q15, f_dec, 'FileType','text');
% 2) hex (mỗi dòng 1 word 16-bit, 4 ký tự HEX, two’s complement)
fid = fopen(f_hex,'w');
for i = 1:numel(x_q15)
    ui16 = typecast(int16(x_q15(i)), 'uint16');
    fprintf(fid, '%04X\n', ui16);
end
fclose(fid);

fprintf('✅ Saved:\n  %s  (%d samples, decimal Q1.15)\n  %s  (HEX Q1.15)\n', ...
        f_dec, numel(x_q15), f_hex);

%% ===== EXPORT FIR COEFFS FOR VIVADO (Q1.15) =====
saveDir = 'D:\Do_An_2\DA2\ECG_input';   % thư mục lưu file
FR = 15;                              % Q1.15
scale = 2^FR;

% Nếu chưa có b (hoặc designfilt không khả dụng) thì tự thiết kế equiripple
if ~exist('b','var') || isempty(b)
    try
        % Thử thiết kế lại bằng designfilt (nếu có DSP System Toolbox)
        Fp=40; Fst=50; Rp=0.5; Ast=60; Fs = 500;  % đổi Fs nếu khác
        d = designfilt('lowpassfir', ...
            'PassbandFrequency',   Fp, ...
            'StopbandFrequency',   Fst, ...
            'PassbandRipple',      Rp, ...
            'StopbandAttenuation', Ast, ...
            'DesignMethod',        'equiripple', ...
            'SampleRate',          Fs);
        b = d.Coefficients(:).';
    catch
        % Fallback dùng firpm (Parks–McClellan)
        Fs = 500; Fp=40; Fst=50; Rp=0.5; Ast=60;
        dev = [ (10^(Rp/20)-1)/(10^(Rp/20)+1), 10^(-Ast/20) ];
        [n,fo,ao,w] = firpmord([Fp Fst],[1 0], dev, Fs);
        n = max(n, 32);                         % đảm bảo tối thiểu 33 tap
        b = firpm(n, fo, ao, w);
    end
end

% Đưa về hàng ngang
b = b(:).';
N = numel(b);

% (Khuyến nghị) Chuẩn hoá gain DC = 1 cho lowpass
s = sum(b);
if abs(s) > 1e-12
    b = b / s;
end

% Lượng tử sang Q1.15 (round-to-nearest + saturate)
b_q = round(b * scale);
b_q = min(max(b_q, -32768), 32767);
b_q = int16(b_q);

% Ghi file DEC
f_dec = fullfile(saveDir, 'coeffs_dec.txt');
writematrix(b_q, f_dec, 'FileType','text');

% Ghi file HEX (2’s complement, 4 ký tự/ dòng)
f_hex = fullfile(saveDir, 'coeffs_hex.txt');
fid = fopen(f_hex,'w');
for i = 1:N
    ui16 = typecast(b_q(i), 'uint16');
    fprintf(fid, '%04X\n', ui16);
end
fclose(fid);

% (tuỳ chọn) ghi thêm info
f_info = fullfile(saveDir,'coeffs_info.txt');
fid = fopen(f_info,'w');
fprintf(fid, 'Taps (N) = %d\nScale Q1.%d\nDC gain normalized: %g\n', N, FR, sum(double(b)));
fclose(fid);

fprintf('✅ Saved coeffs: N=%d\n  %s (dec)\n  %s (hex)\n', N, f_dec, f_hex);
