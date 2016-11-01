function [yhat, yhat_score] = testModelOnAnnotations(dataset,layerName,model,fun,varargin)
% Usage: out = runFuncOnAnnotations(layerName,fun)
% Function will run provided function "fun" on annotations in layer
% layerName in IEEGdataset dataset and return output in cell array out,
% with numel equal to number of annotations

% INPUT
%   dataset     :   IEEG Dataset object
%   layerName   :   layer name (string)
%   fun         :   function handle to calculate features

%anonymous functions
%EnergyFn = @(x) mean(x.^2);
%ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
%LLFn = @(x) mean(abs(diff(x)));

%DEFAULTS
beforeStartTime = 0;
afterStartTime = 0;
afterEndTime = 0;
runOnWin = 0;
highlightch = [];
padsec = [];
params = [];
useAllCh = 0;
timesUSec = [];
eventChannels = [];
for i = 1:2:nargin-4
    switch varargin{i}
        case 'runOnWin'
            runOnWin = varargin{i+1};
        case 'PadStartBefore'
            beforeStartTime = varargin{i+1};
        case 'PadStartAfter'
            afterStartTime = varargin{i+1};
        case 'PadEndAfter'
            afterEndTime = varargin{i+1};
        case 'fnparams'
            params = varargin{i+1};
        case 'useAllChannels'
            useAllCh = varargin{i+1};
        case 'customTimeWindows'
            timesUSec = varargin{i+1}.eventTimesUSec;
            eventChannels = varargin{i+1}.eventChannels;
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end
if isempty(timesUSec)
    [~, timesUSec, eventChannels] = getAnnotations(dataset,layerName);
end
out = cell(size(timesUSec,1),1);
raw = cell(size(timesUSec,1),1);
totalCh = numel(dataset.rawChannels);
fs = dataset.sampleRate;
yhat = zeros(size(timesUSec,1),1);
yhat_score = zeros(size(timesUSec,1),2);
for i = 1:size(timesUSec,1)
    startPt = round((timesUSec(i,1)/1e6-beforeStartTime)*fs);
    %endPt = round((timesUSec(i,1)/1e6+afterStartTime)*fs);
    endPt = round((timesUSec(i,2)/1e6+afterEndTime)*fs);
    if useAllCh
        tmpDat = dataset.getvalues(startPt:endPt,1:totalCh);
    else
        tmpDat = dataset.getvalues(startPt:endPt,eventChannels{i});
    end
    %trim leading and trailing nans
    tmpDat = tmpDat(~all(isnan(tmpDat),2),~all(isnan(tmpDat),1));
    %raw{i}.eeg = tmpDat;
    %raw{i}.times = [startPt/fs endPt/fs];
    if runOnWin
        if ~isempty(params)
            out{i} = runFuncOnWin(tmpDat,fs,fun,params);
        else
            out{i} = runFuncOnWin(tmpDat,fs,fun);
        end
    else
        %[r, c] = find(isnan(tmpDat));
        %tmpDat(unique(r),:) = [];
        if ~isempty(params)
            feat = fun(tmpDat,fs,params);
        else
            feat = fun(tmpDat,fs);
        end
    end
    [tmp_yhat, tmp_score] = predict(model,feat);
    yhat(i) = str2num(tmp_yhat{1});
    yhat_score(i,:) = tmp_score;
    continue
end

