%Use this program to plot EEG data
<<<<<<< HEAD
function hu_DispEEGMat(data,rate,scale)
=======
function p_PlotEEGMat(data,rate,scale)
>>>>>>> 45667d6cb1273defd11272f8308fddcc159728fe
%define the parameters

    x = 1:size(data, 1);
    x = x/rate;

    plot(x, data + repmat(1:size(data,2),size(data,1),1)*scale)
    xlabel('Seconds');

