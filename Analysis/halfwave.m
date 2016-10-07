function [outArr] = halfwave(signal,fs,startTime)
% HALFWAVE : This function extracts valid half waves from EEG signal and
% stores them in outArr
% Function call: [outArr] = halfwave(signal,fs,startTime)
% INPUT:
% signal: raw data, each column is a channel
% fs: sampling frequency of raw data
% startTime: starting time of raw data
% OUTPUT:
% outArr: consists of four columns
% [PeakTime WaveAmp WaveDur Channel]
% PeakTime: Time of one of the extremas of the halfwave
% WaveAmp: Half Wave Amplitude
% WaveDur: Half Wave Duration
% Channel: Channel on which half wave occurs


    
    DurThresh = 25e-3*fs;
    HYST = 100;  % in-built hysteresis
    cellOut = cell(size(signal,2),1);
    
    for iChan = 1:size(signal,2)
        WaveAmp = zeros(size(signal,1),1);
        WaveDur = zeros(size(signal,1),1);
        allpeaks = zeros(size(signal,1),1);

        % Parameters
        FirstSample = find(~isnan(signal(:,iChan)),1,'first');
        cursign = sign(signal(FirstSample+1,iChan)- signal(FirstSample,iChan));
        EndThresh = signal(FirstSample,iChan)-1*cursign*HYST;
        AmpThreshsig = 2*nanstd(abs(signal(:,iChan)))+nanmean(abs(signal(:,iChan)));
        %AmpThresh = 200;
        AmpThresh = 0;
        Peak = FirstSample; % First sample is start point
        LastPeak = Peak;
        
        for samp = FirstSample+1:size(signal,1)
            if sign(signal(samp,iChan)- signal(Peak,iChan)) == cursign
                % If signal is in the same direction
                EndThresh = signal(samp,iChan) + -1*cursign*HYST;
                Peak = samp;
            elseif (cursign == 1 && signal(samp,iChan) < EndThresh) || ...
                   (cursign == -1 && signal(samp,iChan) > EndThresh)
                % If signal went in opposite direction, has it passed the
                % threshold
                Dur = Peak - LastPeak;
                Amp =  signal(Peak,iChan) - signal(LastPeak,iChan);
                if abs(Amp) > AmpThresh && Dur > DurThresh
                    allpeaks(samp,1) = Peak;
                    WaveDur(samp,1) = Dur;
                    WaveAmp(samp,1) = Amp;
                end
                LastPeak = Peak;
                Peak = samp;
                cursign = cursign*-1;
                EndThresh = signal(samp,iChan) + -1*cursign*HYST;
            end
        end
        
        WaveAmp(WaveAmp==0) = [];WaveDur(WaveDur==0) = [];allpeaks(allpeaks==0) = [];
        PeakTime = startTime + allpeaks*(1./fs)*1e6;
        
        cellOut{iChan} = vertcat(cellOut{iChan},...
            [PeakTime WaveAmp WaveDur iChan*ones(length(allpeaks),1)]);
    end
    cellLen = cellfun(@(x) size(x,1), cellOut);
    cCell = [0 ; cumsum(cellLen)];
    outArr = zeros(sum(cellLen),size(cellOut{1},2));
    for i = 1: length(cellLen)
        outArr((cCell(i)+1):cCell(i+1), :) = cellOut{i}; 
    end
end