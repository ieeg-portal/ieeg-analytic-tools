function idx = clusterSpikesMulti(dataset,spikeSuffix)

timeBefore = 0.04;
timeAfter = 0.16;

%% get total spikes
%for each dataset
b = zeros(numel(dataset),1);
for i = 1:numel(dataset)
    %load spike times
    a = load([dataset(i).snapName spikeSuffix]);
    b(i) = size(a.spikeTimes,1);
end
fs = 400;
totalspikes =sum(b)
spikeWV = zeros(totalspikes,(timeBefore+timeAfter)*fs);
spikeInfo = zeros(totalspikes,3);
%% get spike data
iter = 1;
for i = 1:numel(dataset)
    fprintf('Getting spikes from %s\n',dataset(i).snapName);
    %load spike times
    a = load([dataset(i).snapName spikeSuffix]);
    fs = dataset(i).sampleRate;
    for j = 1:size(a.spikeTimes,1);
        if round(a.spikeTimes(j,1)/1e6-timeBefore)*fs > 0
            dat = dataset(i).getvalues(round(a.spikeTimes(j,1)/1e6-timeBefore)*fs :((round(a.spikeTimes(j,1)/1e6-timeBefore))*fs)+(0.2*fs)-1,a.spikeChannels(j));
            if fs ~=400
                dat = resample(dat,400,fs);
            end
            spikeWV(iter,:) = dat;
            spikeInfo(iter,:) = [i a.spikeTimes(j,1) a.spikeChannels(j)];
            iter = iter + 1;
        end
    end
end
% save('allSpikes.mat','spikeWV','spikeInfo');
load('allSpikes.mat')


%get all spikes data
% for i = 1:size(timesUSec,1)
%     startPt = round((timesUSec(i,1)/1e6 - timeBefore ) * fs);
%     endPt = round((timesUSec(i,1)/1e6 + timeAfter) * fs);
%     if startPt > 0
%         tmp = dataset.getvalues(startPt:endPt,eventChannels{i});
%         spikes(i,:) = tmp(:,1);
%         spikes2(i,:) = spikes(i,:)./max(abs(spikes(i,:)));
%     else
%         disp('check for zero rows')
%     end
% end
%cluster waveforms
%E = evalclusters(spikes,'kmeans','GAP','klist',[5:30]);
%[idx b] = kmeans(spikeWV,100);
%save('initialCluster.mat','idx');
load('initialCluster.mat');
%cluster PCS
% [a b c] = pca(spikes);
% E = evalclusters(b(:,1:2),'kmeans','GAP','klist',[1:30]);
% [idx b] = kmeans(b(:,1:2),E.OptimalK);

%% Plot and Remove first
t = 1/400:1/400:.2;
% for i = 1:max(idx)
%     tmp = spikeWV(idx==i,:);
%     subaxis(floor(sqrt(max(idx))),ceil(sqrt(max(idx))),i,'SpacingVert',0.04,'SpacingHoriz',0);
%     errorbar(t,mean(tmp),std(tmp),'Color',[.7 .7 .7])
%     hold on;
%     plot(t,mean(tmp),'r');
%     xlim([0 .2])
%     
% %     for j = 1:size(tmp,1)
% %         plot(tmp(j,:));
% %         hold on;
% %     end
%     title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
% end

%remove 
removeClusters = [15 30 41 50 52 56 64 68 82 84 90 99];
removeIdx = ismember(idx,removeClusters);
spikeWV(removeIdx,:) = [];
spikeInfo(removeIdx,:) = [];
idx(removeIdx,:) = [];

%% recluster
load('secondroundcluster.mat');
% [idx b] = kmeans(spikeWV,100);
% for i = 1:max(idx)
%     tmp = spikeWV(idx==i,:);
%     subaxis(floor(sqrt(max(idx))),ceil(sqrt(max(idx))),i,'SpacingVert',0.04,'SpacingHoriz',0);
%     errorbar(t,mean(tmp),std(tmp),'Color',[.7 .7 .7])
%     hold on;
%     plot(t,mean(tmp),'r');
%     xlim([0 .2])
%     
% %     for j = 1:size(tmp,1)
% %         plot(tmp(j,:));
% %         hold on;
% %     end
%     title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
% end
removeClusters = [3 39 83 94];
removeIdx = ismember(idx,removeClusters);
spikeWV(removeIdx,:) = [];
spikeInfo(removeIdx,:) = [];
idx(removeIdx,:) = [];

%% recheck
% [idx b] = kmeans(spikeWV,100);
% for i = 1:max(idx)
%     tmp = spikeWV(idx==i,:);
%     subaxis(floor(sqrt(max(idx))),ceil(sqrt(max(idx))),i,'SpacingVert',0.04,'SpacingHoriz',0);
%     errorbar(t,mean(tmp),std(tmp),'Color',[.7 .7 .7])
%     hold on;
%     plot(t,mean(tmp),'r');
%     xlim([0 .2])
%     
% %     for j = 1:size(tmp,1)
% %         plot(tmp(j,:));
% %         hold on;
% %     end
%     title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
% end

%%
%[idx1] = kmeans(spikeWV,36,'MaxIter',400);
%save('kmeans36maxiter400wv.mat','idx1','spikeWV','spikeInfo');
% [p1, pc, p2] = pca(spikeWV);
% [idxp] = kmeans(pc(:,1:20),49,'MaxIter',400);
% save('kmeans49maxiter400pca20.mat','idxp','spikeWV','spikeInfo');

%% choose clusters
load('kmeans36maxiter400wv.mat');
figure;
t = 1/400:1/400:.2;
for i = 1:max(idx1)
    tmp = spikeWV(idx1==i,:);
    subaxis(floor(sqrt(max(idx1))),ceil(sqrt(max(idx1))),i,'SpacingVert',0.04,'SpacingHoriz',0);
    errorbar(t,mean(tmp),std(tmp),'Color',[.7 .7 .7])
    hold on;
    plot(t,mean(tmp),'r');
    xlim([0 .2])
    
%     for j = 1:size(tmp,1)
%         plot(tmp(j,:));
%         hold on;
%     end
    title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
end
figure;
res= [];
for i = 1:max(idx1)
res = [res plotExFromCluster(dataset,spikeInfo,idx1,i)];
end

load('kmeans49maxiter400pca20.mat');
figure;
t = 1/400:1/400:.2;
for i = 1:max(idx1)
    tmp = spikeWV(idx1==i,:);
    subaxis(floor(sqrt(max(idx1))),ceil(sqrt(max(idx1))),i,'SpacingVert',0.04,'SpacingHoriz',0);
    errorbar(t,mean(tmp),std(tmp),'Color',[.7 .7 .7])
    hold on;
    plot(t,mean(tmp),'r');
    xlim([0 .2])
    
%     for j = 1:size(tmp,1)
%         plot(tmp(j,:));
%         hold on;
%     end
    title(['Cluster ' num2str(i) ': ' num2str(size(tmp,1))])
end
figure;
resp= [];
for i = 1:max(idxp)
resp = [resp plotExFromCluster(dataset,spikeInfo,idxp,i)];
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
options = statset('Display','final');
gm = gmdistribution.fit(spikes2,4,'Options',options);
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

