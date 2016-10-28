function [eventTimesUSec, eventChannels] = spatialIntegration(allTimesUSec, allChannels,searchWin)
%Usage: [eventTimeUSec, eventChannels] = spatialIntegration(spikeTimesUSec, spikeChannels,searchWin)
% Function will take as input annotations and combine those searchWin[1]
% before timesUSec and searchWin[2] after.

% Input:    timesUSec 
%           searchWin : 1x2 array containing start, stop in seconds of
%           window
% Channels: double with one channel each

%if annotation is only one point, duplicate for second column
%modified to handle large chunks, 5000 at a time.

numTimes = size(allTimesUSec,1);

numBlocks = ceil(numTimes/10000);
tmpTimes = cell(numBlocks,1);
tmpChannels = cell(numBlocks,1);
if size(allTimesUSec,2) == 1
    allTimesUSec = [allTimesUSec allTimesUSec];
end
[allTimesUSec, sortIdx] = sort(allTimesUSec);
allChannels = allChannels(sortIdx(:,1));
for j = 1:numBlocks
    fprintf('Integration block %d of %d\n',j,numBlocks);
    timesUSec = allTimesUSec(1+(5000*(j-1)):min(5000*j,size(allTimesUSec,1)),:);
    channels = allChannels(1+(5000*(j-1)):min(5000*j,size(allTimesUSec,1)));

    %define windows

    windowTimes = [timesUSec(:,1)-searchWin(1)*1e6 timesUSec(:,2)+searchWin(2)*1e6];
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
       newChannels ={unique([channels(idx)])};

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
    tmpTimes{j} = eventTimesUSec;
    tmpChannels{j} = eventChannels;
    fprintf('done!\n')
%merge overlapping windows
end
eventTimesUSec = cell2mat(tmpTimes);
eventChannels = vertcat(tmpChannels{:});