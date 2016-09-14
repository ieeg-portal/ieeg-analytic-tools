function dataset = IEEGDemoAnalysis(dataset, channels, threshold)
  % IEEGDEMOANALYSIS  is a method that demonstrate a possible analysis tool
  % for the IEEG-Portal. This tool marks the times that the data within a
  % channel exceeds the mean + n*standard deviation. 
  %
  % DATASET = IEEGDEMOANALYSIS(DATASET, CHANNELIDX, THRESHOLD) creates
  % annotations in an annotationlayer of DATASET where the signal on each
  % channel crosses a threshold defined by the mean of the signal +/-
  % THRESHOLD * the standard deviation of the channel. CHANNELIDX is a
  % numeric vector indicating the indeces of the channels in DATASET that
  % should be included. The length of the analyzed data is set as a
  % constant in this method at 100 seconds.
  %
  % < RUNNING MEAN AND VARIANCE >
  % The mean and variance of the dataset is continuously updated as new
  % data is requested from the portal. The results will therefore stabilize
  % as more data has been fetched from the portal. 
  %
  % < DISCLAIMER >
  % This tool merely serves as a demonstration of the ease of use of the
  % IEEG-Toolbox and the results are not clinically relevant. The
  % implemented method is not described in a peer-reviewed paper. However,
  % the workflow used in this example can be used as a template for other
  % data analysis tools that utilize the IEEG-Toolbox.
  %
  % Author: J.B. Wagenaar
  
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

  BLOCKLENGTH = 5;   % Length of single block in seconds
  NBLOCKS = 10;     % Number of Blocks to process
  
  isInit = true;
  sf = dataset.rawChannels(1).sampleRate;
  
  % Create new annotation layer, or use existing layer.
  layerName = sprintf('IEEGDemoAnalysis_%0.3f', threshold);
  allLayers = {dataset.annLayer.name};
  foundLayer = find(strcmp(layerName,allLayers),1);
  if isempty(foundLayer)
    curLayer = dataset.addAnnLayer(layerName);
  else
    curLayer = dataset.annLayer(foundLayer);
  end
    
  for i = 0: (NBLOCKS-1)
    startTime = 1e6 * i*BLOCKLENGTH;
    curData = dataset.getvalues(startTime, 1e6*BLOCKLENGTH, channels);
    annotations = detectEvents(curData, startTime, sf, threshold, ...
      dataset.rawChannels(channels), isInit);
    
    if ~isempty(annotations)
      curLayer.add(annotations);    
    end
    
    isInit = false;
    
  end

end

