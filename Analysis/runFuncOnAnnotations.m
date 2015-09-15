function [out, raw] = runFuncOnAnnotations(dataset,layerName,fun,params)
% Usage: out = runFuncOnAnnotations(layerName,fun)
% Function will run provided function "fun" on annotations in layer
% layerName in IEEGdataset dataset and return output in cell array out,
% with numel equal to number of annotations

%anonymous functions
%EnergyFn = @(x) mean(x.^2);
%ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
%LLFn = @(x) mean(abs(diff(x)));
beforeTime = params.runFunc.beforeTime;
afterTime = params.runFunc.afterTime;

[~, timesUSec, eventChannels] = getAllAnnots(dataset,layerName);
out = cell(size(timesUSec,1),1);
raw = cell(size(timesUSec,1),1);

fs = dataset.sampleRate;
for i = 1:size(timesUSec,1)
    startPt = round((timesUSec(i,1)/1e6-beforeTime)*fs);
    endPt = round((timesUSec(i,2)/1e6+afterTime)*fs);
    tmpDat = dataset.getvalues(startPt:endPt,eventChannels{i});
    raw{i} = tmpDat;
    out{i} = fun(tmpDat,fs,params);
end

