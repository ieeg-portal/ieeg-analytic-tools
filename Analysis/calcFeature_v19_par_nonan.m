function calcFeature_v19_par_nonan(dataset,channels,params,allFeatures,varargin)
%Usage: calcFeature_v19_par(dataset,params,allFeatures)
%This function will divide IEEGDataset channels into blocks of
%and within these blocks further divide into winLen. Features
%will be calculated for each winLen and saved in a .mat matrix, minimizing
%number of calls to ieeg.
%If it finds precalculated features in .mat with same naming scheme, it
%will skip the dataset
%
%Features calculated: power, LL, DCN

% Input:
%   dataset:    IEEGDataset object
%   channels:   Vector of channel indices to calculate over
%   params:     Struct of parameters
%   allFeatures:    Cell array of strings containing features to calculate

%Ex.
% session = IEEGSession('dataset','username','username_login.bin')
% channels = [1 2 3]
% params.timeOfInterest=[0 60*60*24]; %get feature for 24*60*60 seconds
% params.filtflag = 1; %1 to filter, 0 to ignore
% params.filt.order = 3;
% params.filt.wn = 190;
% params.filt.type ='low';
% params.winLen = 60*5; (s)
% params.winDisp = 60*5; (s)
% params.blockLen = 60*60*1; Length of data to get from cloud at one time.
% calcFeature_v14_par(session.data,channels,params,{'amp','power','dcn'});
% %calculate amp, power, and dcn features and save to file.
%
% Hoameng Ung - University of Pennsylvania
% hoameng@upenn.edu
% 6/15/2014 - v2 - added filter options
% 8/28/2014 - v3 - edited comments, filter options, blockLenSecsaz
% 9/18/2014 - v4 - changed winLen to winPts for generality across sampling
% rates
% 8/27/2015 - v7 - support for ieeg-matlab-1.13 (rawChannels)
% 9/15/2015 - v8 - will not overwrite existing save files
% 11/18/2015 - v10 - optimization (removed inner cell layer), for half
% wave, others need to be fixed
% 11/19/2015 - v12 - compute multiple features at a time since downloading
% and filtering takes the longest
% 12/10/2015 - v13 - DCN compatability added
% 12/18/2015 - v14 - Fixed variable channel support
% 3/24/2015    v15 - added hwamp
% 6/13/2016 -  v16 - added RMS
% 7/28/2016 -   v17 -   added save for each block
numParBlocks = 200; %% NUMBER OF PARALLEL BLOCKS
numParProcs = 16; % NUMBER OF WORKERS
blockLenSecs = params.blockLen; %get data in blocks
for i = 1:numel(allFeatures)
    allFeatures{i} = lower(allFeatures{i});
end
winLen = params.winLen;
winDisp = params.winDisp;
filtFlag = params.filtFlag;
timeOfInterest= params.timeOfInterest; %times of interest, if empty, use entire dataset
%% Anonymous functions
CalcNumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));
DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
AreaFn = @(x) nanmean(abs(x));
EnergyFn = @(x) nanmean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) nanmean(abs(diff(x)));
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');


%% Initialization
IEEGid = params.IEEGid;
IEEGpwd = params.IEEGpwd;
datasetFN = dataset.snapName;
fs = dataset.rawChannels(1).sampleRate;

%check if feature mat already exists by naming scheme. Skip if does
exists = false(numel(allFeatures),1);
for f = 1:numel(allFeatures)
    if ~isempty(dir(sprintf('%s_wL%d_feat-%s*.mat',datasetFN,params.winLen,allFeatures{f})))
        fprintf('%s - %s mat found, skipping\n',datasetFN,allFeatures{f});
        exists(f) = 1;
    end
end
features = allFeatures(~exists);

