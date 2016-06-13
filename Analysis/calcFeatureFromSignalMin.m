function [feat, labels] = calcFeatureFromSignalMin(y,fs,params)
%feat = [DCNCalc(y) AreaFn(y) EnergyFn(y) ZCFn(y) LLFn(y) bp(x4)];

%% Anonymous functions
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) mean(abs(diff(y)));
[PSD,F]  = pwelch(y,ones(length(y),1),0,length(y),fs,'psd');
avepow = bandpower(PSD,F,'psd');
aRatio= bandpower(PSD, F,[8 10],'psd')/avepow;
aRatio2= bandpower(PSD, F,[10 12],'psd')/avepow;
aRatio3= aRatio/bandpower(PSD, F,[18 22],'psd')/avepow;
aRatio4= aRatio2/bandpower(PSD, F,[28 32],'psd')/avepow;

ZC = ZCFn(y);
coeff = arburg(y,5);
A = roots(coeff);
getFreq = @(x,y) atan( imag(x)./real(x))*y/(2*pi); 
f = getFreq(A,fs);
maxAmp = max(abs(y));
LLMax = max(abs(diff(y)));


ftLL = zeros(1,5);
L = numel(y);
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft(y,NFFT)/L;
f = fs/2*linspace(0,1,NFFT/2+1);
ft = 2*abs(Y(1:NFFT/2+1));
ftLL(1) = LLFn(ft(f>0&f<4));
ftLL(2) = LLFn(ft(f>4&f<8));
ftLL(3) = LLFn(ft(f>9&f<11));
ftLL(4) = LLFn(ft(f>18&f<22));
ftLL(5) = LLFn(ft(f>28&f<32));

%dominant freq
[maxVal, index] = max(ft);
maxFreq = f(index);

feat = [aRatio aRatio2 aRatio3 aRatio4 maxFreq maxAmp ZC LLMax f(2) f(3), ftLL];
labels = {'aRatio', 'aratio2', 'aratio3', 'aratio4','maxFreq','maxAmp','ZC', 'LLMax','f(2)', 'f(3)','ftLL1','ftLL2','ftLL3','ftLL4','ftLL5'};


