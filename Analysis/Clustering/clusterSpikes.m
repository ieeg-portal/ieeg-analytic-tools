function idx = clusterSpikes(datasets,varargin)
% Function will cluster annotated segments of EEG from datasets and times
% or layers in varargin.
%
%   Input:
%   datasets    :   IEEGDataset object(s)
%   varargin    :   [2x1 vector] [timesInMicroSecs eventChannels]
%               :   OR
%               :   ['string'] layername
%%
allSpikes = cell(numel(datasets),1);
allSpikes2 = cell(numel(datasets),1);
numAnnots = zeros(numel(datasets),1);
timeBefore = 0.04;
timeAfter = 0.16;
for d = 1:numel(datasets)
    if numel(varargin)>1
        timesUSec = varargin{1};
        eventChannels = varargin{2};
    else
        [~, timesUSec, eventChannels] = getAllAnnots(datasets(d),varargin);
    end
    numAnnots(d) = size(timesUSec,1);
    fs = datasets(d).sampleRate;
    window = (timeBefore+timeAfter)*fs;
    spikes = zeros(size(timesUSec,1),round(window)+1);
    spikes2 = zeros(size(timesUSec,1),round(window)+1);
    %get all spikes data
    for i = 1:size(timesUSec,1)
        startPt = round((timesUSec(i,1)/1e6 - timeBefore ) * fs);
        endPt = round((timesUSec(i,1)/1e6 + timeAfter) * fs);
        if startPt > 0
            tmp = datasets(d).getvalues(startPt:endPt,eventChannels{i});
            spikes(i,:) = tmp(:,1);
            spikes2(i,:) = spikes(i,:)./max(abs(spikes(i,:)));
        else
            disp('check for zero rows')
        end
    end
    allSpikes{d} = spikes;
    allSpikes2{d} = spikes2;
end

spikes = cell2mat(allSpikes);
spikes2 = cell2mat(allSpikes2);
%cluster waveforms
%E = evalclusters(spikes,'kmeans','GAP','klist',[5:30]);
[idx b] = kmeans(spikes,k);

%cluster PCS
% [a b c] = pca(spikes);
% E = evalclusters(b(:,1:2),'kmeans','GAP','klist',[1:30]);
% [idx b] = kmeans(b(:,1:2),E.OptimalK);

for i = 1:max(idx)
    tmp = spikes(idx==i,:);
    subaxis(floor(sqrt(max(idx))),ceil(sqrt(max(idx))),i,'SpacingVert',0.04,'SpacingHoriz',0);
    for j = 1:size(tmp,1)
        plot(tmp(j,:));
        hold on;
    end
    title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
end

keep = str2num(input('Input clusters to keep: ','s'));
idx = ismember(idx,keep);

%plot all spikes
% for i = 1:size(spikes2,1)
%     subplot(2,1,1);
%     plot(spikes(i,:));
%     hold on;
%     subplot(2,1,2);
%     plot(spikes2(i,:));
%     hold all;
% end


% %plot all spikes
% 
% %gaussian mixture model
% 
% %find optimum number of clusters
% % eva = evalclusters(spikes,'gmdistribution','gap','Klist',[3 4 5 6]);
% % plot(eva)
% options = statset('Display','final');
% gm = gmdistribution.fit(spikes2,4,'Options',options);
% 
% idx = cluster(gm,spikes2);
% for i = 1:max(idx)
%     figure(i);
%     clf;
%     tmp = spikes2(idx==i,:);
%     for j = 1:size(tmp,1)
%         plot(tmp(j,:));
%         hold on
%     end
%     plot(mean(tmp),'r','LineWidth',2)
% end

