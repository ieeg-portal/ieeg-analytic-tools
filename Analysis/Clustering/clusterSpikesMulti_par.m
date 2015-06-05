function idx = clusterSpikesMulti_par(datasetNames,spikeSuffix,userID,pwdFile)
%Function will load spikes saved into .mat files and cluster all, keeping
%track of dataset origination
timeBefore = 0.04;
timeAfter = 0.16;

%% get total spikes
allSpikeWF = cell(numel(datasetNames),1);
allSpikeInfo = cell(numel(datasetNames),1);
%% get spike data
parfor i = 1:numel(datasetNames)
    try
        lvar = load(sprintf('%s_spikeDL.mat',datasetNames{i}));
        fprintf('Found Mat for %s\n',datasetNames{i});
        spikeWV = lvar.spikeWV;
        spikeInfo = lvar.spikeInfo;
    catch
        session=IEEGSession(datasetNames{i},userid,pwd);
        fprintf('Getting spikes from %s\n',session.data.snapName);
        %load spike times
        a = load([session.data.snapName spikeSuffix]);
        fs = session.data.sampleRate;
        spikeWV = zeros(size(a.spikeTimes,1),(timeBefore+timeAfter)*fs);
        spikeInfo = zeros(size(a.spikeTimes,1),3);
        for j = 1:size(a.spikeTimes,1);
            if round(a.spikeTimes(j,1)/1e6-timeBefore)*fs > 0
                dat = session.data.getvalues(round(a.spikeTimes(j,1)/1e6-timeBefore)*fs :((round(a.spikeTimes(j,1)/1e6-timeBefore))*fs)+(0.2*fs)-1,a.spikeChannels(j));
                if fs ~=400
                    dat = resample(dat,400,fs);
                end
                spikeWV(j,:) = dat;
                spikeInfo(j,:) = [i a.spikeTimes(j,1) a.spikeChannels(j)];
            end
        end
        parsave(sprintf('%s_spikeDL.mat',datasetNames{i}),spikeWV,spikeInfo);
    end
    allSpikeWF{i} = spikeWV;
    allSpikeInfo{i} = spikeInfo;
end

%cluster waveforms
%E = evalclusters(spikes,'kmeans','GAP','klist',[5:30]);
spikeWV = cell2mat(allSpikeWF);
spikeInfo = cell2mat(allSpikeInfo);
[idx b] = kmeans(cell2mat(allSpikeWF),20,'MaxIter',300);

session = IEEGSession(datasetNames{1},userID,pwdFile);
for i = 2:numel(datasetNames)
    session.openDataSet(datasetNames{i})
end
res=  [];
for i = 1:max(idx)
    res = [res plotExFromCluster(session.data,spikeInfo,idx,i)];
end

%save('initialCluster.mat','idx');
load('initialCluster.mat');
%cluster PCS
[a b c] = pca(spikes);
E = evalclusters(b(:,1:2),'kmeans','GAP','klist',[1:30]);
[idx b] = kmeans(b(:,1:2),E.OptimalK);

%% Plot and Remove first
t = 1/400:1/400:.2;
for i = 1:max(idx)
    tmp = spikeWV(idx==i,:);
    subaxis(floor(sqrt(max(idx))),ceil(sqrt(max(idx))),i,'SpacingVert',0.04,'SpacingHoriz',0);
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

for i = 1:max(idx)
res = [res plotExFromCluster(datasetNames,spikeInfo,idx1,i)];
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
resp = [resp plotExFromCluster(datasetNames,spikeInfo,idxp,i)];
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

