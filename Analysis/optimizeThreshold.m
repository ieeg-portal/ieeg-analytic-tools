function [combinedAnnots, combinedChannels] = optimizeThreshold(dataset, parameters)
% Change this at some point to tune on an input layer
% For now just threshold at preset values
%
% Usage: f_burst_linelength(dataset, parameters)
% Input: 
%   'dataset'   -   [IEEGDataset]: IEEG Dataset, eg session.data(1)
%   'parameters'    -   Structure containing parameters for the analysis
% 
%   dbstop in optimizeThreshold at 83

  animalName = char(dataset.snapName);
  channels = parameters.DatasetInfo.channelsToRun;
  minThreshold = parameters.InitialDetection.minThreshold;
  maxThreshold = parameters.InitialDetection.maxThreshold;
  minDur = parameters.InitialDetection.minDuration; % sec; default min duration of detection
  maxDur = parameters.InitialDetection.maxDuration; % sec; default min duration of detection

  % save annotations out to a file so addAnnotations can upload them all at once
  inputDir = fullfile(parameters.InitialDetection.filePath, 'InitialDetections', 'FeatureCalc');
  if ~exist(inputDir, 'dir');
    throw(sprintf('Input directory %s not found.', inputDir));
  end

  % save annotations out to a file so addAnnotations can upload them all at once
  outputDir = fullfile(parameters.InitialDetection.filePath, 'InitialDetections', 'Annotations');
  if ~exist(outputDir, 'dir');
    mkdir(outputDir);
  end

  numParBlocks = parameters.ParallelComputing.maxParallelPools;

  for p = 1: numParBlocks
    inputFile = fullfile(inputDir, sprintf('%s-ID-p%d.txt', animalName, p));
    outputFile = fullfile(outputDir, sprintf('%s-annots-p%d.mat', animalName, p));
    
    try
      fileExist = dir(inputFile);
      if fileExist.bytes > 0
        m = memmapfile(inputFile,'Format','single');
      else
        throw(sprintf('No data found in: %s\n',inputFile));
      end
    catch
      throw(sprintf('File not found: %s\n',inputFile));
    end
    
    data = reshape(m.data, length(channels)+1, [])';

    % find elements of data that are over threshold and convert to
    % start/stop time pairs (in usec)
    annotChannels = [];
    annotUsec = [];
    % end time is one window off b/c of diff - add row of zeros to start
%     [idx, chan] = find([zeros(1,length(parameters.channels)+1); diff((data > parameters.minThresh))]);
    [idx, chan] = find(diff([zeros(1,length(channels)+1); ...
      (data >= minThreshold) .* (data < maxThreshold) ]));
    if sum(chan == 0) > 0
      keyboard;
    end
    
    chan = chan - 1;
    
    i = 1;
    while i <= length(idx)-1
      if (chan(i+1) == chan(i))
        if ( (data(idx(i+1),1) - data(idx(i),1)) >= minDur*1e6  ...
            && (data(idx(i+1),1) - data(idx(i),1)) < maxDur*1e6)
          annotChannels = [annotChannels; chan(i)];
          annotUsec = [ annotUsec; [data(idx(i),1) data(idx(i+1),1)] ];
        end
        i = i + 2;
      else % annotation has a beginning but not an end
        % force the annotation to end at the end of the block
        if ( (curTime + blockSize) - data(idx(i),1) >= minDur*1e6 ) % require min duration?
          annotChannels = [annotChannels; chan(i)];
          annotUsec = [ annotUsec; [data(idx(i),1)  curTime+blockSize] ];
        end
        i = i + 1;
      end
    end
    
    if ~isempty(annotUsec)
      [annotChannels, annotUsec] = combineAnnotations(annotChannels, annotUsec);
    end
    
    % need to upload all annotations in a layer at once, but can't process
    % the whole file at once, so appending them to a file seems like the
    % best way to go. 
    if ~isempty(annotUsec)
      parsave(outputFile, annotChannels, annotUsec); % can't use save in parfor
    end
  end
  
  combinedAnnots = [];
  combinedChannels = [];
  for p = 1:numParBlocks
    outputFile = fullfile(outputDir, sprintf('%s-annots-p%d.mat', animalName, p));
    try
      load(outputFile);
    catch
    end
    
    combinedAnnots = [combinedAnnots; annotUsec];
    combinedChannels = [combinedChannels; annotChannels];
  end
end




function [chans, times] = combineAnnotations(eventChannels, eventTimesUsec)
  % want to combine overlapping annotations for feature analysis.
  % if end time of first row is later than start time of second row,
  % there is an overlap - change end time of both to max end time of both
  % keep running through data until no more changes are found.
%   eventChannels = data(1,:)';
%   eventTimesUsec = data(2:3,:)';

  % want to combine overlapping annotations for feature analysis.
  % if end time of first row is later than start time of second row,
  % there is an overlap - change end time of both to max end time of both
  % keep running through data until no more changes are found.
  [~,idx] = sort(eventTimesUsec(:,1));
  times = eventTimesUsec(idx,:);
  chans = eventChannels(idx);

  somethingChanged = 1;
  while somethingChanged
    somethingChanged = 0;
    i = 2;
    while i <= length(chans)
      if (times(i-1,2) > times(i,1)) && (times(i-1,2) ~= times(i,2))
        times(i-1,2) = max([times(i-1,2) times(i,2)]);
        times(i,2) = max([times(i-1,2) times(i,2)]);
        somethingChanged = 1;
      end
      i = i + 1;
    end
  end

  % if the end times match between rows, change the start times to the
  % earliest start time.  keep running until no more changes found.
  somethingChanged = 1;
  while somethingChanged
    somethingChanged = 0;
    i = 2;
    while i <= length(chans)
      if (times(i,1) > times(i-1,1)) && (times(i-1,2) == times(i,2))
        times(i,1) = times(i-1,1);
        somethingChanged = 1;
      end
      i = i + 1;
    end
  end

  % there might be multiple annotations with same start/stop time on the
  % same channel (from having several annots in same region)
  [~,idx] = sort(chans);
  times = times(idx,:);
  chans = chans(idx);
  i = length(chans);
  while i > 1
    if chans(i) == chans(i-1)
      if int64(times(i,1)) == int64(times(i-1,1)) && int64(times(i,2)) == int64(times(i-1,2))
        chans(i) = [];
        times(i,:) = [];
      end
    end
    i = i - 1;
  end
  
  % run from end to beginning of annotations - if start and end times
  % match, compress into one annotation across multiple channels
  [~,idx] = sort(times(:,1));
  times = times(idx,:);
  chans = num2cell(chans(idx));
  i = length(chans);
  while i > 1
    if int64(times(i,1)) == int64(times(i-1,1)) && int64(times(i,2)) == int64(times(i-1,2))
      chans{i-1} = [chans{i-1} chans{i}];
      chans(i) = [];
      times(i,:) = [];
    end
    i = i - 1;
  end
end




function parsave(fname, annotChannels, annotUsec)
  save(fname, 'annotChannels', 'annotUsec');
end

