function [spikeWV, spikeInfo] = clusterSpikesMulti_par(params,spikeSuffix)

datasetNames = params.datasetID;
IEEGID = params.IEEGid;
IEEGPWD = params.IEEGpwd;
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
        lvar = load(sprintf('%s_spikeWV.mat',datasetNames{i}));
        fprintf('Found Mat for %s\n',datasetNames{i});
        spikeWV = lvar.spikeWV;
        spikeInfo = lvar.spikeInfo;
    catch
        session=IEEGSession(datasetNames{i},IEEGID,IEEGPWD);
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
                    fprintf('Resampling...%s',session.data.snapName);
                    dat = resample(dat,400,fs);
                end
                spikeWV(j,:) = dat;
                spikeInfo(j,:) = [i a.spikeTimes(j,1) a.spikeChannels(j)];
            end
        end
        parsave(sprintf('%s_spikeWV.mat',datasetNames{i}),spikeWV,spikeInfo);
    end
    allSpikeWF{i} = spikeWV;
    allSpikeInfo{i} = spikeInfo;
end

%cluster waveforms
%E = evalclusters(spikes,'kmeans','GAP','klist',[5:30]);
spikeWV = cell2mat(allSpikeWF);
spikeInfo = cell2mat(allSpikeInfo);
