function InitialDetectionss(dataset, parameters, dataRow)
  %	Usage: f_InitialDetections(dataset, parameters, dataRow);
  % Should be called by analyzeDataOnPortal.m
  %	
  %	f_InitialDetections() will call f_initial_XXXX to perform event detection by
  % calculating a simple feature using a sliding window and then looking for
  % places where the feature crosses a threshold for a minimum amount of time
  %
  % XXXX = parameters.feature, something like 'linelength'
  % 
  % Note that f_InitialDetectionss() contains supporting code for plotting and
  % saving data, while f_initial_XXXX does the actual sliding window and
  % feature calculation.  The idea is that f_initial_XXXX can be hacked
  % together while f_InitialDetectionss() supports the feature development.
  % You can start and end at specific times in the file, this helps tune the
  % detector by finding sample detections and then seeing what a given
  % threshold/window duration will find.
  %
  % Input:
  %   dataset - single IEEG dataset
  %   parameters		-	a structure containing at least the following:
  %     parameters.startTime = '1:00:00:00'; % day:hour:minute:second, in portal time
  %     parameters.endTime = '1:01:00:00';   % day:hour:minute:second, in portal time
  %     parameters.minThresh = 2e2;       % minimum threshold for initial event detection
  %     parameters.minDur = 10;           % sec; minimum duration for detections
  %     parameters.viewInitialDetectionsPlot = 1;  % view plot of feature overlaid on signal, 0/1
  %     parameters.function = @(x) (sum(abs(diff(x)))); % feature function
  %     parameters.windowLength = 2;         % sec, duration of sliding window
  %     parameters.windowDisplacement = 1;    % sec, amount to slide window
  %     parameters.blockDurMinutes = 15;      % minutes; amount of data to pull at once
  %     parameters.smoothDur = 20;   % sec; width of smoothing window
  %     parameters.maxThresh = parameters.minThresh*4;  
  %     parameters.maxDur = 120;    % sec; min duration of the seizures
  %     parameters.plotWidth = 1; % minutes, if plotting, how wide should the plot be?
  %   datarow - row from dataKey table corresponding to this dataset
  %
  % Output:
  %   to portal -> detections uploaded to portal as a layer called 'initial-XXXX'
  %   to file -> eg 'I023_A0001_D001-annot-initial-XXXX.txt - start/stop times of annots
  %
  % Jason Moyer 7/20/2015 
  % University of Pennsylvania Center for Neuroengineering and Therapeutics
  %
  % History:
  % 7/20/2015 - v1 - creation
  %.............

%   dbstop in InitialDetectionss at 77;
  
  % user specifies start/end time for analysis (in portal time), in form day:hour:minute:second
  % convert these times to usecs from start of file
  % remember that time 0 usec = 01:00:00:00
  timeValue = sscanf(parameters.InitialDetections.startTime,'%d:');
  startUsecs = ((timeValue(1)-1)*24*60*60 + timeValue(2)*60*60 + ...
    timeValue(3)*60 + timeValue(4))*1e6; 
  if startUsecs <= 0  % day = 0 or 1:00:00:00
    startUsecs = round((datenum(dataRow.Start_EEG, 'dd-mmm-yyyy HH:MM:SS') - ...
      datenum(dataRow.Start_System, 'dd-mmm-yyyy HH:MM:SS'))*24*60*60*1e6);
  end
  durationHrs = parameters.InitialDetections.hoursToAnalyze;
  endUsecs = startUsecs + durationHrs * 3600 * 1e6; 
  % save time by only analyzing data that is relevant
  if endUsecs <= 0 || endUsecs > dataset.rawChannels(1).get_tsdetails().getDuration || endUsecs == startUsecs
    endUsecs = round((datenum(dataRow.End_EEG, 'dd-mmm-yyyy HH:MM:SS') - ...
      datenum(dataRow.Start_System, 'dd-mmm-yyyy HH:MM:SS'))*24*60*60*1e6);
  end
  
  animalName = char(dataset.snapName);
  userName = parameters.IEEGInfo.userName;
  credentialsFile = parameters.IEEGInfo.credentialsFile;
  toolboxPath = parameters.IEEGInfo.toolboxPath;
  channels = parameters.DatasetInfo.channelsToRun;
  featureFnName = parameters.InitialDetections.featureFnName;
  minThreshold = parameters.InitialDetections.minThreshold;
  fs = dataset.sampleRate;
  
  % calculate number of blocks = # of times to pull data from portal
  durationHrs = (endUsecs - startUsecs)/1e6/60/60;    % duration in hrs
  numBlocks = ceil(durationHrs/(parameters.InitialDetections.blockDurMinutes/60));    % number of data blocks
  blockSize = parameters.InitialDetections.blockDurMinutes * 60 * 1e6;        % size of block in usecs

  % save annotations out to a file so addAnnotations can upload them all at once
  outputDir = fullfile(parameters.InitialDetections.filePath, 'InitialDetectionss', 'FeatureCalc');
  if ~exist(outputDir, 'dir');
    mkdir(outputDir);
  end

  numParBlocks = parameters.ParallelComputing.maxParallelPools;
  
  % break each animal into X blocks and process blocks in parallel
  parfor p = 1: numParBlocks
