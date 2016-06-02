function [eventTimesUSec, eventChannels] = spatialIntegration(timesUSec, channels,searchWin)
%Usage: [eventTimeUSec, eventChannels] = spatialIntegration(spikeTimesUSec, spikeChannels,searchWin)
% Function will take as input annotations and combine those searchWin[1]
% before timesUSec and searchWin[2] after.

% Input:    timesUSec 

%if annotation is only one point, duplicate for second column

[timesUSec, sortIdx] = sort(timesUSec);
channels = channels(sortIdx);
if size(timesUSec,2) == 1
    timesUSec = [timesUSec timesUSec];
end
%define windows

windowTimes = [timesUSec(:,1)-searchWin(1)*1e3 timesUSec(:,2)+searchWin(2)*1e3];
tmpWindowTimes = windowTimes;
eventTimesUSec = zeros(size(windowTimes,1),2);
eventChannels = cell(size(windowTimes,1),1);
i = 1;
maxIter = size(tmpWindowTimes,1);
fprintf('Spatial integration...')
while ~isempty(tmpWindowTimes(:,1));
   %loop through each window
   x = tmpWindowTimes(1,:);
   idx = x(:,2)>=windowTimes(:,1) & x(:,1)<=windowTimes(:,2);
   
   %aggregate window times of original and any overlap 
   overlapping = [tmpWindowTimes(idx,:)];
   newWindow = [min(overlapping(:,1)) max(overlapping(:,2))];
   newChannels ={unique([channels{idx}])};
   
   tmpWindowTimes(idx,:) = [];
   windowTimes(idx,:) = [];
   channels(idx) = [];
   eventTimesUSec(i,:) = newWindow;
   eventChannels(i) = newChannels;
   %eventTimesUSec = [eventTimesUSec;newWindow];
   %eventChannels = [eventChannels; newChannels];
   i = i + 1;
end
eventChannels(i:end) = [];
eventTimesUSec(i:end,:) = [];
fprintf('done!\n')
%merge overlapping windows
