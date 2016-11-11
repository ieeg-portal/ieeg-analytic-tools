function newTimesUSec = findNearestPeak(dataset,timesUSec,eventChannels,searchWin)

fs = dataset.sampleRate;
newTimesUSec = zeros(size(timesUSec,1),1);
for i = 1:size(timesUSec,1)
    data = dataset.getvalues(((timesUSec(i,1)/1e6)-searchWin(1))*fs:((timesUSec(i,1)/1e6)+searchWin(2)) * fs,eventChannels{i});
    data = bsxfun(@minus,data,mean(data));
    [pk, locs] = findpeaks(abs(data));
    shift = locs(pk==max(pk));
    newTime = (((timesUSec(i,1)/1e6)-searchWin(1))*fs + (shift-1))/fs*1e6;
    newTimesUSec(i,1) = newTime;
end