%   parfor p = 1: numParBlocks
    % for each block (block size is set by user in parameters)
    outputFile = fullfile(outputDir, sprintf('%s-ID-p%d.txt', animalName, p));
    ftxt = fopen(outputFile, 'w');
    assert(ftxt > 0, 'Unable to open text file for writing: %s\n', outputFile);
    fclose(ftxt);  % this flushes the file

    blockVec = 1:numBlocks;
    blockBreaks = [(1: ceil(numBlocks/numParBlocks): numBlocks) numBlocks+1];
    try
      runTheseBlocks = blockVec(blockBreaks(p):(blockBreaks(p+1)-1));
    catch
      runTheseBlocks = blockVec;
    end

    session = IEEGSession(animalName, userName, credentialsFile);
    
    for b = runTheseBlocks
      curTime = startUsecs + (b-1)*blockSize;

      % get data - sometimes it takes a few tries for portal to respond
      count = 0;
      successful = 0;
      while count < 10 && ~successful
        try
          data = session.data(1).getvalues(curTime, blockSize, channels);
          successful = 1;
        catch
          count = count + 1;
          fprintf('Try #: %d\n', count);
        end
      end
      if ~successful
        error('Unable to get data.');
      end

      fprintf('Proc #%d. %s: Processing data block %d of %d\n', p, char(session.data(1).snapName), b, numBlocks);

      %%-----------------------------------------
      %%---  custom feature creation and data processing
      fhandle = str2func(featureFnName);
      output = fhandle(data, fs, channels, curTime);
      %%---  custom feature creation and data processing
      %%-----------------------------------------

      % optional - plot data, width of plot set by user in parameters
%       if parameters.InitialDetections.viewPlot
%         if parameters.ParallelComputing.maxParallelPools == 1
%           plotWidth = parameters.InitialDetections.plotWidthMinutes*60*1e6; % usecs to plot at a time
%           numPlots = blockSize/plotWidth;
%           time = 1: length(data);
%           time = time/fs*1e6 + curTime;
% 
%           i = 1;
%           while (i <= numPlots)
%             % remember portal time 0 = 01:00:00:00
%             day = floor(output(1,1)/1e6/60/60/24) + 1;
%             leftTime = output(1,1) - (day-1)*24*60*60*1e6;
%             hour = floor(leftTime/1e6/60/60);
%             leftTime = (day-1)*24*60*60*1e6 + hour*60*60*1e6;
%             startPlot = (i-1) * plotWidth + curTime;
%             endPlot = min([startPlot + plotWidth   time(end)]);
%             dataIdx = find(startPlot <= time & time <= endPlot);
%             ftIdx = find(startPlot <= output(:,1) & output(:,1) <= endPlot);
%             for c = 1: length(parameters.DatasetInfo.channelsToRun)
%               figure(1); subplot(2,2,c); hold on;
%               plot((time(dataIdx)-leftTime)/1e6/60, ...
%                 data(dataIdx,c)/max(data(dataIdx,c)), 'Color', [0.5 0.5 0.5]);
%               plot((output(ftIdx,1)-leftTime)/1e6/60, ...
%                 output(ftIdx,c+1)/max(output(ftIdx,c+1)),'k');
%               axis tight;
%               xlabel(sprintf('(minutes) Day %d, Hour %d',day,hour));
%               title(sprintf('Channel %d',c));
%               line([(startPlot-leftTime)/1e6/60 (endPlot-leftTime)/1e6/60],...
%                 [parameters.InitialDetections.default.minThreshold/max(output(ftIdx,c+1)) ...
%                 parameters.InitialDetections.default.minThreshold/max(output(ftIdx,c+1))],'Color','r');
%               line([(startPlot-leftTime)/1e6/60 ...
%                 (endPlot-leftTime)/1e6/60],[parameters.maxThresh/max(output(ftIdx,c+1)) ...
%                 parameters.maxThresh/max(output(ftIdx,c+1))],'Color','b');
%               hold off;
%             end
% 
%             i = i + 1;
%             pause;      % pause to view plot
%     %        keyboard    % type return in command window to keep going, dbquit to stop
%             clf;        % can change keyboard to pause to move more quickly
%           end
%         else
%           fprintf('parameters.InitialDetections.viewPlot is set to 1 but maxParallelPools > 1.  To view plot, set maxParallelPools to 1.\n');
%         end
%       end
      
      ftxt = fopen(outputFile, 'a');
      assert(ftxt > 0, 'Unable to open text file for appending: %s\n', outputFile);
      fwrite(ftxt, output', 'single');
      fclose(ftxt);  % this flushes the file
    end
  end
end

