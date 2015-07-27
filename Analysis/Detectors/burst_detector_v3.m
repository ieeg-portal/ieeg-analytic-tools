function [eventTimesUSec, eventChannels] = burst_detector_v3(dataset, channels,dparams)
%Usage: burst_detector_v2(dataset, blockLenSecs, channels)
%This function will calculate bursts based on line length.
%Input: 
%   'dataset'   -   [IEEGDataset]: IEEG Dataset loaded within an IEEG Session
%   'channels'  -   [Nx1 integer array] : channels of interest
%   'dparams'   -   [struct]    :   Detection parameters

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
timeOfInterest = dparams.timeOfInterest;
if isempty(timeOfInterest)
    duration = dataset.channels(1).get_tsdetails.getDuration/1e6;
else
    duration =(timeOfInterest(2) - timeOfInterest(1));
end
startPt = 1+(timeOfInterest(1)*fs);
numPoints = duration*fs;
numParBlocks = 5;
numPointsPerParBlock = numPoints / numParBlocks;
%calculate number of blocks
numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);

parFeats = cell(numParBlocks,1);
%pool(numParBlocks);
parfor i = 1:numParBlocks
    session = IEEGSession(datasetFN,IEEGid,IEEGpwd);
    %% Feature extraction loop
    feat = cell(numBlocks,1);
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
        percentValid = 1-sum(isnan(blockData),1)/size(blockData,1);
        nChan = numel(channels);
        tmpFeat = zeros(numWins,nChan);
        if sum(isnan(tmpData)) ~= length(tmpData)
            %detect bursts
            [startTimesSec, endTimesSec, chan] = burstDetector(blockData, fs, channels,dparams); 

            if ~isempty(startTimesSec)
                totEvents = totEvents + size(startTimesSec,1);
                startTimesUsec = ((i-1)*blockLenSecs + startTimesSec) * 1e6;
                endTimesUsec = ((i-1)*blockLenSecs + endTimesSec) * 1e6;
                toAdd = [startTimesUsec endTimesUsec];
                eventTimesUSec = [eventTimesUSec;toAdd];
                eventChannels = [eventChannels;chan'];
            end
        end
        feat{j} = tmpFeat;
        percentDone = 100 * j / numBlocks;
        msg = sprintf('Percent done worker %d: %3.1f',i,percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    fprintf('\n');
    feat = cell2mat(feat);
    parFeats{i} = feat;
end
    save([datasetFN '_' params.saveLabel '.mat'],'parFeats','-v7.3');
end






%common params
fs = dataset.channels(channels(1)).sampleRate;
duration = dataset.channels(channels(1)).get_tsdetails.getDuration / 1e6;
blockLenSecs = 2*60*60;
numBlocks = ceil(duration/blockLenSecs);

%burst params
winLen = dparams.winLen;

%line length anonymous function
dparams.featFn = @(X, winLen) conv2(abs(diff(X,1)),repmat(1/winLen,winLen,1),'same');

%for each block
eventTimesUSec = [];
eventChannels = [];
totEvents = 0;
reverseStr = '';
for i = 1:numBlocks
    curPt = 1+ (i-1)*blockLenSecs*fs;
    endPt = (i*blockLenSecs)*fs;
    tmpData = dataset.getvalues(curPt:endPt,channels);
    %if not all nans
    if sum(isnan(tmpData)) ~= length(tmpData)
        %detect bursts
        [startTimesSec, endTimesSec, chan] = burstDetector(tmpData, fs, channels,dparams); 
        
        if ~isempty(startTimesSec)
            totEvents = totEvents + size(startTimesSec,1);
            startTimesUsec = ((i-1)*blockLenSecs + startTimesSec) * 1e6;
            endTimesUsec = ((i-1)*blockLenSecs + endTimesSec) * 1e6;
            toAdd = [startTimesUsec endTimesUsec];
            eventTimesUSec = [eventTimesUSec;toAdd];
            eventChannels = [eventChannels;chan'];
        end
    end
    percentDone = 100 * i / numBlocks;
    msg = sprintf('Percent done: %3.1f -- Bursts found: %d ',percentDone,totEvents); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
end
 
end


function [startTimesSec, endTimesSec, chan] = burstDetector(data, fs, channels, dparams)

orig = data;
%filter data
if dparams.FILTFLAG == 1
    for i = 1:size(data,2);
        [b, a] = butter(4,[1/(fs/2)],'high');
        d1 = filtfilt(b,a,data(:,i));
        try
        [b, a] = butter(4,[70/(fs/2)],'low');
        d1 = filtfilt(b,a,d1);
        catch
        end
        [b, a] = butter(4,[58/(fs/2) 62/(fs/2)],'stop');
         d1 = filtfilt(b,a,d1);
        data(:,i) = d1;
    end
end

featWinLen = round(dparams.winLen * fs);

featVals = dparams.featFn(data, featWinLen);

medFeatVal = median(featVals);
medFeatVal = repmat(medFeatVal,size(featVals,1),1);
nfeatVals = featVals./medFeatVal;

  % get the time points where the feature is above the threshold (and it's not
  % NaN)
  aboveThresh = ~isnan(nfeatVals) & nfeatVals > dparams.thres & nfeatVals<dparams.maxThres;
  
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
  idx = (duration<(dparams.minDur) | (duration>dparams.maxDur));
  startTimesSec(idx) = [];
  endTimesSec(idx) = [];
  chan(idx) = [];
  
  chan = num2cell(chan);
end

