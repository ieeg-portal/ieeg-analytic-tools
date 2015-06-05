function parfeats = calcFeature_v5_par(dataset,params)
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
filtFlag = params.filtFlag;

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
duration = dataset.channels(1).get_tsdetails.getDuration;
fs = dataset.channels(1).sampleRate;
numPoints = duration/1e6*fs;
numParBlocks = 5;
numPointsPerParBlock = numPoints / numParBlocks;
%calculate number of blocks
numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);

parFeats = cell(numParBlocks,1);
try
    delete(gcp)
catch
end
parpool(numParBlocks);
parfor i = 1:numParBlocks
    session = IEEGSession(datasetFN,IEEGid,IEEGpwd);
    %% Feature extraction loop
    feat = cell(numBlocks,1);
    reverseStr = '';
    for j = 1:numBlocks
        %Get data
        startBlockPt = 1+(blockLenSecs*(j-1)*fs)
        endBlockPt = min(blockLenSecs*j*fs,numPointsPerParBlock)
        try
        blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        catch
            pause(1);
            blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        end
        blockData(isnan(blockData)) = 0; %NaN's turned to zero
        nChan = numel(channels);
        %calculate feature every winLen secs
        numWins = ceil(size(blockData,1)/(winLen*fs));
        tmpFeat = zeros(numWins,nChan);
        for n = 1:numWins
            startWinPt = round(1+(winLen*(n-1)*fs));
            endWinPt = round(min(winLen*n*fs,size(blockData,1)));
                switch feature
                    case 'power'
                        for c = 1:nChan
                            y = blockData(startWinPt:endWinPt,c);
                            [PSD,F]  = pwelch(y,ones(length(y),1),0,length(y),fs,'psd');
                            tmpFeat(n,c) = bandpower(PSD,F,[8 12],'psd');
                        end
                    case 'dcn'
                        y = blockData(startWinPt:endWinPt,1:nChan);
                        tmpFeat(n,1) = DCNCalc(y);
                    case 'll'
                        y = blockData(startWinPt:endWinPt,1:nChan);
                        tmpFeat(n,:) = LLFn(y);
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

