function [rec_winLen, rec_mult, allThreshold, allMax,allStd,durations,numMiss] =getHypersensitiveParams(dataset,train_layer,varargin)
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


fs = dataset.sampleRate;
nCh = numel(dataset.rawChannels);

LLFn = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');
ENFn = @(X, winLen) envelope_smooth(X,winLen);

featFn{1} = LLFn;
featFn{2} = ENFn;

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
        timesUSec = [timesUSec-0.05*1e6 timesUSec+0.05*1e6];
    end
end

patternFeatsAll = cell(numel(featFn),1);
backgroundFeatsAll = cell(numel(featFn),1);
for f = 1:numel(featFn)
    curFeatFn = featFn{f};

    tstat = NaN(size(timesUSec,1),nCh);
    rec_mult = NaN(size(timesUSec,1),nCh,2);
    numMiss = 0;
    for j = 1:size(timesUSec,1);
       win(j) = (timesUSec(j,2)-timesUSec(j,1))/1e6;
       tmp = dataset.getvalues((timesUSec(j,1)/1e6-win(j)*pad_mult)*fs:(timesUSec(j,2)/1e6+win(j)*pad_mult)*fs,eventChannels{j});
       tmp2 = NaN(size(tmp,1),nCh);
       tmp2(:,eventChannels{j}) = tmp;
       tmp = tmp2;
       winLen = round(win(j)*fs);
       feat1 = curFeatFn(tmp,round(winLen/2));
       numPt = size(feat1,1);

       %parse background and pattern
       bckfeat1 = feat1(winLen:winLen*pad_mult,:);
       bckfeat2 = feat1(numPt-winLen*pad_mult:numPt-winLen,:);
       patfeat = feat1(winLen*pad_mult:end-winLen*pad_mult,:);
       patternfeat{j} = patfeat;

       %find min patternFeat that is greater than 2x sd of mean background
       bckfeat{j} = [bckfeat1;bckfeat2];
       maxbck = mean(bckfeat{j}) + bckthresmult*std(bckfeat{j});
       tmpAdd = NaN(1,nCh);
       for k = eventChannels{j}
           [h, p, CI, stats] = ttest2(bckfeat{j}(:,k),patfeat(:,k));
           tstat(j,k) = stats.tstat;

           %find min feature that is greater than max of background
           try % if fails, feature was not greater than background
               minFeat = min(patfeat(patfeat(:,k)>max(bckfeat{j}(:,k)),k));
               maxFeat = max(patfeat(patfeat(:,k)>max(bckfeat{j}(:,k)),k));
               rec_mult(j,k,1) = (minFeat - mean(bckfeat{j}(:,k)))/std(bckfeat{j}(:,k));
               rec_mult(j,k,2) = (maxFeat - mean(bckfeat{j}(:,k)))/std(bckfeat{j}(:,k));
           catch
           end
           tmpMin = max(patfeat(patfeat(:,k)>maxbck(k),k));
           if ~isempty(tmpMin)
                tmpAdd(k) = tmpMin;
           else
               numMiss = numMiss + 1;
           end
           tmpDur(k) = sum(patfeat(:,k)>maxbck(k))/fs;

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
               xlim([0 numel(tmp(:,k))]);
               subplot(2,1,2)
               plot(1:numel(feat1(:,k)),feat1(:,k),'LineWidth',2);
               hold on;
               plot(winLen*pad_mult:numPt-winLen*pad_mult,patfeat(:,k),'r','LineWidth',2);
               plot(winLen:winLen*pad_mult,bckfeat1(:,k),'k','LineWidth',2);
               plot(numPt-winLen*pad_mult:numPt-winLen,bckfeat2(:,k),'k','LineWidth',2);
               if ~isempty(tmpMin)
                    hline(tmpMin,'r');
               end
               xtick = get(gca,'XtickLabels');
               xtick = round(cellfun(@str2num,xtick)/fs,2);
               set(gca,'XtickLabels',num2cell(xtick))
               set(gca,'XGrid','On','FontSize',14)
               xlabel('Time (s)');
               ylabel('Feature Value');
               xlim([0 numel(tmp(:,k))]);
               hold off;
               waitforbuttonpress;
           end
       end
       threshold{j} = tmpAdd;
       durations{j} = tmpDur;
    end
    %patternfeat = cellfun(@(x)nanmax(x),patternfeat,'UniformOutput',0);
    %bckfeat = cellfun(@(x)nanmax(x),bckfeat,'UniformOutput',0);
    patternFeatsAll{f} = cell2mat(patternfeat');
    backgroundFeatsAll{f} = cell2mat(bckfeat');
end
featTitles = {'Line Length','Signal Envelope'};
stat = zeros(numel(featFn),1);
for i = 1:numel(featFn)
    subplot(2,1,i)
    tmppat = patternFeatsAll{i};
    tmpbck = backgroundFeatsAll{i};
    tmppat = tmppat(~isnan(tmppat));
    tmpbck = tmpbck(~isnan(tmpbck));
    histogram(tmppat,'Normalization','probability');
    hold on;
    histogram(tmpbck,'Normalization','probability');
    [h,p,stats] = ranksum(tmppat,tmpbck);
    stat(i) = stats.zval;
    legend('SOI','BCK');
    title(sprintf('%s, z= %0.2f ',featTitles{i}, stat(i)));
    xlabel('Feature Value');
    ylabel('P(x)');
    set(gca,'FontSize',14)
end

rec_winLen = win/2;
rec_mult_min = rec_mult(:,:,1);
rec_mult_max = rec_mult(:,:,2);
recMultMiss = sum(isnan(rec_mult_max));
rec_mult = nanmean(rec_mult_max)-1*nanstd(rec_mult_max);
% find best feature and threshold to detect patterns
threshold = cell2mat(threshold');
%allThreshold = nanmin(threshold,[],1);
allThreshold = nanmean(threshold);
allMax = nanmax(threshold);
allStd = nanstd(threshold);
durations = cell2mat(durations');
fprintf('With these parameters, you miss %d of %d markings, or %0.2f\n',numMiss,size(timesUSec,1),numMiss/size(timesUSec,1));
fprintf('Current threshold multiplier: %0.3d\n',bckthresmult);
    g = sprintf('%d, ',rec_mult);
fprintf('Recommended threshold multiplier: %s, missing %d of %d markings\n',g,recMultMiss,size(timesUSec,1));