function [spikeTimesUSec, spikeChannels] = spike_LL(dataset,channels, winLen,mult,filtFlag,filtCheck)
% Usage: spike_LL(dataset,channels, winLen,mult,filtFlag,filtCheck)
% Input
%   dataset : IEEGDataset Object
%   channels : channels to detect spikes over
%   winLen : window length
%   mult : multiple of std to threshold
%   filtFlag : 1 to filter
%   filtCheck : 1 to enable manual checking of filtered signal (can be stopped mid run)

close all;
%common params
fs = dataset.channels(channels(1)).sampleRate;
duration = dataset.channels(channels(1)).get_tsdetails.getDuration/1e6;

%find nearest winLen that evaluates to full number of pts without rounding
%(else features will be shifted)
tmp = round(fs * winLen);
winLen = tmp/fs;

%calculate LL for all channels
try
    load(sprintf('%s_LL%d-%0.1d.mat',dataset.snapName,filtFlag,winLen));
catch
    fprintf('No saved mat detected, recalculating features...\n');
    feat = calcFeature_LL(dataset,1:numel(dataset.channels),'LL',winLen,sprintf('LL%d-%0.1d',filtFlag,winLen),filtFlag,filtCheck);
end
fprintf('Detecting spikes...\n');
eventIdxs = [];
eventChannels = [];
%for given channels, detect psikes
winPts = winLen*fs;
smIdxs = round(60/winLen); %smooth LL over 4 seconds
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
%     data = getAllData(dataset,c);
%     data = data(1:1001941);
%     plot(data(idx:idx+5*400));
%     title('raw');
%     subplot(5,1,2);
%     plot(feat(idx:idx+5*400,35));
%     title('feat');
%     subplot(5,1,3);
%     plot(smfeat(idx:idx+5*400));
%     title('smfeat');
%     subplot(5,1,4);
%     plot(divAvg);
%     title('feat./smfeat');
%     subplot(5,1,5)
%     tmp = divPrevWindow.*divAvg;
%     plot(tmp(idx:idx+5*400))
%     title('divPrevWindow*divAvg');
%     hline(std(tmp)*mult,'r')
%     linkaxes(get(gcf,'Children'),'x');
    divAvgFeat = divPrevWindow.*divAvg;
    thres = mult * std(divAvgFeat);
    [pks, eventIdx]=findpeaks(divAvgFeat,'minpeakheight',thres,'minpeakdistance',round(0.1*fs)); 
    
    eventIdxs = [eventIdxs; eventIdx];
    eventChannels = [eventChannels; ones(numel(unique(eventIdx)/fs*1e6),1)*c];
end

%remove early spikes within 3 seconds of recording
%eventChannels(eventIdxs<3*fs) = [];
%eventIdxs(eventIdxs<3*fs) = [];

% select spikes present on more than one channel
% [a b] = unique(eventIdxs);
% ev = eventIdxs;
% ev(b) = [];
% ev = unique(ev);
% newEventIdxs = [];
% newEventChannels = [];
% for i = 1:numel(ev)
%     newEventIdxs = [newEventIdxs; eventIdxs(eventIdxs==ev(i))];
%     newEventChannels = [newEventChannels; eventChannels(eventIdxs==ev(i))];
% end
% eventIdxs = newEventIdxs;
% eventChannels = newEventChannels;

% feat = zeros(numel(eventIdxs),6*fs);
% featIdx = 1;
% for c = channels
%     allData = getAllData(dataset,c);
%     allData(isnan(allData)) = 0;
%     allData = std_filter(allData,fs,4);
%     eventIdxsByChannel = eventIdxs(eventChannels==c);
%     for i = 1:numel(eventIdxsByChannel)
%         tmp = allData(eventIdxsByChannel(i):eventIdxsByChannel(i)+(0.1*fs));
%         %find first zero crossing
%         tdiff = diff(smooth(tmp,4));
%         tsign = sign(mean(tdiff(1:3)));
%         tIdx = sign(tdiff);
%         clf; plot(tmp); hold on;
%         idx = find(tIdx*tsign<0,1);
%         if isempty(idx)
%             eventIdx(i) = -1;
%         else
%             vline(idx,'r');
%             eventIdxsByChannel(i) = eventIdxsByChannel(i) + idx;
%             %get 6 seconds window, 3 seconds before, 3 seconds after
%             if (eventIdxsByChannel(i)+(3*fs))<size(allData,1);
%                 feat(featIdx,:) = allData(eventIdxsByChannel(i)-(3*fs)+1:eventIdxsByChannel(i)+(3*fs));
%             end
%         end
%         %feat(featIdx,:) = allData(eventIdxsByChannel(i)-(3*fs)+1:eventIdxsByChannel(i)+(3*fs));
%         featIdx = featIdx + 1;
%     end
% 
% end
    
       % eventIdx(eventIdx==-1) = [];
%     close all
%     
%     kidx = kmeans(feat(:,2.95*fs:3.15*fs),3);
%     for i = 1:max(kidx)
%         figure;
%         tmpdat = feat(kidx==i,2.95*fs:3.15*fs);
%         hold on;
%         for j = 1:size(tmpdat,1)
%             plot(tmpdat(j,:));
%         end
%         title(sprintf('Cluster %d',i));
%     end
%     
spikeTimesUSec = [eventIdxs/fs*1e6  eventIdxs/fs*1e6];

spikeChannels = eventChannels;
keepIdx = zeros(size(spikeTimesUSec,1),1);
for j = 1:size(spikeTimesUSec,1)
    dat = dataset.getvalues(spikeTimesUSec(j,1)/1e6*fs,spikeChannels(j));
    if abs(dat)>50
        keepIdx(j) = 1;
    end
end
keepIdx = logical(keepIdx);
spikeTimesUSec = spikeTimesUSec(keepIdx,:);
spikeChannels = spikeChannels(keepIdx);
        
        
    fprintf('%d spikes found\n',size(spikeTimesUSec,1));
  
end



