function [spikeTimes, spikeChannels] = spike_ku_wrapper(IEEGDataset,channels,params)
    fs = IEEGDataset.sampleRate;
    eventIdxs = cell(numel(channels),1);
    eventChannels = cell(numel(channels),1);
    for c = 1:numel(channels)
        data = getAllData(IEEGDataset,c);
        [spikeData padLength] = spike_ku_v4(data, fs, 1/fs, logical(1),params);
        eventIdxs{c} = spikeData(:,1);
        eventChannels{c} = ones(size(eventIdxs{c},1),1)*channels(c);
    end
    spikeTimes = cell2mat(eventIdxs)*1e6;
    spikeChannels = cell2mat(eventChannels);
    fprintf('%d spikes found\n',size(spikeTimes,1));

end



