function quickPlotEEG(data,fs)
%Usage: quickPlotEEG(data,fs)

% Data = N x Ch matrix
% fs = sampling rate (hz)

%define the parameterss
scale = max(max(data));
    x = 1:size(data, 1);
    %x = x/fs;

    plot(x, data + repmat(1:size(data,2),size(data,1),1)*scale)
    %xlabel('Seconds');

