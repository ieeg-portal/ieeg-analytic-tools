function [out, raw] = runFuncOnAnnotations(dataset,fun,varargin)
% Usage: out = runFuncOnAnnotations(layerName,fun)
% Function will run provided function "fun" on annotations in layer
% layerName in IEEGdataset dataset and return output in cell array out,
% with numel equal to number of annotations

% INPUT
%   dataset     :   IEEG Dataset object
%   layerName   :   layer name (string)
%   fun         :   function handle to calculate features

% Hoameng Ung
% University of Pennsylvania
% 12/6/2016

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
feature_params = [];
useAllCh = 0;
timesUSec = [];
eventChannels = [];
layerName = [];
for i = 1:2:nargin-2
    switch varargin{i}
        case 'runOnWin'
            runOnWin = varargin{i+1};
        case 'PadStartBefore'
            beforeStartTime = varargin{i+1};
        case 'PadStartAfter'
            afterStartTime = varargin{i+1};
        case 'PadEndAfter'
            afterEndTime = varargin{i+1};
        case 'useAllChannels'
            useAllCh = varargin{i+1};
        case 'customTimeWindows'
            timesUSec = varargin{i+1}.eventTimesUSec;
            eventChannels = varargin{i+1}.eventChannels;
        case 'layerName'
            layerName = varargin{i+1};
        case 'feature_params'
            feature_params = varargin{i+1};
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end
if isempty(timesUSec)
    if isempty(layerName)
        error('Need either layername of custom time windows');
    else
        [~, timesUSec, eventChannels] = getAnnotations(dataset,layerName);
    end
end
out = cell(size(timesUSec,1),1);
raw = cell(size(timesUSec,1),1);
totalCh = numel(dataset.rawChannels);
fs = dataset.sampleRate;
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
    raw{i}.eeg = tmpDat;
    raw{i}.times = [startPt/fs endPt/fs];
    if runOnWin
        if ~isempty(feature_params)
            out{i} = runFuncOnWin(tmpDat,fs,fun,feature_params);
        else
            out{i} = runFuncOnWin(tmpDat,fs,fun);
        end
    else
        %[r, c] = find(isnan(tmpDat));
        %tmpDat(unique(r),:) = [];
        if ~isempty(feature_params)
            out{i} = fun(tmpDat,fs,feature_params);
        else
            out{i} = fun(tmpDat,fs);
        end
    end
    continue
end

