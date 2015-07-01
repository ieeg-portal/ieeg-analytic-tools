function parFeats = calcFeature_v5_par(dataset,params)
%Usage: calcFeature_v4(datasets,channels,feature,winLen,outLabel,filtFlag,varargin)
%This function will divide IEEGDataset channels into blocks of
%and within these blocks further divide into winLen. Features
%will be calculated for each winLen and saved in a .mat matrix.
%Features calculated: power, LL, DCN
%
% Hoameng Ung - University of Pennsylvania
% 6/15/2014 - v2 - added filter options
% 8/28/2014 - v3 - edited comments, filter options, blockLenSecsaz
% 9/18/2014 - v4 - changed winLen to winPts for generality across sampling
% rates
blockLenSecs = params.blockLen; %get data in blocks
feature = lower(params.feature);
channels = params.channels;
winLen = params.winLen;
winDisp = params.winDisp;
filtFlag = params.filtFlag;
timeOfInterest= params.timeOfInterest; %times of interest, if empty, use entire dataset
%% Anonymous functions
CalcNumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));
DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
AreaFn = @(x) mean(abs(x));
EnergyFn = @(x) mean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) mean(abs(diff(x)));
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');


%% Initialization
IEEGid = params.IEEGid;
IEEGpwd = params.IEEGpwd;
datasetFN = dataset.snapName;
fs = dataset.channels(1).sampleRate;
if isempty(timeOfInterest)
    duration = dataset.channels(1).get_tsdetails.getDuration/1e6;
else
    duration =(timeOfInterest(2) - timeOfInterest(1));
end
startPt = 1+(timeOfInterest(1)*fs);
numPoints = duration*fs;
numParBlocks = 5;
numPointsPerParBlock = numPoints / numParBlocks;
%calculate number of blocks
numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);

parFeats = cell(numParBlocks,1);
%pool(numParBlocks);
parfor i = 1:numParBlocks
    session = IEEGSession(datasetFN,IEEGid,IEEGpwd);
    %% Feature extraction loop
    feat = cell(numBlocks,1);
    reverseStr = '';
    startParPt = startPt + (i-1)*numPointsPerParBlock;
    for j = 1:numBlocks
        %Get data
        startBlockPt = startParPt+(blockLenSecs*(j-1)*fs);
        endBlockPt = startParPt+min(blockLenSecs*j*fs,numPointsPerParBlock);
        
        %get data
        try
            blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        catch
            pause(1);
            blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        end
        percentValid = 1-sum(isnan(blockData),1)/size(blockData,1);
        blockData(isnan(blockData)) = 0; %NaN's turned to zero
        nChan = numel(channels);
        
        numWins = CalcNumWins(size(blockData,1),fs,winLen,winDisp);
        tmpFeat = zeros(numWins,nChan);
        for n = 1:numWins
            tmpData = blockData(1+(n-1)*(winDisp*fs):((n-1)*(winDisp)+winLen)*fs,:);
            startWinPt = round(1+(winLen*(n-1)*fs));
            endWinPt = round(min(winLen*n*fs,size(blockData,1)));
            switch feature
                case 'power'
                    for c = 1:nChan
                        y = tmpData(:,c);
                        [PSD,F]  = pwelch(y,ones(length(y),1),0,length(y),fs,'psd');
                        tmpFeat(n,c) = bandpower(PSD,F,[8 12],'psd');
                    end
                case 'dcn'
                    tmpFeat(n,1) = DCNCalc(tmpData);
                case 'll'
                    tmpFeat(n,:) = LLFn(tmpData)./percentValid;
            end
        end
        feat{j} = tmpFeat;
        percentDone = 100 * j / numBlocks;
        msg = sprintf('Percent done worker %d: %3.1f',i,percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    feat = cell2mat(feat);
    if strcmp(feature,'dcn')
        feat = feat(:,1);
    end
    parFeats{i} = feat;
end
    save([datasetFN '_' params.saveLabel '.mat'],'parFeats','-v7.3');
end

