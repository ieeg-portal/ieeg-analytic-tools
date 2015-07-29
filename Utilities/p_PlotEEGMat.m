%Use this program to plot EEG data
function p_PlotEEGMat(data,rate,scale)
%define the parameters

    x = 1:size(data, 1);
    x = x/rate;

    plot(x, data + repmat(1:size(data,2),size(data,1),1)*scale)
    xlabel('Seconds');

