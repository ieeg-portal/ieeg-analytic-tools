function [feat, labels] = calcFeatureFromSignal(y,fs,params)
%feat = [DCNCalc(y) AreaFn(y) EnergyFn(y) ZCFn(y) LLFn(y) bp(x4)];

%% Anonymous functions
DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
AreaFn = @(x) mean(abs(x));
EnergyFn = @(x) mean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) mean(abs(diff(x)));
bp = [];
[PSD,F]  = pwelch(y,ones(length(y),1),0,length(y),fs,'psd');
avepow = bandpower(PSD,F,'psd');
bp = [bp bandpower(PSD,F,[.1 4],'psd')/avepow];
bp = [bp bandpower(PSD, F,[4 8],'psd')/avepow];
bp = [bp bandpower(PSD, F,[8 10],'psd')/avepow];
bp = [bp bandpower(PSD, F,[10 12],'psd')/avepow];
bp = [bp bandpower(PSD, F,[12 14],'psd')/avepow];
bp = [bp bandpower(PSD, F,[14 16],'psd')/avepow];
bp = [bp bandpower(PSD, F,[16 30],'psd')/avepow];
bp = [bp bandpower(PSD, F,[30 60],'psd')/avepow];
bp = [bp bandpower(PSD, F,[60 99],'psd')/avepow];
bp = [bp bandpower(PSD, F,[1 30],'psd')/bandpower(PSD, F,[30 99],'psd')];

ftLL = zeros(1,10);
L = numel(y);
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft(y,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
ft = 2*abs(Y(1:NFFT/2+1));
ftLL(1) = LLFn(ft(f>0&f<10));
ftLL(2) = LLFn(ft(f>10&f<20));
ftLL(3) = LLFn(ft(f>20&f<30));
ftLL(4) = LLFn(ft(f>30&f<40));
ftLL(5) = LLFn(ft(f>40&f<50));
ftLL(6) = LLFn(ft(f>50&f<60));
ftLL(7) = LLFn(ft(f>60&f<70));
ftLL(8) = LLFn(ft(f>70&f<80));
ftLL(9) = LLFn(ft(f>80&f<90));
ftLL(10) = LLFn(ft(f>90&f<99));
coeff = arburg(y,5);
A = roots(coeff);
getFreq = @(x,y) atan( imag(x)./real(x))*y/(2*pi); 
f = getFreq(A,fs);

feat = [AreaFn(y) EnergyFn(y) ZCFn(y) LLFn(y) max(abs(y))/mean(y) bp ftLL f(2) f(3)];
labels = {'Area','Energy', 'ZC','LL','Asymmetry', '.1-4','4-8','8-10','10-12','12-14','14-16','16-30','30-60','60-99','30/60 band', ...
    'fft1','fft2','fft3','fft4','fft5','fft6','fft7','fft8','fft9','fft10','AR2','AR3'};