if (~isempty(features))

    if isempty(timeOfInterest)
        duration = dataset.rawChannels(1).get_tsdetails.getDuration/1e6;
        startPt = 1;
    else
        duration =(timeOfInterest(2) - timeOfInterest(1));
        startPt = 1+(timeOfInterest(1)*fs);
    end
    numPoints = duration*fs;

    numPointsPerParBlock = numPoints / numParBlocks;
    %calculate number of blocks
    numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);
    
    %try to open parpools
    try
        parpool(numParProcs)
    catch
    end
    
    %% Read NaNIDXS to avoid
    try
        AllNaNIdx = csvread(sprintf('%s-NaN-final2.csv',datasetFN));
    catch
        AllNaNIdx = [];
    end

    numWins = CalcNumWins(blockLenSecs*fs,fs,winLen,winDisp);
    nChan = numel(channels);
    % 
    % disp('Adding java library to each worker')
    % spmd
    %     javaaddpath('../../Libraries/ieeg-matlab-1.13.2/IEEGToolbox/lib/ieeg-matlab.jar');
    % end

    %% RUNNN
    parfor i = 1:numParBlocks
        parsavename = sprintf('%s_wL%d_parblock2-%0.2d.mat',datasetFN,params.winLen,i);
        if exist(parsavename,'file') ~= 2
            %javaaddpath('../../Libraries/ieeg-matlab-1.13.2/IEEGToolbox/lib/ieeg-matlab.jar');
            parFeats = cell(numel(features),1);
            session = IEEGSession(datasetFN,IEEGid,IEEGpwd);
            if filtFlag
               session.data.setFilter(params.filt.order,params.filt.wn,params.filt.type);
            end
            %% Feature extraction loop
            startParPt = startPt + (i-1)*numPointsPerParBlock;
            tmpFeat = cell(numel(features),1);
            for f = 1:numel(features)
                if strcmp(features{f},'power')
                    tmpFeat{f} = nan(numWins,numBlocks,nChan,6);
                elseif strcmp(features{f},'dcn')
                    tmpFeat{f} = nan(numWins,numBlocks,1); %DCN is global      
                elseif strcmp(features{f},'hw')
                    tmpFeat{f} = nan(numWins,numBlocks,nChan,2);    %hw amp and dur       
                elseif strcmp(features{f},'custom')
                    tmpFeat{f} = nan(numWins,numBlocks,896);
                else
                    tmpFeat{f} = nan(numWins,numBlocks,nChan);
                end
            end

            for j = 1:numBlocks
                %Get data
                startBlockPt = round(startParPt+(blockLenSecs*(j-1)*fs));
                endBlockPt = round(startParPt+min(blockLenSecs*j*fs,numPointsPerParBlock)-1);
                if endBlockPt>startBlockPt && (isempty(AllNaNIdx) || (~sum(AllNaNIdx(:,1)<startBlockPt & AllNaNIdx(:,2)>endBlockPt))) %if not encapsulated in nan block
                    percNaN = 0;
    %                 if ~isempty(NaNFN)
    %                    percNaN = sum(diff(NaNIdx(NaNIdx(:,1)<endBlockPt & NaNIdx(:,2)>startBlockPt,:),1,2))/(endBlockPt-startBlockPt);
    %                 end
                    if percNaN>0.5
                        fprintf('Block more than half NaN: %s, pb %d, b %d, skipping...\n',datasetFN,i,j,numBlocks)
                    else
                        fprintf('Getting data values for %s, pb %d, b %d/%d...\n',datasetFN,i,j,numBlocks)
                        count = 0; err_count = 0;
                        skipBlock = 0;
                        while count == err_count
                            %get data
                            try
                                blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
                                if isempty(AllNaNIdx) %if no NaNIdx files loaded, create files
                                    if sum(sum(~isnan(blockData)))== 0 %if all NaN, record start end
                                        NaNIdx = [startBlockPt endBlockPt]; 
                                        skipBlock = 1;
                                    else
                                        tmp = diff(isnan(blockData));
                                        [startNaNRow, ~] = find(tmp==1);
                                        [endNaNRow, ~] = find(tmp==-1);
                                        startNaNRow = unique(startNaNRow);
                                        endNaNRow = unique(endNaNRow);
                                        if numel(startNaNRow) > numel(endNaNRow)
                                            endNaNRow = [endNaNRow; size(blockData,1)];
                                        elseif numel(startNaNRow) < numel(endNaNRow)
                                            startNaNRow = [1;startNaNRow];
                                        elseif tmp(1) == -1
                                            startNaNRow = [1,startNaNRow];
                                            endNaNRow = [endNaNRow; size(blockData,1)];
                                        end
                                        NaNIdx = [startNaNRow+startBlockPt endNaNRow+startBlockPt];
                                    end
                                    dlmwrite(sprintf('%s-NaNIdx-%d.csv',session.data.snapName,i),NaNIdx,'precision',10,'-append');
                                end
                                %end
                                %manual filter
                                %[z,p,k]=butter(params.filt.order,params.filt.wn/200,params.filt.type);
                                %[sos,g] = zp2sos(z,p,k);
                            catch ME
                                pause(2);
                                err_count = err_count + 1;
                            end
                            count = count + 1;
                            if count > 10
                                fprintf('Failed to get data parblock %d block %d/%d...skipping: time: %s, %s \n',i,j,numBlocks,datestr(datetime('now')), ME.identifier);
                                fprintf('Error getting %s_%f:%f\n',datasetFN,startBlockPt,endBlockPt);
                                break;
                            end
                        end

                        if count > 10
                            break;
                        end
                            %percentValid = 1-sum(isnan(blockData),1)/size(blockData,1);
                        if ~skipBlock
                        %    fprintf('[%s] Calculating features for %s, pb %d, b %d,...\n',datestr(clock),datasetFN,i,j)
                            for n = 1:numWins
                               % fprintf('[%s] Calculating feature for %s, pb %d, b %d, win %d...\n',datestr(clock),datasetFN,i,j,n)
                                startWinPt = round(1+(winLen*(n-1)*fs));
                                endWinPt = round(min(winLen*n*fs,size(blockData,1)));
                                if startWinPt<endWinPt
                                    tmpData = blockData(startWinPt:endWinPt,:);
                                    numNaN = sum(sum(isnan(tmpData))); % find total NaN;
                                    if numNaN/numel(tmpData)<=.10 % if less than 10 percent NaN
                                        for f = 1:numel(features)
                                            switch features{f}
                                                case 'power'
                                                    y = tmpData;
                                                    nanmat = repmat(nanmean(y),size(y,1),1);
                                                    if sum(sum(isnan(nanmat)))==0
                                                        y(isnan(y)) = nanmat(isnan(y));
                                                        [PSD,F]  = pwelch(y,[],[],[],fs,'psd');
                                                        tmpFeat{f}(n,j,:,1) = bandpower(PSD,F,[1 4],'psd');
                                                        tmpFeat{f}(n,j,:,2) = bandpower(PSD,F,[4 8],'psd');
                                                        tmpFeat{f}(n,j,:,3) = bandpower(PSD,F,[8 12],'psd');
                                                        tmpFeat{f}(n,j,:,4) = bandpower(PSD,F,[12 30],'psd');
                                                        tmpFeat{f}(n,j,:,5) = bandpower(PSD,F,[30 100],'psd');
                                                        tmpFeat{f}(n,j,:,6) = bandpower(PSD,F,[100 180],'psd');
                                                    end
                                                case 'dcn'
                                                    tmpFeat{f}(n,j,1) = DCNCalc(tmpData);
                                                case 'energy'
                                                    tmpFeat{f}(n,j,:) = nanmean(tmpData.^2);
                                                case 'area'
                                                    tmpFeat{f}(n,j,:) = nansum(abs(tmpData));
                                                case 'amp'
                                                    tmpFeat{f}(n,j,:) = nanmean(abs(tmpData));
                                                case 'rms' 
                                                    tmpFeat{f}(n,j,:) = sqrt(nanmean(tmpData.^2));
                                                case 'll'
                                                    tmpFeat{f}(n,j,:) = LLFn(tmpData);
                                                case 'hw'
                                                    out =  halfwave(tmpData,fs,1);
                                                    for c = 1:size(tmpdata,2)
                                                        %store median abs value of hw amplitude for
                                                        %each channel
                                                        tmpFeat{f}(n,j,c,1) = median(abs(out(out(:,4)==c,2)));
                                                        tmpFeat{f}(n,j,c,2) = median(abs(out(out(:,4)==c,3)));
                                                    end
                                                case 'custom'
                                                    featFn = varargin{1};
                                                    tmpFeat{f}(n,j,:) = featFn(tmpData,fs);
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                percentDone = 100 * j / numBlocks;
                msg = sprintf('Percent done worker %d: %3.1f\n',i,percentDone); %Don't forget this semicolon
               % fprintf([reverseStr msg]);
               fprintf(msg);
                %reverseStr = repmat(sprintf('\b'), 1, length(msg));
            end
            fprintf('\n');
            z = 1;
            for f = 1:numel(features)
                if strcmp(features{f},'power')
                    for band = 1:6
                        tmp = squeeze(tmpFeat{f}(:,:,:,band));
                        parFeats{z} = squeeze(reshape(tmp,size(tmp,1)*size(tmp,2),size(tmp,3)));
                        z = z + 1;
                    end
                elseif strcmp(features{f},'hw')
                    for ft = 1:2
                        tmp = squeeze(tmpFeat{f}(:,:,:,ft));
                        parFeats{z} = squeeze(reshape(tmp,size(tmp,1)*size(tmp,2),size(tmp,3)));
                        z = z + 1;
                    end
                else
                    parFeats{z} = squeeze(reshape(tmpFeat{f},size(tmpFeat{f},1)*size(tmpFeat{f},2),size(tmpFeat{f},3)));
                    z = z + 1;
                end
            end
            parsave2(parsavename,parFeats);
        else
            fprintf('%s exists, skipping\n',parsavename);
        end
    end
    fns = dir(sprintf('%s_wL%d_parblock*.mat',datasetFN,params.winLen));
    fns = {fns.name};
    allParFeats = cell(numel(fns),1);
    for i = 1:numel(fns)
        tmp = load(fns{i});
        allParFeats{i} = tmp.parFeats;
    end
    z = 1;
    powerfeats = {'delta','theta','alpha','beta','gamma','higamma'};
    hwfeats={'hwamp','hwdur'};
    for f = 1:numel(features)  
        if strcmp(features{f},'power')
            for band = 1:6
                parFeats = [];
                for i = 1:numel(allParFeats)
                    parFeats = [parFeats; allParFeats{i}{z}];
                end
                save(sprintf('%s_wL%d_feat-%s-%s.mat',datasetFN,params.winLen,features{f},powerfeats{band}),'parFeats','-v7.3');
                z = z + 1;
            end
        elseif strcmp(features{f},'hw')
            for fidx = 1:2
                parFeats = [];
                for i = 1:numel(allParFeats)
                    parFeats = [parFeats; allParFeats{i}{z}];
                end
                save(sprintf('%s_wL%d_feat-%s-%s.mat',datasetFN,params.winLen,features{f},hwfeats{fidx}),'parFeats','-v7.3');
                z = z + 1;
            end
        else
            parFeats = [];
            for i = 1:numel(allParFeats)
                parFeats = [parFeats; allParFeats{i}{z}];
            end
            save(sprintf('%s_wL%d_feat-%s.mat',datasetFN,params.winLen,features{f}),'parFeats','-v7.3');
            z = z +1;
        end
    end
