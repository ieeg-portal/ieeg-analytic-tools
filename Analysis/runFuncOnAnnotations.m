function [out, raw] = runFuncOnAnnotations(dataset,layerName,fun,params,runOnWin)
% Usage: out = runFuncOnAnnotations(layerName,fun)
% Function will run provided function "fun" on annotations in layer
% layerName in IEEGdataset dataset and return output in cell array out,
% with numel equal to number of annotations

%anonymous functions
%EnergyFn = @(x) mean(x.^2);
%ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
%LLFn = @(x) mean(abs(diff(x)));
beforeStartTime = params.runFunc.beforeStartTime;
afterStartTime = params.runFunc.afterStartTime;
afterEndTime = params.runFunc.afterEndTime;
[~, timesUSec, eventChannels] = getAnnotations(dataset,layerName);
out = cell(size(timesUSec,1),1);
raw = cell(size(timesUSec,1),1);

fs = dataset.sampleRate;
for i = 1:size(timesUSec,1)
    startPt = round((timesUSec(i,1)/1e6-beforeStartTime)*fs);
    %endPt = round((timesUSec(i,1)/1e6+afterStartTime)*fs);
    endPt = round((timesUSec(i,2)/1e6+afterEndTime)*fs);
    tmpDat = dataset.getvalues(startPt:endPt,eventChannels{i});
    %trim leading and trailing nans
    tmpDat = tmpDat(~all(isnan(tmpDat),2),~all(isnan(tmpDat),1));
    raw{i}.eeg = tmpDat;
    raw{i}.times = [startPt/fs endPt/fs];
    if runOnWin
        out{i} = runFuncOnWin(tmpDat,fs,fun,params);
    else
        %[r, c] = find(isnan(tmpDat));
        %tmpDat(unique(r),:) = [];
        out{i} = fun(tmpDat,fs,params);
    end
    continue
end

