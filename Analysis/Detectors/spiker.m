% The methods below are performig the actual analysis on a single channel of
% EEG. The code was mostly unaltered from its original form except for a few
% matlab syntax fixes.
function spikedata = spiker(eegdata, datarate, start_t, end_t) 
  %SPIKER  Main portion taken from keating1.m
  
  %setup
  tmul      = 3;    % threshold multiplier ##    
  absthresh = 300;  % absolute threshold (uV) min spike size ##      
  fr        = 30;   % high pass freq ##1000
  lfr       = 5;    % low pass freq   ##50
  spkdur    = 0.200;  % in sec spike duration  less than this ##
  spkdur    = spkdur*datarate; %convert from time to number of points
  aftdur    = 0.1;   %in sec after hyperpolarization wave must be longer than this ##
  aftdur    = aftdur*datarate;  %convert from time to number of points         
  lthresh = mean(abs(eegdata));  % this is the smallest the initial part of the spike can be       
  thresh = lthresh*tmul;      % this is the final threshold we want to impose       
  sthresh = lthresh*tmul/3;   % this is the first run threshold 
  allout=[];
  spikes = [];

  %datarate in Hz, times in us.  in ms, it would be
  %start:1/datarate:end - 1/datarate;
  t = start_t:1/datarate:end_t;        
  assert(length(t) == length(eegdata), 'T and Data are not the same length.');
  fndata=butterfilt(eegdata, 2, 'hp', datarate);  %% changed to lfr instead of 1-- check theory
  HFdata=butterfilt(fndata, fr, 'lp', datarate);
  [spp, spv] = FindThePeaks(HFdata); %peaks and troughs of the data set
  %spp spv are vectors of indices

  idx=find(diff(spp) <=spkdur);  %is the # of samples between two peaks less than spkdur
  startdx = spp(idx);            %the first peak in a close pair  (vector of all pairs)
  startdx1= spp(idx+1);          %the second peak in a close pair        
  for i = 1:length(startdx)
    spkmintic = spv(spv > startdx(i) & spv < startdx1(i));  % find the valley that is between the two peaks

    if HFdata(startdx1(i)) - HFdata(spkmintic) > sthresh & HFdata(startdx(i)) - HFdata(spkmintic) > lthresh  %#ok<AND2> % see if the peaks are big enough
      spikes(end+1,1) = spkmintic;                                 % add timestamp to the spike list
      spikes(end,2) =  (startdx1(i)-startdx(i))*1000/datarate;        % add spike duration to list
      spikes(end,3) = HFdata(startdx1(i)) - HFdata(spkmintic);    % add spike amplitude to list
    end
  end        
  spikes(:,4)=0;
  spikes(:,5)=0;
  dellist=[];   

  LFdata=butterfilt(fndata,lfr, 'lp', datarate);
  [hyperp, hyperv]=FindThePeaks(LFdata);
  olda=0;

  for i=1:size(spikes,1)
    a=hyperp(hyperp > spikes(i,1)); %num times the slow wave  peaks following the spike
    try %catch waves at end of data
      if ((a(2)-a(1)) < aftdur) %too short duration
        dellist(end+1)=i;  %delete from list
      else
        spikes(i,4)=(a(2)-a(1))*1000/datarate; %#ok<*AGROW> %amp of slow wave
        b=hyperv(hyperv>a(1) & hyperv<a(2)); %add duration of afhp
        spikes(i,5)= LFdata(a(1))-LFdata(b);%valley
        if a(1)==olda
          dellist(end+1)=i-1;
        end
      end
      olda=a(1);

    catch %#ok<CTCH>
      dellist(end+1)=i;
    end
  end        
  spikes(dellist,:)=[];
  toosmall=[];
  toosharp=[];

  for i=1:size(spikes,1); %for each spike
    if (((sum(spikes(i, [3 5])))> thresh) && (sum(spikes(i, [3 5]))> absthresh))
      if spikes(i,2)>20                            
        allout(end+1,1) = t(spikes(i,1));  %the time at the index in spikes(i,1)
        allout(end,2) = spikes(i,3);
      else
        toosharp(end+1)=spikes(i,1);
      end
    else 
      toosmall(end+1)=spikes(i,1);
    end
  end

  spikedata=allout;
end            

function [p,t]=FindThePeaks(s)
  warning off %#ok<WNOFF>
  ds = diff(s);
  ds = [ds(1); ds];%pad diff
  filter = find(ds(2:end)==0)+1;%%find index of diffs that are zeros
  ds(filter) = ds(filter-1);%%replace zeros
  ds = sign(ds);
  ds = diff(ds);
  t = find(ds>0);
  p = find(ds<0);
end 

function out = butterfilt(x,fc,type, fs)
  %EEG_BUTTER - Butterworth filter implementation
  %  xf = eeg_butter(x,sampl_freq,cutoff_freq,filter_type,num_poles)
  % global eeghdr
  % if ~exist('fs')
  % fs = eeghdr.rate;
  % end
  sprintf('Values: fc: %d fs %d', fc, fs);

  np = 6;  %this will make a 6th order butterworth filter
  if sum(fc >= fs/2), error('Cutoff frequency must be < one half the sampling rate'); end
  fn = fs/2;
  type = type(1:2);
  if strcmp(type,'bp'), type = 'lp'; end

  switch type,
  case 'lp',
    [B,A] = butter(np,fc/fn);
  case 'hp',
    [B,A] = butter(np,fc/fn,'high');
  case 'st'
    [B,A] = butter(np,fc/fn,'stop'); %% second value should be a vector
  end
  out = filtfilt(B,A,x);
end 
