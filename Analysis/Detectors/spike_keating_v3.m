function [spikeData padLength] = spike_keating_v3(data, rate, startT, init, SPKDURATION, ABSTHRESH, AFTDUR)
  %SPIKER_V3  Updated spike detection algorithm
  
  % SPKDURATION =  in ms (spike duration  less than this ##)
  % ABSTHRESH = absolute threshold (uV) min spike size ##  
  % AFTDUR = in ms (after hyperpolarization wave must be longer than this)
 
  % OUT = SPIKER_V2(DATA, RATE, STARTT, INIT) returns a nx2 array of spiketimes
  % and spike amplitudes. The returned times are in seconds and the amplitudes
  % are based on the filtered amplitudes.
  %
  % [OUT PADLENGTH] = SPIKER(...) also returns the length of the padding that is
  % used for the filters. This value is the length of data that is stripped from
  % the beginning and end when INIT is true and the length that is stripped from
  % the end and added to the beginning (from previous call) when INIT is false.
  %
  % DATA should be a vector of values representing the recorded signal. The RATE
  % should be the sampling rate (i.e. 400 Hz), STARTT is the timestamp of the
  % 1st index of the DATA vector in seconds and INIT is a boolean that indicates
  % whether the filter buffers should be flushed. This is required for the first
  % time the method is called and should be set whenever the data is not
  % continuous.
  %
  % To eliminate filter artifacts on subsequent calls of the method, a
  % predetermined length of data is stored temporarily inside this method and
  % used as padding before the data in the following call. The length of the
  % padding ('npad') is determined by the sampling rate and the filter settings
  % using an approximate of the impulse response and finding the length after
  % which additional contribution are less then 0.0001 * the input.
  %
  % Because of the padding, the first and last 'npad' samples are not analyzed
  % when the INIT input is set to TRUE and the last 'npad' samples are not
  % analyzed in any scenario.

  % Author: J.B.Wagenaar
  % This file was modified from the original spiker.m file which was based on
  % methods developed by Jeff Keating. I did not change any of the parameter
  % values and modified the code only to the extend that it is more efficient
  % and that it can be used on large datasets using multiple calls.
  
  % small modifications by Hoameng Ung 5/2014
  
  persistent B1 A1 B2 A2 padding leftpad thresMap thresMapIdx

  if nargin == 3
    init = false;
  elseif init
    B1 = [];
  end
  
  data = double(data);
  
  % Filter settings
  FILTER_ORDER  = 12; % order is final order, after filtfilt --> see filter init
  DHF = 2;            % Default High Pass filter.
  HFR = 20;           % high pass freq ##1000
  LFR = 7;            % low pass freq   ##50
  
  % Set SpikeDuration in miliseconds. Use
  % SPKDURATION = 200; % in ms spike duration  less than this ##
  spkdur      = SPKDURATION*rate/1000; %convert from time to number of points
  
  % Set the spike threshold parameters
  TMULT    = 2;                % threshold multiplier ##   
  THRESHIST = 10;               % Number of block in threshold history;
%   ABSTHRESH = 250;            % absolute threshold (uV) min spike size ##      

  % Set minimum hyperpolarization time in ms
  % AFTDUR    = 200;  %in ms after hyperpolarization wave must be longer than this ##
  aftdur    = AFTDUR*rate/1000; %convert from time to number of points         
  
  % Create filter on first call; when init is set to true
  if isempty(B1)
    assert(init, 'Empty persistent variables requires input INIT to be true.');
    assert(mod(FILTER_ORDER,4)==0, 'Filter order must be multiple of 4.');
    % This generates a bandpass filter of order FILTER_ORDER. FILTER_ORDER is
    % divided by 4 because the butter method creates a 2*N order filter and the
    % filtfilt method also dubbles the order.
    halfRate = rate/2;
    [B1, A1] = butter(FILTER_ORDER/4, [DHF/halfRate HFR/halfRate]);
    [B2, A2] = butter(FILTER_ORDER/4, [DHF/halfRate LFR/halfRate]);

    % find necessary padding
    test = zeros(10000,1);
    test(1) = 1;
    testOut = filter(B1, A1, test);
    padding1 = find(abs(testOut)>0.0001,1,'last');    
    testOut2 = filter(B2, A2, test);
    padding2 = find(abs(testOut2)>0.0001,1,'last');
    %padding = max([padding1 padding2])
    padding=150;
    
    % Rearrange input arguments for init.
    leftpad = data(1 : padding);
    data = data(padding+1: end);
    
    % Set thresholdhistory matrix
    thresMap = zeros(THRESHIST,2);
    thresMap(1,:) = [mean(abs(leftpad)) length(leftpad)];
    thresMapIdx = 2;
  end
  
  % Define padlength output
  padLength = padding;
  
  thresMap(thresMapIdx,:) = [mean(abs(data)) length(data)];
  thresMapIdx = thresMapIdx + 1;
  if thresMapIdx > THRESHIST; thresMapIdx = 1; end;  
  
  % Derive threshold parameters.
  
  %Lthres is weighted average of previous inputs.
  lthresh = sum(prod(thresMap,2))/sum(thresMap(:,2));  
  sthresh = lthresh*TMULT/3;    % this is the first run threshold 
  thresh  = lthresh*TMULT;      % this is the final threshold we want to impose  
  
  % Filter Data using zero-phase butterworth filter.
  data = [leftpad ;  data];
  data2 = data;
  ldata = length(data);
    
  % Get new LeftPad
  leftpad = data((ldata - 2*padding +1): ldata);

  data = filter(B1,A1, data);
  data(ldata:-1:1) = filter(B1, A1, data(ldata:-1:1));
  data = data(padding + 1: ldata - padding); 
  
  data2 = filter(B2,A2, data2);
  data2(ldata:-1:1) = filter(B2, A2, data2(ldata:-1:1));
  data2 = data2(padding + 1: ldata - padding); 
  
  if init
    startTime = startT + (1/rate)*padding;
  else
    startTime = startT - (1/rate)*padding; 
  end
  % -- end filter --

  if sum(data) == 0
     spikeData = [];
    return
  end
  
  % Find all Peaks and Valleys
  [spp, spv] = FindThePeaks(data);
    
  if isempty(spp)
    spikeData = [];
    return
  end
  
  % Check if start with peak or valley.
  isFirstValley = double(spp(1) > spv(1));
  
  idx = diff(spp) <= spkdur;       %is the # of samples between two peaks less than spkdur
  if idx(end); idx(end)= false;end %Remove possible last peak.
  startdx = spp(idx);              %the first peak in a close pair  (vector of all pairs)
  startdx1= spp([false ;idx(1:end-1)]); %the second peak in a close pair    
  
  if isFirstValley
    idx2 = [false ;idx(1:end-1)];
  else
    idx2 = idx;
  end
  
  sstartdx = spv(idx2);
  
  spikes = zeros(length(startdx),5);
  for i = 1:(length(startdx) - isFirstValley)
    % find the valley that is between the two peaks
    
    % Add 1 offset if the dataset starts with valley. 
    curValley = sstartdx(i);
        
    assert(startdx(i) < curValley,'Spike Valley Error.');
    
    if data(startdx(i)) - data(curValley) > lthresh && ...
        data(startdx1(i)) - data(curValley) > sthresh 
      spikes(i,1) =  sstartdx(i);                                % add timestamp to the spike list
      spikes(i,2) = (startdx1(i)-startdx(i))*1000/rate;        % add spike duration to list
      spikes(i,3) = data(startdx1(i)) - data( curValley);    % add spike amplitude to list
    end
  end        
  
  % Remove non-spikes
  spikes(~spikes(:,1),:) = []; 
  
  % Now find low frequency spikes
  [hyperp, hyperv] = FindThePeaks(data2);
  isFirstValley = double(hyperp(1) > hyperv(1));
  
  olda = 0;
  dellist = false(length(spikes), 1);  
  for i = 1 : size(spikes,1)
    
    % Find first two slowWaves after spike
    findex = find(hyperp > spikes(i,1), 2);
    a = hyperp(findex); 
    try 
      if ( (a(2) - a(1)) < aftdur) %too short duration
        dellist(i) = true;
      else
        spikes(i,4) = (a(2)-a(1)) * 1000/rate;    %amp of slow wave
        
        b = hyperv(findex(1) + isFirstValley);
        
        spikes(i,5) = data2(a(1)) - data2(b); %valley
        if a(1) == olda
          dellist(i-1) = true;
        end
      end
      olda = a(1);

    catch ME %#ok<NASGU>
      dellist(i)=true;
    end
    
  end   
  spikes(dellist,:)=[];
  
  % Check the amplitude of the spikes.
  spikeData = zeros(size(spikes,1),2);
  ix = 0;
  for i = 1:size(spikes,1)
    chk1 = sum(spikes(i, [3 5])) > thresh;
    chk2 = sum(spikes(i, [3 5])) > ABSTHRESH;           % add EKG rejection threshold as 4th number input
    if chk1 && chk2
      if spikes(i,2)>20   
        ix = ix+1;
        if init
          spikeData(ix, 1) = (startTime - 1/rate) + (1/rate)*(spikes(i,1) );
        else
          spikeData(ix, 1) = (startTime - 1/rate) + (1/rate)*(spikes(i,1) );
        end
        spikeData(ix, 2) = spikes(i,3);
      end
    end
  end
  spikeData = spikeData(1:ix,:);
  
end

function [p, t] = FindThePeaks(s)
  % Result of this function is that a peak is always followed by a valley.

  ds = diff(s);
  
  % Make sure that 1st value of array is not equal to zero.
  if ds(1) == 0
    aux = find(ds~=0,1);
    ds(1:aux) = ds(aux);
  end
  
  ds = [ds(1); ds];
  
  % Replacing ds that are zero with previous value. Changed from original code
  % to work when two or more values in a row are zero.
  while ~all(ds~=0)
    aux = ds==0;
    ds(aux) = ds([aux(2:end); true]);
  end

  ds = sign(ds);
  ds = diff(ds);
  t = find(ds > 0);
  p = find(ds < 0);
end 
