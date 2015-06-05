function standalone_seizure_v1(snapshot,layerName, blockLenSecs, channels,thresh,maxthresh,minthressecs,maxthressecs)
%Usage: standalone_spike(snapshot, blockLenSecs, channels)
%This function will calculate bursts based on line length.
%Input: 
% snapshot [IEEGDataset]: IEEG Dataset loaded within an IEEG Session
% layerName [string]: String containing name of new layer to be added
% blockLenSecs [integer]: length (in seconds) of each block to process
    %Standard deviation threshold is calculated relative to the length of
    %blockLenSecs
% channels [Nx1 integer array] : channels of interest

%common params
rate = snapshot.channels(channels(1)).sampleRate;
duration = snapshot.channels(channels(1)).get_tsdetails.getDuration / 1e6;
numBlocks = ceil(duration/blockLenSecs);

%burst params
% the amount of padding before and after threshold onset/offset to use, in
% seconds  
burst.std = 0; %standardize to unit variance
burst.filt = 0;
burst.padSecs = .5;
burst.winSecs = 2;
burst.featThresh = thresh;
burst.maxfeatThresh = maxthresh;
%must be > than thresSecs duration
burst.threshSecs = minthressecs;
burst.maxThreshSecs = maxthressecs;
burst.diag=0;

%line length anonymous function
burst.featFn = @(X, winLen) conv2(abs(diff(X,1)),repmat(1/winLen,winLen,1),'same');

