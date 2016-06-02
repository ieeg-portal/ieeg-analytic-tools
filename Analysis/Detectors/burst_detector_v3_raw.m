function [eventTimesUSec, eventChannels] = burst_detector_v3(dataset, channels,params)
%Usage: burst_detector_v3(dataset, blockLenSecs, channels)
%This function will calculate bursts based on line length.
%Input: 
%   'dataset'   -   [IEEGDataset]: IEEG Dataset loaded within an IEEG Session
%   'channels'  -   [Nx1 integer array] : channels of interest
%   'params'   -   [struct]    :   Detection parameters

% Author: Hoameng Ung, Questions,comments,bugs : hoameng@upenn.edu
% Updated 7/7/2015

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright 2013 Trustees of the University of Pennsylvania
% 
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
% http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initialization
fs =dataset.sampleRate;
blockLenSecs = params.burst.blockLenSecs;
timeOfInterest = params.timeOfInterest;
filtFlag = params.filtFlag;
datasetFN = dataset.snapName;
if isempty(timeOfInterest)
    duration = dataset.rawChannels(1).get_tsdetails.getDuration/1e6;
    timeOfInterest = [0 duration/1e6];
else
    duration =(timeOfInterest(2) - timeOfInterest(1));
end
startPt = 1+(timeOfInterest(1)*fs);
numPoints = duration*fs;
numParBlocks = 8;
numPointsPerParBlock = numPoints / numParBlocks;
%calculate number of blocks
numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);

eventTimesBlock_par = cell(numParBlocks,1);
eventChannelsBlock_par = cell(numParBlocks,1);
%116392.27
totEvents = 0;
%parpool(numParBlocks);
for i = 1:numParBlocks
    session = IEEGSession(datasetFN,params.IEEGid,params.IEEGpwd);
    if filtFlag
        session.data.setFilter(params.filt.order,params.filt.wn,params.filt.type);
    end
    %% Feature extraction loop
    eventTimesBlock = cell(numBlocks,1);
    eventChannelsBlock = cell(numBlocks,1);
    reverseStr = '';
    startParPt = startPt + (i-1)*numPointsPerParBlock;
    for j = 1:numBlocks
        %Get data
        startBlockPt = startParPt+(blockLenSecs*(j-1)*fs);
        endBlockPt = startParPt+min(blockLenSecs*j*fs,numPointsPerParBlock);
        %get data
        try
            blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        catch
            pause(1);
            blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
        end
        nChan = numel(channels);
        eventTimesUSec = [];
        eventChannels = [];
        if sum(isnan(blockData)) ~= length(blockData)
            %detect bursts
            [startTimesSec, endTimesSec, chan] = burstDetector(blockData, fs, channels,params); 
            if ~isempty(startTimesSec)
                totEvents = totEvents + size(startTimesSec,1);
                startTimesUsec = (startBlockPt/fs + startTimesSec) * 1e6;
                endTimesUsec = (startBlockPt/fs  + endTimesSec) * 1e6;
                toAdd = [startTimesUsec endTimesUsec];
                eventTimesUSec = [eventTimesUSec;toAdd];
                eventChannels = [eventChannels;chan'];
            end
        end
        eventTimesBlock{j} = eventTimesUSec;
        eventChannelsBlock{j} = eventChannels;
        percentDone = 100 * j / numBlocks;
        msg = sprintf('Percent done worker %d: %3.1f',i,percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    eventTimesBlock_par{i} = cell2mat(eventTimesBlock);
    eventChannelsBlock_par{i} = eventChannelsBlock;

end
    eventTimesUSec = cell2mat(eventTimesBlock_par);
    eventChannels = [];
    for i = 1:numel(eventChannelsBlock_par)
        tmp = eventChannelsBlock_par{i};
        tmp = tmp(~cellfun('isempty',tmp));
        if ~isempty(tmp)
            for j = 1:numel(tmp)
                eventChannels = [eventChannels; tmp{j}];
            end
        end
    end
end


function [startTimesSec, endTimesSec, chan] = burstDetector(data, fs, channels, params)
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');

featWinLen = round(params.burst.winLen * fs);

featVals = LLFn2(data, featWinLen);

medFeatVal = nanmedian(featVals);
medFeatVal = repmat(medFeatVal,size(featVals,1),1);
nfeatVals = featVals;%./medFeatVal;

  % get the time points where the feature is above the threshold (and it's not
  % NaN)
  aboveThresh = ~isnan(nfeatVals) & nfeatVals > params.burst.thres & nfeatVals<params.burst.maxThres;
  
aboveThreshPad = aboveThresh;
  %get event start and end window indices - modified for per channel
  %processing
   [evStartIdxs, chan] = find(diff([zeros(1,size(aboveThreshPad,2)); aboveThreshPad]) == 1);
   [evEndIdxs, ~] = find(diff([aboveThreshPad; zeros(1,size(aboveThreshPad,2))]) == -1);
   evEndIdxs = evEndIdxs + 1;

  startTimesSec = evStartIdxs/fs;
  endTimesSec = evEndIdxs/fs;
  
  if numel(channels) == 1
      channels = [channels channels];
  end
  %map chan idx back to channels
  chan = channels(chan);
  
  duration = endTimesSec - startTimesSec;
  idx = (duration<(params.burst.minDur) | (duration>params.burst.maxDur));
  startTimesSec(idx) = [];
  endTimesSec(idx) = [];
  chan(idx) = [];
  
  chan = num2cell(chan);
end

