function [spikeTimes, spikeChannels, DE] = spike_ja_wrapper(dataset,channels,params)
    fs = dataset.sampleRate;

    dataLim = 500*130*2000;
    durInPts = dataset.rawChannels(1).get_tsdetails.getDuration/1e6*fs;
    data = getAllData(dataset,channels,3600);
    [DE]=spike_detector_hilbert_v16_byISARG(data,fs, '-h 60');
    spikeTimes = DE.pos*1e6;
    spikeChannels = num2cell(channels(DE.chan));
    fprintf('%d spikes found\n',size(spikeTimes,1));
end



