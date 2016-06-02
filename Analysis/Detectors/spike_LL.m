function [spikeTimesUSec, spikeChannels] = spike_LL(dataset,channels, params)
% Usage: standalone_spike_LL(dataset,channels,params)
% Input:
%       dataset     : IEEGDataset object
%       channels    : Cell array, each element contacts vector of channels
%       to calculate spikes over
%       params      : parameter structs

rawThreshold = params.spikeLL.rawThreshold;
winLen = params.spikeLL.winLen;
mult = params.spikeLL.mult;
FILTFLAG = params.spikeLL.FILTFLAG;
FILTCHECK = params.spikeLL.FILTCHECK;

%common params
fs = dataset.channels(channels(1)).sampleRate;
duration = dataset.channels(channels(1)).get_tsdetails.getDuration/1e6;

%find nearest winLen that evaluates to full number of pts without rounding
%(else features will be shifted)
tmp = round(fs * winLen);
winLen = tmp/fs;

%calculate LL for all channels
try
    load(sprintf('%s_LL%d-%0.1d.mat',dataset.snapName,FILTFLAG,winLen));
catch
    fprintf('No saved mat detected, recalculating features...\n');
    feat = calcFeature_LL(dataset,1:numel(dataset.channels),'LL',winLen,sprintf('LL%d-%0.1d',FILTFLAG,winLen),FILTFLAG,FILTCHECK);
end
fprintf('Detecting spikes...\n');
eventIdxs = [];
eventChannels = [];
%for given channels, detect psikes
winPts = winLen*fs;
smIdxs = round(60/winLen); %smooth LL 
for c = channels
    smfeat = conv(feat(:,c),repmat(1/smIdxs,1,smIdxs),'same');
    divPrevWindow = feat(2:end,c)./feat(1:end-1,c);
    divAvg = feat(2:end,c)./smfeat(1:end-1);
%     smfeat = repmat(smfeat(:,1),1,winPts );
%     smfeat = reshape(smfeat',numel(smfeat),1);
%     divPrevWindow = repmat(divPrevWindow(:,1),1,winPts );
%     divPrevWindow = reshape(divPrevWindow',numel(divPrevWindow),1);
%     divAvg = repmat(divAvg(:,1),1,winPts );
%     divAvg = reshape(divAvg',numel(divAvg),1);
    %   feat2 = repmat(feat(:,c),1,winLen*fs);
    %   feat2 = reshape(feat2',numel(feat2),1);
    
%     %idx = (5*60+47)*fs
%     %idx = (7*60+45)*fs
%     idx = (10*60 +54)*fs
%     figure
%     subplot(5,1,1)
%     pad = 2; %(seconds to pad idx)
%     idx = round(228674545/1e6*fs)
%     idxWindow = idx-pad*fs:idx+pad*fs
%     data = dataset.getvalues(idxWindow,c);
%     plot(data);
%     title('raw');
%     subplot(5,1,2);
%     plot(feat(idxWindow,c));
%     title('feat');
%     subplot(5,1,3);
%     plot(smfeat(idxWindow));
%     title('smfeat');
%     subplot(5,1,4);
%     plot(divAvg(idxWindow));
%     title('feat./smfeat');
%     subplot(5,1,5)
%     tmp = divPrevWindow.*divAvg;
%     plot(tmp(idxWindow))
%     title('divPrevWindow*divAvg');
%     hline(std(tmp)*mult,'r')
%     linkaxes(get(gcf,'Children'),'x');
    divAvgFeat = divPrevWindow.*divAvg;
    thres = mult * std(divAvgFeat);
    [pks, eventIdx]=findpeaks(divAvgFeat,'minpeakheight',thres,'minpeakdistance',round(0.1*fs)); 
    
    %AMPLITUDE FILTER 
    % Remove all spikes with a raw uV voltage in 100 ms window greater than threshold 
    toRemove = zeros(numel(pks),1);
    for i = 1:numel(pks);
       %pull each spike window
       tmp = dataset.getvalues(max(eventIdx(i)-.05*fs,1):min(eventIdx(i)+.05*fs,size(feat,1)),c);
       if max(abs(tmp)) > rawThreshold
           toRemove(i) = 1;
       end
    end
    fprintf('False spikes removed: %d \n', sum(toRemove));
    toRemove = logical(toRemove);
    if sum(toRemove) > 0
        pks(toRemove) = [];
        eventIdx(toRemove) = [];
    end
    eventIdxs = [eventIdxs; eventIdx];
    eventChannels = [eventChannels; ones(numel(unique(eventIdx)/fs*1e6),1)*c];
end

spikeTimesUSec = [eventIdxs/fs*1e6  eventIdxs/fs*1e6];
spikeChannels = eventChannels;
       
fprintf('%d spikes found\n',size(spikeTimesUSec,1));
  
end



