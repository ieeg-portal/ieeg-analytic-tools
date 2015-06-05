function idxByDataset = initialBurstClusterAsla(datasets,varargin)
%idxByDataset is cell array containing the indices of each cluster for
%bursts
%%
% Function will cluster annotated segments of EEG from datasets and times
% or layers in varargin.
%
%   Input:
%   datasets    :   IEEGDataset object(s)
%   varargin    :   [2x1 vector] [timesInMicroSecs eventChannels]
%               :   OR
%               :   ['string'] layername
%%

%anonymous functions
EnergyFn = @(x) mean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) mean(abs(diff(x)));
dataFeat = cell(numel(datasets),1);
numAnnots = zeros(numel(datasets),1);
for d = 1:numel(datasets)
    if numel(varargin)>1
        timesUSec = varargin{1};
        eventChannels = varargin{2};
    else
        [~, timesUSec, eventChannels] = getAllAnnots(datasets(d),varargin);
    end
    numAnnots(d) = size(timesUSec,1);
    fs = datasets(d).sampleRate;

    %% get each burst
    bursts = cell(size(timesUSec,1),1);
    feat = cell(size(timesUSec,1),1);
    for i = 1:size(timesUSec,1)
        startPt = round(timesUSec(i,1)/1e6*fs);
        endPt = round(timesUSec(i,2)/1e6*fs);
        tmpDat = datasets(d).getvalues(startPt:endPt,eventChannels{i});
        bursts{i} = tmpDat;
    end
    bursts = bursts(~cellfun('isempty',bursts));

    %feat = zeros(numel(bursts),1);
    feat = cell(numel(bursts),1);
    for i = 1:numel(bursts)
        y = bursts{i};
        avgbp = bandpower(y);
        aRatio = bandpower(y,fs,[8 13])/avgbp;
        focus = max(abs(y))./mean(abs(y));
        LL = LLFn(y);

        %  feat(i,4) = bandpower(y,fs,[13 30])/avgbp;

        %% AR
        coeff = arburg(y,8);
        A = roots(coeff);
        getFreq = @(x,y) atan( imag(x)./real(x))*y/(2*pi); 
        f = getFreq(A,fs);

        feat{i} = [aRatio focus LL f(2) f(3)];

        %% View FFT of burst
        %     L = length(y);                     % Length of signal
        %     t = (0:L-1)*(1/fs);                % Time vector
        %     subplot(2,1,1)
        %     plot(y)
        %     
        %     %set length so each burst has same spectrum length
        %     NFFT = 256;%2^nextpow2(L); % Next power of 2 from length of y
        %     Y = fft(y,NFFT)/L;
        %     f = fs/2*linspace(0,1,NFFT/2+1);
        %  %   Plot single-sided amplitude spectrum.
        %     subplot(2,1,2)
        %     plot(f,2*abs(Y(1:NFFT/2+1))) 
        %     a = bandpower(y,fs,[8 15])/bandpower(y);
        %     title(sprintf('%d',a));
        %     pause;

    end
    dataFeat{d} = cell2mat(feat);
end
dataFeat = cell2mat(dataFeat);

dataFeat = zscore(dataFeat); %z score normalization
 options = statset('Display','final');
%first split on aRatio (col 1)
gm = gmdistribution.fit(dataFeat(:,1),2,'Options',options);
idx = cluster(gm,dataFeat(:,1));

% %take upper group, split on all features
a = mean(dataFeat(idx==1,1));
b = mean(dataFeat(idx==2,1));

%split high alpha bursts into two more groups
if a > b
    feat = dataFeat(idx==1,2:end); %split group 1 into 2 groups on rest of data
    gm = gmdistribution.fit(feat,2,'Options',options);
    idx2 = cluster(gm,feat);
    idx(idx==2) = 3; %move original group 2 to group 3
    idx(idx==1) = idx2; %fill in new group 1 and 2, one should contain rhythmic bursts
else
    feat = dataFeat(idx==2,2:end);
    gm = gmdistribution.fit(feat,2,'Options',options);
    idx2 = cluster(gm,feat);
    idx(idx==1) = 3;
    idx(idx==2) = idx2;
end

idxByDataset = cell(numel(numAnnots),1); %each dataset will contain relevant start end times
startIdx = 1;
for i = 1:numel(numAnnots)
    endIdx = startIdx + numAnnots(i)-1;
    idxByDataset{i} = idx(startIdx:endIdx);
    startIdx = endIdx + 1;
end
