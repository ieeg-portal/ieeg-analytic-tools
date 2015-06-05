function [timesUSec, channels] = p_detect_bursts_par(params,dparams)

datasetID = params.datasetID;
IEEGid = params.IEEGid;
IEEGpwd = params.IEEGpwd;
% dparams.ch_keep = ch_keep;
% dparams.thres = 2;
% dparams.maxThres = 100;
% dparams.minDur = 1.25;
% dparams.maxDur = 9;
% dparams.FILTFLAG = 1;
timesUSec = cell(numel(datasetID),1);
channels = cell(numel(datasetID),1);
parfor i = 1:numel(datasetID)
    fprintf('Detecting bursts in : %s\n',datasetID{i});
    session = IEEGSession(datasetID{i},IEEGid,IEEGpwd);
    try
        [timesUSec{i}, channels{i}] = burst_detector_v2(session.data,dparams.ch_keep{i},dparams.thres,dparams.maxThres,dparams.minDur,dparams.maxDur,dparams.FILTFLAG);
    catch ME
        disp(ME)
        fprintf('Failed detecting in: %s\n',session.data(i).snapName);
    end
end