else
        fprintf('No new features found, skipping ... %s \n',datasetFN);
end
end




function [timesUSec, chan] = burstDetector(data, fs, channels, params)

orig = data;
%filter data
if params.burst.FILTFLAG == 1
    for i = 1:size(data,2);
        [b, a] = butter(4,[1/(fs/2)],'high');
        d1 = filtfilt(b,a,data(:,i));
        try
        [b, a] = butter(4,[70/(fs/2)],'low');
        d1 = filtfilt(b,a,d1);
        catch
        end
        [b, a] = butter(4,[58/(fs/2) 62/(fs/2)],'stop');
         d1 = filtfilt(b,a,d1);
        data(:,i) = d1;
    end
end                 

if params.burst.DIAGFLAG
    T = 1/fs;                     % Sample time
    L = length(orig(:,1));                     % Length of signal
    subplot(2,2,1)
    plot(orig(:,1));
    subplot(2,2,3)
    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft(d1,NFFT)/L;
    f = fs/2*linspace(0,1,NFFT/2+1);

    % Plot single-sided amplitude spectrum.
    plot(f,2*abs(Y(1:NFFT/2+1))) 
    title('Single-Sided Amplitude Spectrum of y(t)')
    xlabel('Frequency (Hz)')
    ylabel('|Y(f)|')

    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft(d1,NFFT)/L;
    f = fs/2*linspace(0,1,NFFT/2+1);
    subplot(2,2,3)
    plot(d1);
    subplot(2,2,4)
    % Plot single-sided amplitude spectrum.
    plot(f,2*abs(Y(1:NFFT/2+1))) 
    title('Single-Sided Amplitude Spectrum of y(t)')
    xlabel('Frequency (Hz)')
    ylabel('|Y(f)|')  
