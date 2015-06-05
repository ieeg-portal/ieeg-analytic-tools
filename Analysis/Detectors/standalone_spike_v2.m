function standalone_spike_v2(snapshot, layerName,blockLenSecs, channels)
%Usage: standalone_spike_v2(snapshot, layerName,blockLenSecs, channels)
%This function will calculate spikes and upload annotations
%to the raw dataset on the portal. Data is first filtered and spikes above
%a set amplitude greater than a threshold are retained. Threshold is
%defined as a multiple of the standard deviation within each blockLenSec block. Other
%Parameters can be specified (detailed below). Improvements pending
%
%Input: 
% snapshot [IEEGDataset]: IEEG Dataset loaded within an IEEG Session
% layerName [string]: String containing name of new layer to be added
% blockLenSecs [integer]: length (in seconds) of each block to process
    %Standard deviation threshold is calculated relative to the length of
    %blockLenSecs (300 seconds is default)
% channels [Nx1 integer array] : channels of interest
%
%Options: (set below)
%spike.sepSpkDur : minimum distance between spike peaks
%spike.mult : threshold multiplier
%spike.filt : filter toggle
%spike.frontPad : padding before peak
%spike.backPad : padding after peak
%


%%
%Update History:
%v1. 3/24/2014 - changed input to IEEGdataset, various other updates
%common params
%v2. 6/23/2014 - edited comments, added license, changed filter to butterworth
%

% Author: Hoameng Ung, Questions,comments,bugs : hoameng@upenn.edu

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

rate = snapshot.channels(channels(1)).sampleRate;
duration = snapshot.channels(channels(1)).get_tsdetails.getDuration / 1e6;
numBlocks = ceil(duration/blockLenSecs);

%spike params
spike.sepSpkDur = 0.2; %(s)
spike.mult = 6; %mult*SD is threshold
spike.filt = 1; %filter toggle (1 on, 0 off)
spike.spatial = 0; %to be implemented
spike.frontPad = .100; %100 ms padding on front, 200 ms on back
spike.backPad = .200; %200 ms

%for each block
spikeTimes = [];
spikeChannels = [];
j = 1;
while j < numBlocks
    curPt = 1+ (j-1)*blockLenSecs*rate;
    endPt = (j*blockLenSecs)*rate;
    tmpData = snapshot.getvalues(curPt:endPt,channels);
    %if not all nans
    if sum(isnan(tmpData)) ~= length(tmpData)
        %detect spikes
        [startTimesSec, chan] = spikeDetector(tmpData, rate, channels, spike);
        disp(['Found ' num2str(size(startTimesSec,1)) ' spikes']);
        if ~isempty(startTimesSec)
            startTimesUsec = ((j-1)*blockLenSecs + startTimesSec(:,1)) * 1e6 - (spike.frontPad*1e6);
            endTimesUsec = ((j-1)*blockLenSecs + startTimesSec(:,1)) * 1e6 + (spike.backPad * 1e6);
            toAdd = [startTimesUsec endTimesUsec];
            spikeTimes = [spikeTimes;toAdd];
            spikeChannels = [spikeChannels;chan];
        end
    end
    disp(['Processed block ' num2str(j) ' of ' num2str(numBlocks)]);
    j = j + 1;
end
disp(['Total spikes found: ' num2str(size(spikeTimes,1))]);

%Removing out of bound spikes
[a, ~] = find(spikeTimes<0);
spikeTimes(unique(a),:) = [];
spikeChannels(unique(a)) = [];

if ~isempty(spikeTimes)
    foundLayer = find(strcmp(layerName,{snapshot.annLayer.name}),1);
    if ~isempty(foundLayer)
        disp('Removing existing spike layer');
        snapshot.removeAnnLayer(layerName);
    end
    spikeLayer = snapshot.addAnnLayer(layerName);
    spikeAnn = [];
    for i = 1:length(spikeChannels)
        spikeAnn = [spikeAnn IEEGAnnotation.createAnnotations(spikeTimes(i,1),spikeTimes(i,2),'Event','Spike',snapshot.channels(spikeChannels(i)))];
    end
    spikeLayer.add(spikeAnn);
    disp('Spike layer added!');
end
end



function [spiketimes, finalChannels] = spikeDetector(data, rate, channels, params)
%Detects spikes in data and returns time of spikes in spikeData. Currently
%only uses an amplitude threshold as a function of standard deviation.
%Improvements pending.
%Input: Timeseries (TxP) with p(p>1) channels, sample rate, channels,
%params.
%Params:
%   1. params.filt: if == 1, will filter data with
%       i. high pass filter at 2 hz
%       ii. low pass filter at 70 hz
%       iii. band gap filter at 58 - 62 hz
%   2. params.mult: set threshold as a multiple of standard deviation
%   3. params.sepSpkDur: time (s) required to distinguish between two
%   spikes

warning('off')

%filter data - 4th order butterworth
% 1. 1 Hz high pass
% 2. 70 Hz low pass
% 3. [58 62] bandstop
if params.filt == 1
    for i = 1:size(data,2);
        [b a] = butter(4,[1/(rate/2)],'high');
        d1 = filtfilt(b,a,data(:,i));
        [b a] = butter(4,[70/(rate/2)],'low');
        d1 = filtfilt(b,a,d1);
        [b a] = butter(4,[58/(rate/2) 62/(rate/2)],'stop');
        d1 = filtfilt(b,a,d1);
        data(:,i) = d1;
    end
end

numChan = size(data,2);
%sd = median(abs(data)./.6795); %(Quiroga 2004, multiunit spike)
sd = std(data);

x = cell(numChan,1);
for i = 1:numChan
    %find timepoints where value is > than mult*sd for that channel
    tmpData = data(:,i) - repmat(mean(data(:,i)),size(data,1),1);
    [~, x{i}] = findpeaks(abs(tmpData),'MinPeakHeight',params.mult*sd(i),'MinPeakDistance',params.sepSpkDur*rate); 
    %find(abs(data(:,i))>mult*sd(i));
end

%map back to time
spiketimes = [];
finalChannels = [];
for i = 1:size(x,1)
    if ~isempty(x{i})
        [finalspikes, ~]= sort(x{i});
        spkChan = ones(length(finalspikes),1)*channels(i);
        spiketimes = [spiketimes; finalspikes/rate];
        finalChannels = [finalChannels; spkChan];
    end
end

end

