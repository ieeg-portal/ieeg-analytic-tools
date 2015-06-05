function [spikeTimes spikeChannels] = standalone_spike_keating_std(snapshot,layerName, blockLenSecs, channels,mult,spkdur,aftdur)
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
duration = snapshot.channels(channels(1)).get_tsdetails.getDuration/1e6;
numBlocks = ceil(duration/blockLenSecs);

%for each block
eventTimes = [];
eventChannels = [];
totSpikes = 0;
j = 1;
reverseStr = '';
    while j <= numBlocks
        curPt = 1+ (j-1)*blockLenSecs*rate;
        endPt = (j*blockLenSecs)*rate;
        tmpData = snapshot.getvalues(curPt:min(endPt,duration*rate),channels);
        %if stdflag
            %zscore - doesn't seem to work well
            %tmpData = zscore(tmpData);
           
            %scale -1 to 1 : %outlier effects prominent
           % tmpData = scalestd(tmpData,1.5);
            
            %for each channel, make 99% of points between [-10 10]
                %numPts = size(tmpData(:,1),1);
       % end
        %if not all nans
        if sum(isnan(tmpData)) ~= length(tmpData)
            %detect bursts
            startTimesSec = [];
            endTimesSec = [];
            chan = [];
            for k = 1:numel(channels)
                thres =  mean(tmpData(:,1)) + mult*std(tmpData(:,k));
                if sum(tmpData(:,k)==0)/numel(tmpData(:,k))< 0.2 %run if more than 20% are nonzeroes for stability
                    [spikeData padLength] = spiker_v3(tmpData(:,k), rate, 0, logical(1), spkdur, thres, aftdur);
                    if ~isempty(spikeData)
                        startTimesSec = [startTimesSec; spikeData(:,1)];
                        endTimesSec = [endTimesSec; spikeData(:,1)+.4];
                        chan = [chan ones(1,numel(spikeData(:,1)))*channels(k)];
                    end
                end
            end
            %[startTimesSec, endTimesSec, chan] = spikeDetector(tmpData, rate, channels,spike); 
            if ~isempty(startTimesSec)
               % disp(['Found ' num2str(size(startTimesSec,1)) ' spikes']);
                totSpikes = totSpikes + size(startTimesSec,1);
                startTimesUsec = ((j-1)*blockLenSecs + startTimesSec) * 1e6;
                endTimesUsec = ((j-1)*blockLenSecs + endTimesSec) * 1e6;
                toAdd = [startTimesUsec endTimesUsec];
                eventTimes = [eventTimes;toAdd];
                eventChannels = [eventChannels;chan'];
            end
        end   
        percentDone = 100 * j / numBlocks;
        msg = sprintf('Percent done: %3.1f -- Spikes found: %d ',percentDone,totSpikes); %Don't forget this semicolon
        if totSpikes==103
            test = '1';
        end
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        %disp(['Processed block ' num2str(j) ' of ' num2str(numBlocks)]);
        j = j + 1;
    end
    if ~isempty(eventTimes)
        try 
            fprintf('\nRemoving existing spike layer\n');
            snapshot.removeAnnLayer(layerName);
        catch 
            fprintf('No existing spike layer\n');
        end
        annLayer = snapshot.addAnnLayer(layerName);
        uniqueAnnotChannels = unique(eventChannels);
        ann = [];
        for i = 1:numel(uniqueAnnotChannels)
            tmpChan = uniqueAnnotChannels(i);
            ann = [ann IEEGAnnotation.createAnnotations(eventTimes(eventChannels==tmpChan,1),eventTimes(eventChannels==tmpChan,1),'Event','spike',snapshot.channels(tmpChan))];
        end
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
    else
        fprintf('\n');s
    end
end


