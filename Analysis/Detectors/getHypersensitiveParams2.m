function [=getHypersensitiveParams2(dataset,train_layer,varargin)
%Function will return recommended winLen,threshold,feature to use

pad_mult = 2; %multiple of pattern window length to use as background
showPlots = 0;
detect_spikes = 0;
for i = 1:2:nargin-2
    switch varargin{i}
        case 'pad_mult'
            pad_mult = varargin{i+1};
        case 'show_plots'
            showPlots = varargin{i+1};
        case 'detect_spikes'
            detect_spikes = varargin{i+1};
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end

fs = dataset.sampleRate;
nCh = numel(dataset.rawChannels);

%% features 
LLFn = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');
ENFn = @(X, winLen) envelope_smooth(X,winLen);
featFn{1} = LLFn;
featFn{2} = ENFn;

%% get all training layer annotations
[~, timesUSec, eventChannels] = getAnnotations(dataset,train_layer);
win = zeros(size(timesUSec,1),1);
patternFeat = {};
bckfeat = {};
threshold = {};
durations = {};

%% if spike, adjust times to nearest peak
if detect_spikes
    tmpdur = sum(timesUSec(:,2)-timesUSec(:,1))/1e6;
    if tmpdur == 0 %if duration is 0, assume spike
        searchWin = [0.2 0.2]; %s before and after to search
        timesUSec = findNearestPeak(dataset,timesUSec,eventChannels,searchWin);
        timesUSec = [timesUSec-0.05*1e6 timesUSec+0.05*1e6];
    end
end

runFuncOnWin(featFn{1})