%for each block
burstTimes = [];
burstChannels = [];
totEvents = 0;
reverseStr = '';
j = 1;
    while j <= numBlocks
        curPt = 1+ (j-1)*blockLenSecs*rate;
        endPt = (j*blockLenSecs)*rate;
        tmpData = snapshot.getvalues(curPt:endPt,channels);
        %if not all nans
        if sum(isnan(tmpData)) ~= length(tmpData)
            %detect bursts
            [startTimesSec, endTimesSec, chan] = burstDetector(tmpData, rate, channels,burst); 
            if ~isempty(startTimesSec)
                totEvents = totEvents + size(startTimesSec,1);
                startTimesUsec = ((j-1)*blockLenSecs + startTimesSec) * 1e6;
                endTimesUsec = ((j-1)*blockLenSecs + endTimesSec) * 1e6;
                toAdd = [startTimesUsec endTimesUsec];
                burstTimes = [burstTimes;toAdd];
                burstChannels = [burstChannels;chan'];
            end
        end
        percentDone = 100 * j / numBlocks;
        msg = sprintf('Percent done: %3.1f -- Seizures found: %d ',percentDone,totEvents); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        j = j + 1;
    end
    if ~isempty(burstTimes)
        try 
            fprintf('\nRemoving existing layer...');
            snapshot.removeAnnLayer(layerName);
            fprintf('done!\n');
        catch 
             fprintf('\nNo existing seizure layer\n');
        end
        
        fprintf('Creating annotation layer and annotations...');
        annLayer = snapshot.addAnnLayer(layerName);
        uniqueAnnotChannels = unique(burstChannels);
        ann = [];
        for i = 1:numel(uniqueAnnotChannels)
            tmpChan = uniqueAnnotChannels(i);
            ann = [ann IEEGAnnotation.createAnnotations(burstTimes(burstChannels==tmpChan,1),burstTimes(burstChannels==tmpChan,2),'Event','Seizure',snapshot.channels(tmpChan))];
        end
        fprintf('done!\n');
        numAnnot = numel(ann);
        startIdx = 1;
        %add annotations 5000 at a time (freezes if adding too many)
        fprintf('Adding annotations...\n');
        for i = 1:ceil(numAnnot/5000)
            fprintf('Adding %d to %d\n',startIdx,min(startIdx+5000,numAnnot));
            annLayer.add(ann(startIdx:min(startIdx+5000,numAnnot)));
            startIdx = startIdx+5000;
        end
        fprintf('done!\n');
        disp('Seizure Layer added!');
    else
        fprintf('-- No events found \n');
    end
    
end


function [startTimesSec, endTimesSec, chan] = burstDetector(data, rate, channels, params)

%filter data
if params.filt == 1
    for i = 1:size(data,2);
        L = size(data(:,i),1);
        NFFT = length(data(:,i));%2^nextpow2(L);
        Y = fft(data(:,i),NFFT)/L;
        F = ((0:1/NFFT:1-1/NFFT)*rate).';
         if params.diag == 1
             figure;
        plot(F(1:NFFT/2+1),2*abs(Y(1:NFFT/2+1)))
        xlabel('freq (Hz')
         end
       
        Y(F<=4 | F>=rate-4) = 0;
         Y(F>=100 & F<=rate-100) = 0;
         Y(F>=57 & F<=63) = 0;
         Y(F>=rate-63 & F<=rate-57) = 0;
         %plot(F,abs(Y));
        
        reconY = ifft(Y,NFFT,'symmetric')*L;
         if params.diag == 1
             figure;
        subplot(2,1,1);
        plot(data(:,i));
        subplot(2,1,2);
        plot(reconY);
         end
        data(:,i) = reconY;
        
%         [b a] = butter(3,[2/(rate/2)],'high');
%         d1 = filtfilt(b,a,data(:,i));
%         [b a] = butter(3,[70/(rate/2)],'low');
%         d1 = filtfilt(b,a,d1);
%         [b a] = butter(3,[55/(rate/2) 65/(rate/2)],'stop');
%         d1 = filtfilt(b,a,d1);
    end
end

  winSecs = params.winSecs;
  std = params.std;
  featThresh = params.featThresh;
  maxfeatThresh = params.maxfeatThresh;
  padSecs = params.padSecs;
  threshSecs = params.threshSecs;
  maxThreshSecs = params.maxThreshSecs;
  featFn = params.featFn;

  featWinLen = round(winSecs * rate);
  
  if params.diag == 1
  featVals = featFn(data, featWinLen);
  subplot(2,2,1);plot(data(:,1));
  subplot(2,2,2);plot(featVals(:,1));
  end


  if std 
   %subtract mean and divide by standard deviation for each channel
    nmean = nanmean(data);
    nstd = nanstd(data); 
    data = (data-repmat(nmean,size(data,1),1))./repmat(nstd,size(data,1),1);
  end
  % calculate the LL value over the data block
  featVals = featFn(data, featWinLen);
  if params.diag==1
  subplot(2,2,3);plot(data(:,1));
  subplot(2,2,4);plot(featVals(:,1));
  a = input('s')
  end
 
  % get the time points where the feature is above the threshold (and it's not
  % NaN)
  aboveThresh = ~isnan(featVals) & featVals > featThresh & featVals<maxfeatThresh;
  
  % create the pad filter
  numPad = round(padSecs*rate);

  %pad numPad on each side
  padFilt = ones(numPad*2+1,1);
  
  % pad/smear threshold crossings
  %aboveThreshPad = conv(double(aboveThresh), padFilt, 'same') > 0;
  aboveThreshPad = conv2(double(aboveThresh), padFilt, 'same') > 0;

  %get event start and end window indices - modified for per channel
  %processing
  [evStartIdxs, chan] = find(diff([zeros(1,size(aboveThreshPad,2)); aboveThreshPad]) == 1);
  [evEndIdxs, ~] = find(diff([aboveThreshPad; zeros(1,size(aboveThreshPad,2))]) == -1);
  evEndIdxs = evEndIdxs + 1;

  % convert event indices back to original sampling rate
  if ~isempty(evEndIdxs)
    evEndIdxs(end) = min(size(data,1), evEndIdxs(end));
  end
  
  startTimesSec = evStartIdxs/rate;
  endTimesSec = evEndIdxs/rate;
  
  %map chan idx back to channels
  chan = channels(chan);
  
%   %remove spikes by thresholding max line length
%   idx = [];
%   for i = 1:size(evStartIdxs,1)
%       maxFeat = max(max(featVals(evStartIdxs(i):evEndIdxs(i),:)));
%       if maxFeat>maxfeatThresh
%           idx = [idx i];
%       end
%   end
%   startTimesSec(idx) = [];
%   endTimesSec(idx) = [];
%   chan(idx) = [];
  
  duration = endTimesSec - startTimesSec;
  idx = (duration<(threshSecs+2*padSecs)) | (duration>maxThreshSecs);
  startTimesSec(idx) = [];
  endTimesSec(idx) = [];
  chan(idx) = [];
  
  
end

