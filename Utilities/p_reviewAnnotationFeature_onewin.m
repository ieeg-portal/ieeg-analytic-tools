function [opt stats]= p_reviewAnnotationFeature_onewin(IEEGDataset,layerNames,params)
close all;
winLenMarkers = {'rx','k+','co','m.'};
testWinLens = params.LL.testWinLens;
upperThreshold = params.LL.upperThreshold;
lowerThreshold = params.LL.lowerThreshold;
backLen = params.LL.backLen;
patternMinDuration = params.LL.minDuration;
patternMaxDuration = params.LL.maxDuration;

nrow = 2;
ncol = 1;
pad = 3;
stats.passL = zeros(numel(testWinLens),numel(lowerThreshold));
stats.backLRatio = zeros(numel(testWinLens),numel(lowerThreshold));
stats.passU = zeros(numel(testWinLens),numel(upperThreshold));
stats.backURatio = zeros(numel(testWinLens),numel(upperThreshold));

for w = 1:numel(testWinLens)
    winLen = testWinLens(w);
    passL = zeros(1,numel(lowerThreshold));
    passU = zeros(1,numel(upperThreshold));
    totalAnnot = 0;
    backLRatio = cell(numel(IEEGDataset),1);
    backURatio = cell(numel(IEEGDataset),1);
    for d = 1:numel(IEEGDataset)
        dataset = IEEGDataset(d);
        %Function will plot annotation EEG and overlay with feature
        fs = dataset.sampleRate;
        backLRatio{d} = cell(numel(layerNames,1));
        backURatio{d} = cell(numel(layerNames,1));

        for l = 1:numel(layerNames)
            %loop over layernames
            layerName = layerNames{l};
            try
                %get all annotations
                [~,times,ch] = getAllAnnots(dataset,layerName);
                %pad = 2*max(winLen);%(s);
                LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');
                totalAnnot = totalAnnot + size(times,1);
                backLRatio{d}{l} = zeros(numel(size(times,1)),numel(lowerThreshold));
                backURatio{d}{l} = zeros(numel(size(times,1)),numel(upperThreshold));
                
                for i = 1:size(times,1)
                    %pull data
                    data = dataset.getvalues(times(i,1)/1e6*fs-pad*fs:times(i,2)/1e6*fs+pad*fs,ch{i});
                    backdata = dataset.getvalues(times(i,1)/1e6*fs-2*backLen*fs:times(i,1)/1e6*fs+2*backLen*fs,ch{i});
                    annotLength = round((times(i,2)-times(i,1))/1e6*fs);

                    backFeat = LLFn2(backdata,winLen*fs); %feature values for background
                    feat = bsxfun(@rdivide, LLFn2(data,winLen*fs),nanmedian(backFeat)); %annotation feature value with padding normalized by background
                    annotFeat = feat(pad*fs+1:pad*fs+annotLength); %feature values for annotation only
                    
                    for t = 1:numel(upperThreshold)
                        upperRatio = sum(annotFeat<upperThreshold(t))/size(annotFeat,1); % percent of annotation with feat below upper threshold
                        backURatio{d}{l}(i,t) = sum(backFeat/(mean(backFeat))>upperThreshold(t))/numel(backFeat);
                        if upperRatio > .95;
                            passU(t) = passU(t) + 1;
                        end
                    end
                    
                    for t = 1:numel(lowerThreshold)
                        lowerRatio = sum(annotFeat>lowerThreshold(t))/size(annotFeat,1); % percent of annotation with feat above lower threshold
                        aboveThresh = backFeat/(mean(backFeat))>lowerThreshold(t); %points where background is greater than lower threshold
                        secsAboveThresh = diff(find(diff(aboveThresh)~=0))/fs; %find total seconds where background is greater than lower threshold
                        tmp= sum(secsAboveThresh(secsAboveThresh>patternMinDuration & secsAboveThresh<patternMaxDuration)); %take only those times greater than min duration since those are the false detections

                        if isnan(tmp)
                            tmp = 0;
                        end
                        backLRatio{d}{l}(i,t) = tmp;
                        if lowerRatio > .95 %inc pass is greater than 95% of annotation is above lower limit
                            passL(t) = passL(t) + 1;
                        end
                    end

                        
                    
                    subplot(nrow,ncol,1)
                    [ax, h1, h2] = plotyy(1:size(data,1),data,1:size(feat,1),feat);
                    maxval = cellfun(@(x) max(abs(x)), get([h1 h2], 'YData'));
                    ylim = [-maxval, maxval] * 1.1;  % Mult by 1.1 to pad out a bit
                    set(ax(1), 'YLim', ylim(1,:) );
                    set(ax(2), 'YLim', ylim(2,:) );
                    vline(pad*fs)
                    vline(pad*fs+(times(i,2)-times(i,1))/1e6*fs)
                    axes(ax(2))
                    hline(lowerThreshold);
                    hline(upperThreshold,'k');
                    title(sprintf('winLen: %0.2f (s)',winLen));

                    subplot(nrow,ncol,2)

                    hold on;
                    scatter(upperRatio,lowerRatio,winLenMarkers{w},'SizeData',78);
                    xlabel('Upper Ratio');
                    ylabel('Lower Ratio');
                    hold off;
                    waitforbuttonpress;

                end
            catch ME
                fprintf('Error in %s in %s: \n',layerName,dataset.snapName');
                rethrow(ME)
            end
        end
    end
    tmp = cellfun(@(x)cell2mat(x'),backLRatio,'UniformOutput',0);
    stats.backLRatio(w,:) = mean(cell2mat(tmp));
    tmp = cellfun(@(x)cell2mat(x'),backURatio,'UniformOutput',0);
    stats.backURatio(w,:) = mean(cell2mat(tmp));
    stats.passL(w,:) = passL/totalAnnot; %percent of annotations with 95% of feat value > lower threshold
    stats.passU(w,:) = passU/totalAnnot; %percent of annotations with 95% of feat value < upper threshold
end
opt = 1;