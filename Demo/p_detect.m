[timesUSec, channels] = p_detect_bursts_par(params,prefix);
datasetID = params.datasetID;
parfor i = 1:numel(datasetID)
    fprintf('Detecting bursts in : %s\n',session.data(i).snapName);
    try
        [burstTimes, burstChannels] = burst_detector_v2(session.data(i),channelIdxs{i},2,100,1.25,9,filtFlag);
    catch ME
        disp(ME)
        fprintf('Failed detecting in: %s\n',session.data(i).snapName);
    end
end