function annotations = detectEvents(values, startTime, sf, threshold, ...
  channels ,init)
  % DETECTEVENTS iterates over channels and creates annotations at when the
  % values exceed the mean + Threshold*Standard deviation of the data for
  % that channel. 
  
  persistent pendingIdx
  MINDISTANCE = 0.075;   % Minumum distance between annotations in sec. 
  
  %If single channel make sure it is a column vector.
  if isvector(values); values = values(:); end 
  
  %Reset pendingIdx persistent variable on init.
  if init
    pendingIdx = zeros(size(values,2),1);
  end

  % Find indeces that cross Mean + threshold*StandardDev
  [runMean, runVar] = runningVariance(values, init);  
  thrVector = (runMean + (threshold * sqrt(runVar)));

  annotations = IEEGAnnotation.empty;
  for iChan =1 :size(values,2)
    
    % -- Find Threshold locations --
    aboveThres = abs(values(:,iChan)) > thrVector(iChan);
    ThresCross = find(diff(aboveThres));

    
    % -- Making sure first transition is positive --
    if aboveThres(1) == true;
      if init
        ThresCross = ThresCross(2:end);
      else
        ThresCross = [pendingIdx(iChan); ThresCross]; %#ok<AGROW>
      end
    else
      if pendingIdx(iChan) ~=0
        ThresCross = [pendingIdx(iChan);1 ; ThresCross]; %#ok<AGROW>
        pendingIdx(iChan) = 0;
      end
    end
    
    
    % -- If uneven number items, populate pending vector --
    lThr = length(ThresCross);
    if mod(lThr,2) && lThr > 1
      % Check that last value is larger than threshold. Sanity check...
      assert(aboveThres(end)==1,'Expecting positive last value');
      
      % Find start of pending annotation, take into account the minimum
      % separation between annotations.
      minSep = upper(MINDISTANCE * sf);
      ixx    = length(ThresCross);
      curSep = ThresCross(ixx) - ThresCross(ixx-1);
      while curSep < minSep && ixx >=4
        ixx = ixx - 2;
        curSep = ThresCross(ixx) - ThresCross(ixx-1);
      end
      
      % Adding New Start index to pending vector and removing remainder
      % from ThressCross vector.
      pendingIdx(iChan) = -1 * (size(values,1) - ThresCross(ixx));
      ThresCross = ThresCross(1:ixx-1);
    elseif mod(lThr,2)
      
      % Check that last value is larger than threshold. Sanity check...
      assert(aboveThres(end)==1,'Expecting positive last value');
      ThresCross = ThresCross(1:end-1);
      
    end
    
    
    % -- Create the annotation objects --
    if ~isempty(ThresCross)
      annStartIndeces = ThresCross(1:2:end);
      annStopIndeces = ThresCross(2:2:end);
      
      % Combine Events that are separated less than 0.05 sec.
      diffStartTime = (annStartIndeces(2:end)-annStopIndeces(1:end-1))./sf;
      smallTimeDiff = find(diffStartTime < MINDISTANCE);
      annStartIndeces(smallTimeDiff+1) = [];
      annStopIndeces(smallTimeDiff) = [];
      
      display(sprintf('Creating %03i annotations on channel %02i',...
        length(annStartIndeces), iChan));

      % Create new annotations
      annStartTimes = startTime + (annStartIndeces-1)*(1e6/sf);
      annStopTimes = startTime + (annStopIndeces-1)*(1e6/sf);
      annotations = [annotations IEEGAnnotation.createAnnotations(...
        annStartTimes, annStopTimes,'Event', channels(iChan))]; %#ok<AGROW>
    
    end
  end
    
end

function [runMean, runVar] = runningVariance(newData, init)
  % Method updates the mean and variance when new data is presented. This
  % method works on multiple channels when channels are presented as
  % columns.
  %
  % NEWDATA is a nxm array of datapoints with n equals the number of
  % timepoints and m equals the number of channels. INIT is a boolean
  % indicating whether the NEWDATA values are the first values obtained.
  % This resets the running mean and variance.
  %
  % NANs are omitted from the calculations.
  %
  % runMean and runVar are vectors with length equal to the number of
  % columns in newData.

  persistent n data_mean data_var

  % Check inputs.
  if init
    newData = newData(~any(isnan(newData')),:);
    n = length(newData);
    data_mean = mean(newData);
    data_var = var(newData);
    
    runMean = data_mean;
    runVar = data_var;
    return
  elseif isempty(n)
    error('First call to method must have ''init'' parameter TRUE');
  else
    assert(length(data_mean)==size(newData,2),...
      'Number of Columns in NEWDATA is not the same as previous iterations.')
  end
  
  % Remove any NANs
  newData = newData(~any(isnan(newData')),:);
  lData = size(newData, 1);
  
  % Update mean and variance.
  if lData
    new_data_mean = ...
      (n*data_mean + lData*mean(newData))./(n+lData);
    new_data_var = ...
      ((n-1).*data_var + n.*(data_mean.^2) + sum(newData.^2) - ...
      (n+lData) .* (new_data_mean.^2))./(n+lData-1);
    
    
    data_mean = new_data_mean;
    data_var = new_data_var;
    n = n + lData;
  end
  
  runMean = data_mean;
  runVar = data_var;

  
end