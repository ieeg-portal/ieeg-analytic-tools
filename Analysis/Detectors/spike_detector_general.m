function [spikeTimesUSec, spikeChannels] = spike_detector_general(dataset,channels,varargin);
% Usage: standalone_spike_LL(dataset,channels,params)
% Input:
%       dataset     : IEEGDataset object
%       channels    : Cell array, each element contacts vector of channels
%       to calculate spikes over
%       params      : parameter structs

find_nearest_peak = 0;
absthresh = 0;
timeOfInterest = [];
filtFlag = 0;
for i = 1:2:nargin-2
    switch varargin{i}
        case 'absthresh'
            absthresh = varargin{i+1};
        case 'winLen'
            winLen = varargin{i+1};
        case 'timeOfInterest'
            timeOfInterest = varargin{i+1};
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end

%Split data into blocks
%get data 1 hr at a time
numParBlocks = 200; %% NUMBER OF PARALLEL BLOCKS
numParProcs = 16; % NUMBER OF WORKERS
blockLenSecs = 3600; %get data in blocks

CalcNumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));
DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
AreaFn = @(x) nanmean(abs(x));
EnergyFn = @(x) nanmean(x.^2);
ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
LLFn = @(x) nanmean(abs(diff(x)));
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');

if isempty(timeOfInterest)
    duration = dataset.rawChannels(1).get_tsdetails.getDuration/1e6;
    startPt = 1;
else
    duration =(timeOfInterest(2) - timeOfInterest(1));
    startPt = 1+(timeOfInterest(1)*fs);
end

numBlocks = duration / 3600;
datasetFN = dataset.snapName;
numWins = CalcNumWins(blockLenSecs*fs,fs,winLen,winDisp);
nChan = numel(channels);
  
%for each block

