function [rec_winLen, allThreshold, durations] =getHypersensitiveParams2(dataset,train_layer,varargin)
%Function will return recommended winLen and threshold to use with LL

pad_mult = 2;
bckthresmult = 4;
showPlots = 0;
find_nearest_peak = 0;
for i = 1:2:nargin-2
    switch varargin{i}
        case 'pad_mult'
            pad_mult = varargin{i+1};
        case 'background_thres_mult'
            bckthresmult = varargin{i+1};
        case 'show_plots'
            showPlots = varargin{i+1};
        case 'find_nearest_peak'
            find_nearest_peak = varargin{i+1};
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end

LLFn = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');

fs = dataset.sampleRate;
nCh = numel(dataset.rawChannels);

[~, timesUSec, eventChannels] = getAnnotations(dataset,train_layer);
win = zeros(size(timesUSec,1),1);
patternFeat = {};
bckfeat = {};
threshold = {};
durations = {};

%if spike, adjust times to nearest peak
if find_nearest_peak
    tmpdur = sum(timesUSec(:,2)-timesUSec(:,1))/1e6;
    if tmpdur == 0 %if duration is 0, assume spike
        searchWin = [0.2 0.2]; %s before and after to search
        timesUSec = findNearestPeak(dataset,timesUSec,eventChannels,searchWin);
        timesUSec = [timesUSec-0.05*1e6 timesUSec+0.15*1e6];
    end
end

for j = 1:size(timesUSec,1);
   win(j) = round((timesUSec(j,2)-timesUSec(j,1))/1e6);
   tmp = dataset.getvalues((timesUSec(j,1)/1e6-win(j)*pad_mult)*fs:(timesUSec(j,2)/1e6+win(j)*pad_mult)*fs,eventChannels{j});
   tmp2 = NaN(size(tmp,1),nCh);
   tmp2(:,eventChannels{j}) = tmp;
   tmp = tmp2;
   winLen = round(win(j)*fs);
   feat1 = LLFn(tmp,round(winLen/2));
   numPt = size(feat1,1);

   %parse background and pattern
   bckfeat1 = feat1(winLen:winLen*pad_mult,:);
   bckfeat2 = feat1(numPt-winLen*pad_mult:numPt-winLen,:);
   patfeat = feat1(winLen*pad_mult:end-winLen*pad_mult,:);
   patternFeat{j} = patfeat;

   %find min patternFeat that is greater than 2x sd of mean background
   bckfeat{j} = [bckfeat1;bckfeat2];
   maxbck = mean(bckfeat{j}) + bckthresmult*std(bckfeat{j});
   tmpAdd = NaN(1,nCh);
   for k = eventChannels{j}
       tmpMin = min(patfeat(patfeat(:,k)>maxbck(k),k));
       tmpDur(k) = sum(patfeat(:,k)>maxbck(k))/fs;
       if ~isempty(tmpMin)
           tmpAdd(k) = tmpMin;
       end
       if showPlots
           figure(1)
           clf;
           subplot(2,1,1);
           plot(tmp(:,k),'k');
           xtick = get(gca,'XtickLabels');
           xtick = round(cellfun(@str2num,xtick)/fs,2);
           title('Initial segmentation');
           set(gca,'XtickLabels',num2cell(xtick),'XGrid','On','FontSize',14)
           xlabel('Time (s)');
           ylabel('Voltage (uV)');
           subplot(2,1,2)
           plot(1:numel(feat1(:,k)),feat1(:,k),'LineWidth',2);
           hold on;
           plot(winLen*pad_mult:numPt-winLen*pad_mult,patfeat(:,k),'r','LineWidth',2);
           plot(winLen:winLen*pad_mult,bckfeat1(:,k),'k','LineWidth',2);
           plot(numPt-winLen*pad_mult:numPt-winLen,bckfeat2(:,k),'k','LineWidth',2);
           hline(tmpMin,'r');
           xtick = get(gca,'XtickLabels');
           xtick = round(cellfun(@str2num,xtick)/fs,2);
           set(gca,'XtickLabels',num2cell(xtick))
           set(gca,'XGrid','On','FontSize',14)
           xlabel('Time (s)');
           ylabel('Feature Value');
           hold off;
           waitforbuttonpress;
       end
   end
   threshold{j} = tmpAdd;
   durations{j} = tmpDur;
end
rec_winLen = win/2;
% find best feature and threshold to detect patterns
threshold = cell2mat(threshold');
allThreshold = nanmin(threshold,[],1);
durations = cell2mat(durations');