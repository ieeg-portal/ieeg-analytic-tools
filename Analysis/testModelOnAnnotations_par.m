function [yhat, yhat_score] = testModelOnAnnotations_par(dataset,layerName,model,fun,varargin)
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
N = size(timesUSec,1);
out = cell(N,1);
totalCh = numel(dataset.rawChannels);
fs = dataset.sampleRate;

numParBlocks = 200;
numParProcs = 16;

numPointsPerParBlock = N/ceil(numParBlocks);

yhat = cell(numParBlocks,1);
yhat_score = cell(numParBlocks,1);
try
parpool(numParProcs)
catch
end
parDat = [];
for i = 1:numParBlocks
    parDat(i).eventTimesUSec = timesUSec(1+round((i-1)*numPointsPerParBlock):round(min(i*numPointsPerParBlock,N)),:);
    parDat(i).eventChannels = eventChannels(1+round((i-1)*numPointsPerParBlock):round(min(i*numPointsPerParBlock,N)));
end
parfor i=1:numParBlocks
    parsavename = sprintf('%s-testmodel-parsave%0.4d.mat',dataset.snapName,i);
    if exist(parsavename,'file')~=2
        session = IEEGSession(dataset.snapName,'hoameng','hoa_ieeglogin.bin');
        fprintf('Working on parfor %d/%d...\n',i,numParBlocks);
        feats = runFuncOnAnnotations(session.data,layerName,fun,'runOnWin',0,'useAllChannels',1,'customTimeWindows',parDat(i));
        feats = cell2mat(feats);
        parsave(parsavename,feats)
    else
        tmp = load(parsavename,'feats');
        feats = tmp.feats;
    end
    [tmp_yhat, tmp_score] = predict(model,feats);
    yhat{i} = cell2mat(cellfun(@(x)str2num(x),tmp_yhat,'UniformOutput',0));
    yhat_score{i} = tmp_score;
end
%delete(h)

