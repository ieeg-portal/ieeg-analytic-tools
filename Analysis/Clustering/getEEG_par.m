function [eegdata, eegInfo] = getEEG(dataset,timesUSec,channels,timeBefore,timeAfter)

%% get total spikes
session=IEEGSession(datasetNames{i},IEEGID,IEEGPWD);
        fprintf('Getting spikes from %s\n',session.data.snapName);
        %load spike times
        a = load([session.data.snapName '_' spikeSuffix '.mat']);
        fs = session.data.sampleRate;
        spikeWV = zeros(size(a.spikeTimes,1),(timeBefore+timeAfter)*fs);
        spikeInfo = zeros(size(a.spikeTimes,1),3);
        for j = 1:size(a.spikeTimes,1);
            if round(a.spikeTimes(j,1)/1e6-timeBefore)*fs > 0
                dat = session.data.getvalues(round((a.spikeTimes(j,1)/1e6-timeBefore)*fs) :(round((a.spikeTimes(j,1)/1e6-timeBefore)*fs)+((timeAfter+timeBefore)*fs)-1),a.spikeChannels(j));
                if fs ~=400
                    fprintf('Resampling...%s',session.data.snapName);
                    dat = resample(dat,400,fs);
                end
                spikeWV(j,:) = dat;
                spikeInfo(j,:) = [i a.spikeTimes(j,1) a.spikeChannels(j)];
            end
        end
        parsave(sprintf('%s_%s.mat',datasetNames{i},saveSuffix),spikeWV,spikeInfo);
    end
    allSpikeWF{i} = spikeWV;
    allSpikeInfo{i} = spikeInfo;
end

%cluster waveforms
%E = evalclusters(spikes,'kmeans','GAP','klist',[5:30]);
spikeWV = cell2mat(allSpikeWF);
spikeInfo = cell2mat(allSpikeInfo);

%remove spikes with no surrounding
noPadIdx = spikeInfo(:,1) == 0;
spikeWV(noPadIdx,:) = [];
spikeInfo(noPadIdx,:) = [];