end


featWinLen = round(params.burst.winLen * fs);

featVals = params.burst.featFN(data, featWinLen);

medFeatVal = nanmedian(featVals);
nfeatVals = bsxfun(@rdivide, featVals,medFeatVal);

  % get the time points where the feature is above the threshold (and it's not
  % NaN)
  aboveThresh = ~isnan(nfeatVals) & nfeatVals > params.burst.thres & nfeatVals<params.burst.maxThres;
  
aboveThreshPad = aboveThresh;
  %get event start and end window indices - modified for per channel
  %processing
   [evStartIdxs, chan] = find(diff([zeros(1,size(aboveThreshPad,2)); aboveThreshPad]) == 1);
   [evEndIdxs, ~] = find(diff([aboveThreshPad; zeros(1,size(aboveThreshPad,2))]) == -1);
   evEndIdxs = evEndIdxs + 1;

  startTimesSec = evStartIdxs/fs;
  endTimesSec = evEndIdxs/fs;
  
  if numel(channels) == 1
      channels = [channels channels];
  end
  %map chan idx back to channels
  chan = channels(chan);
  
  duration = endTimesSec - startTimesSec;
  idx = (duration<(params.burst.minDur) | (duration>params.burst.maxDur));
  startTimesSec(idx) = [];
  endTimesSec(idx) = [];
  chan(idx) = [];
  timesUSec = [startTimesSec*1e6 endTimesSec*1e6];
  chan = chan';
end

