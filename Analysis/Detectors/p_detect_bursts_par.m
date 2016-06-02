function [atimesUSec, achannels] = p_detect_bursts_par(params)

datasetID = params.datasetID;
IEEGid = params.IEEGid;
IEEGpwd = params.IEEGpwd;
% dparams.ch_keep = ch_keep;
% dparams.thres = 2;
% dparams.maxThres = 100;
% dparams.minDur = 1.25;
% dparams.maxDur = 9;
% dparams.FILTFLAG = 1;
atimesUSec = cell(numel(datasetID),1);
achannels = cell(numel(datasetID),1);
for i = 1:numel(datasetID)
    fprintf('Detecting bursts in : %s\n',datasetID{i});
    try
        lvar = load(sprintf('%s_%s.mat',datasetID{i}),saveSuffix);
        fprintf('Found %s.mat for %s\n',saveSuffix, datasetID{i});
        atimesUSec{i} = lvar.timesUSec;
        aeventInfo{i} = lvar.channels;
    catch
        try
            session = IEEGSession(datasetID{i},IEEGid,IEEGpwd);
            [timesUSec, channels] = burst_detector_v3(session.data,params.ch_keep{i},params);
            atimesUSec{i} = timesUSec;
            aeventInfo{i} = channels;
            parsave(sprintf('%s_%s.mat',datasetID{i},params.burst.saveLabel),timesUSec,channels);
        catch ME
            disp(ME)
            fprintf('Failed detecting in: %s\n',datasetID{i});
        end
    end
end
