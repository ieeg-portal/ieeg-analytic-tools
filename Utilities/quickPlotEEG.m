function quickPlotEEG(data,fs,varargin)
% Usage: quickPlotEEG(data,fs)
% This function will plot EEG
% Input:
%   Data = N x Ch matrix
%   fs = sampling rate (hz)
%
%   OPTIONAL
%   'Highlight Channels'    :   array of channel indices to highlight with
%   a different color
%   'Pad'                   :   Creates another figure showing padding in
%                               data. Data input is assumed to already be
%                               padded
% 
% Updated Hoameng Ung, 10/11/2016
highlightch = [];
padsec = [];
for i = 1:2:nargin-2
    switch varargin{i}
        case 'Highlight Channels'
            highlightch = varargin{i+1};
        case 'Pad'
            padsec = varargin{i+1};
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end

%define the parameters

%PLOT PATTERN ONLY IF NO PADSEC
if isempty(padsec)
    tmpdata = data;
    scale = max(max(tmpdata));
    x = 1:size(tmpdata, 1);
    duration = round(size(tmpdata,1)/fs);
    tmpdata = tmpdata - repmat(1:size(tmpdata,2),size(tmpdata,1),1)*scale;
    plot(x, tmpdata,'k'); title(sprintf('Duration: %d seconds',duration));
    lim = xlim;
    vline(1:fs:lim(2));
    ax1 = gca;
    ax1.YTick = scale*(-size(data,1):-1);
    ax1.YTickLabel = size(data,1):-1:1;
    
    if ~isempty(highlightch)
        hold on;
        plot(x, tmpdata(:,highlightch),'r')
        hold off;
    end
else
    %PLOT PATTERN
    figure(1);
    clf;
    tmpdata = data(padsec*fs:end-padsec*fs,:);
    scale = max(max(tmpdata));
    x = 1:size(tmpdata, 1);
    duration = round(size(tmpdata,1)/fs);
    tmpdata = tmpdata - repmat(1:size(tmpdata,2),size(tmpdata,1),1)*scale;
    plot(x, tmpdata,'k'); title(sprintf('Duration: %d seconds',duration));
    set(gcf, 'Position', [1146 600 907 507]);
    lim = xlim;
    vline(1:fs:lim(2));
    ax1 = gca;
    ax1.YTick = scale*(-size(data,1):-1);
    ax1.YTickLabel = size(data,1):-1:1;

    
    set(ax1,'XTick',1:fs:lim(2))
    a = ax1.XTickLabels;
    a = cellfun(@(x)str2num(x),a);
    a = round(a / fs,2);
    set(ax1,'XTickLabels',a)
    
    if ~isempty(highlightch)
        hold on;
        plot(x, tmpdata(:,highlightch),'r')
        hold off;
    end

    %PLOT FULL
    figure(2)
    clf;
    tmpdata = data;
    scale = max(max(tmpdata));
    x = 1:size(tmpdata, 1);
    duration = round(size(tmpdata,1)/fs);
    tmpdata = tmpdata - repmat(1:size(tmpdata,2),size(tmpdata,1),1)*scale;
    plot(x, tmpdata,'k'); title(sprintf('Duration: %d seconds',duration));
    set(gcf, 'Position', [1146 26 907 507]);
    lim = xlim;
    vline(1:fs:lim(2));
    hold on;
    vline(padsec*fs,'b');
    vline(size(data,1)-padsec*fs,'b');
    ax1 = gca;
    ax1.YTick = scale*(-size(data,1):-1);
    ax1.YTickLabel = size(data,1):-1:1;
    
    set(ax1,'XTick',1:fs:lim(2))
    a = ax1.XTickLabels;
    a = cellfun(@(x)str2num(x),a);
    a = round(a / fs,2);
    set(ax1,'XTickLabels',a)
    if ~isempty(highlightch)
        hold on;
        plot(x, tmpdata(:,highlightch),'r')
        hold off;
    end

end



