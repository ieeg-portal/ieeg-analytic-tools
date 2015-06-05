function feat = calcFeature_v4(datasets,channels,feature,winLen,outLabel,filtFlag,filtCheck,varargin)
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

%Input:
%   'dataset'       :   IEEG dataset
%   'channels'      :   vector of channels
%   'winLen'        :   winLen = vector of windowlengths (s) to calculate
%                       features over
%   'outlabel'      :   Suffix to save features to
%   (datasetname_outlabel.mat)
%   'filtFlag'      :   [0/1] 1: filter data [1 70] bandpass, [58 62]
%   bandstop
%   'filtCheck'     :   [0/1] 1: Plot data before and after filtering for
%   one block for manual checking
%Output:
%   'feat'          :   Calculated feature for each window

%% Anonymous functions
CalcNumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));
DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
AreaFn = @(x) mean(abs(x));
EnergyFn = @(x) mean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) mean(abs(diff(x)));
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');

%% Initialization
feature = lower(feature);
blockLenSecs = 4*60*60; %get data in blocks
for i = 1:numel(datasets)
    datasetFN = datasets(i).snapName;
    duration = datasets(i).channels(1).get_tsdetails.getDuration;
    fs = datasets(i).channels(1).sampleRate;
    numPoints = duration/1e6*fs;
    %calculate number of blocks
    %numBlocks = CalcNumWins(numPoints,fs,blockLenSecs,blockLenSecs);
    numBlocks = ceil(numPoints/fs/blockLenSecs);
    
    %% Feature extraction loop
    feat = cell(numBlocks,1);
    reverseStr = '';
    for j = 1:numBlocks
        %Get data
        startBlockPt = 1+(blockLenSecs*(j-1)*fs);
        endBlockPt = min(blockLenSecs*j*fs,numPoints);
        blockData = datasets(i).getvalues(startBlockPt:endBlockPt,channels);
        blockData(isnan(blockData)) = 0; %NaN's turned to zero
        if filtFlag
            for c = 1:numel(channels)
                [b a] = butter(3,[1/(fs/2)],'high');
                d1 = filtfilt(b,a,blockData(:,c));
                try
                [b a] = butter(3,[70/(fs/2)],'low');
                d1 = filtfilt(b,a,d1);
                catch 
                end
                [b a] = butter(3,[58/(fs/2) 62/(fs/2)],'stop');
                d1 = filtfilt(b,a,d1);

                if filtCheck 
                    figure;
                    subplot(2,1,1); plot(blockData(:,c)); title('original');
                    subplot(2,1,2); plot(d1); title('d1');
                    linkaxes;
                    chk = input('Check plot for correct filter results, enter y for yes to stop check: ','s');
                    if strcmp(chk,'y'); filtCheck = 0; end
                end
                blockData(:,c) = d1;
            end
        end
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
                            tmpFeat(n,c) = bandpower(PSD,F,varargin{1},'psd');
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
        msg = sprintf('Percent done: %3.1f',percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    feat = cell2mat(feat);
    if strcmp(feature,'dcn')
        feat = feat(:,1);
    end
    save([datasetFN '_' outLabel '.mat'],'feat','-v7.3');
end

