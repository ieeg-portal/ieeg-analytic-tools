function plot_fft(dataset,layerName);
% Function will plot the FFT for each annotation window



fs = dataset.sampleRate;
[~,timesUsec,channels ] = getAllAnnots(dataset,layerName);

for i = 1:size(timesUsec,1);
    data = dataset.getvalues((timesUsec(i,1)/1e6)*fs:(timesUsec(i,2)/1e6)*fs,channels{i});
    dataexp = dataset.getvalues((timesUsec(i,1)/1e6-2)*fs:(timesUsec(i,2)/1e6+2)*fs,channels{i});
    T = 1/fs;             % Sampling period
    L = length(data);
    t = (0:L-1)*T;  
    Y = fft(data);
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f = fs*(0:(L/2))/L;
    subplot(2,1,1);
    plot(dataexp);
    subplot(2,1,2);
    plot(f,P1)
    title('Single-Sided Amplitude Spectrum of X(t)')
    xlabel('f (Hz)')
    pause;
end