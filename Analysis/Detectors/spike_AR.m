function [eventTimesUSec, eventChannels] = spike_AR(dataset,channels,mult)

%   USAGE: [eventTimesUSEc eventChannels] = spike_AR(dataset, channels,mult)
% 
%   This function will detect spikes in channels of a given dataset, and upload to layerName annotation layer on the portal.
%   Each spike occurrence will be returned in an array of times eventTimesUSec (in microsecs) and eventChannels (idx)
%   The algorithm is based off of Acir 2004 and is as follows:
%	1. Bandpass filter data 1-70 Hz
%	2. Model with autoregressive model of order 5 with Burg's lattice-based method
%	3. Square residuals and apply amplitude threshold (mult*stddev of squared residual) to detect spikes
%	4. Cluster to remove spike-like nonspikes (to be implemented)
%
%   INPUT:
%   'dataset'   -   IEEGDataset object
%   'channels'  -   [Nx1] array of channel indices
%   'mult'      -   integer to multiply by standard deviation for threshold

%   OUTPUT:
%   'eventTimesUSec'    -   times of events in microsecds
%   'eventChannels'     -   corresponding channels for each event
%
%   See also: uploadAnnotations.m
%
%   History:
%   8/22/2014:  commented code more thoroughly: Hoameng Ung

%initialize
close all;
plotGraphs=0; %set to 1 to show plots: if running batch, set to 0
numChannels = numel(dataset.channels);
eventTimesUSec = [];
eventChannels = [];
fs = dataset.sampleRate;
numPoints = (dataset.channels(1).get_tsdetails.getDuration/1e6-10) * fs; %remove last 10 secs
blockLenSecs = 3600*2; %process 7200 secs (2 hr) at a time
blockLenPts = round(blockLenSecs * fs);
numBlocks = ceil(numPoints/blockLenPts);
warning('off');

%operate on each channel
reverseStr = '';
fprintf('Running spike_AR on %s: ',dataset.snapName);
totalIter = numel(channels)*numBlocks;
iter = 0;
for i = channels
    %split into blocks and load 1 hr at a time
    for b = 1:numBlocks
        iter = iter + 1;
        percentDone = iter/totalIter*100;
        msg = sprintf('Processed: %3.1f%%%%', percentDone);
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg)-1);
        
        
        startPt = (b-1)*blockLenPts + 1;
        endPt = min(b*blockLenPts,numPoints);
        data = dataset.getvalues(startPt:endPt,i);
        d1 = data;
        if sum(isnan(d1))/numel(data) < 0.25 %is less than 25% of window is missing, then run, else skip
            d1(isnan(d1)) = 0;

            %Lowpass filter - [1 70 Hz]
            ord = 4;
            try
                [b, a] = butter(ord,[70/(fs/2)],'low');
                d1 = filtfilt(b,a,d1);
            catch
                try
                   [b, a] = butter(ord,[55/(fs/2)],'low');
                   d1 = filtfilt(b,a,d1);
                catch
                end

            end
            [b, a] = butter(ord,[1/(fs/2)],'high');
            d1 = filtfilt(b,a,d1);



            %Code below will plot data and filtered data to check for manual
            %integrity. Uncomment to check.
        % 
            %% plot data and filtered
            if plotGraphs == 1
                figure(1)
                subplot(2,1,1);
                plot(data);
                title('original');

                figure(2)
                subplot(2,1,1)
                L = length(data);
                NFFT = length(data);%2^nextpow2(L);
                Y = fft(data,NFFT)/L;
                F = ((0:1/NFFT:1-1/NFFT)*fs).';
                plot(F(1:NFFT/2+1),2*abs(Y(1:NFFT/2+1)))
                title('fft - original');
                xlabel('freq (Hz)')

                figure(1)
                subplot(2,1,2);
                plot(d1);
                title('butterworth filtered');

                figure(2)
                data = d1;
                subplot(2,1,2)
                L = length(data);
                NFFT = length(data);%2^nextpow2(L);
                Y = fft(data,NFFT)/L;
                F = ((0:1/NFFT:1-1/NFFT)*fs).';
                plot(F(1:NFFT/2+1),2*abs(Y(1:NFFT/2+1)))
                title('fft - butterworth filtered');
                xlabel('freq (Hz')

                figure(1)
                linkaxes
            end

            %% Autoregressive modeling

            %to find optimal order, AIC and min mse can be used.
            %time consuming, but good to visualize. order should 
            %ideally be in the "elbow" of the graph
            % data = d1;
            % %fit and plot
            % order = 1:20;
            % armse= zeros(numel(order),1);
            % aicm = armse;
            % for k = order
            %     model = ar(data,k,'ls');
            %     armse(k) = model.r.fit.MSE;
            %     aicm(k) = aic(model);
            % end
            % figure;
            % plot(armse);
            % hold on;
            % plot(aicm,'r');
            % legend('MSE','AIC');

            %assume order 5, solve AR model with Burg's lattice method
            model =ar(d1,6,'burg');
            yhat = predict(model,d1,6);
            e_n = d1-yhat; %residual
            sigma = std(e_n); 
            d_n = (e_n/sigma).^2;

            %remove nan values from calculation of threshold
            tmp = d_n;
            tmp(isnan(data)) = [];
            thres = mean(tmp) + mult*std(tmp); %threshold residual squared by multiple
            %   plots below show the data, e_n, d_n, as well as thresholds. 
            %   uncomment to see how the algorithm works. 
            %   NOTE: for large datasets, this may crash matlab since too much data to
            %   plot.

            if plotGraphs==1
                figure(3)
                ax = zeros(2,1);
                ax(1) = subplot(3,1,1);
                plot(data);
                hold on;
                plot(yhat,'r')
                legend('y','yhat')
                ax(2) = subplot(3,1,2);
                plot(data-yhat);
                title('e_n')
                ax(3) = subplot(3,1,3);
                plot(d_n)
                hline(thres,'r')
                title('d_n');
                linkaxes(ax,'x')
            end

            %find peaks
            d_n(isnan(data)) = 0;
            [~, idx] = findpeaks(d_n,'MINPEAKHEIGHT',thres);
            spikeIdx = idx(diff(idx)>.075*fs); %keep peaks >.075 s apart
            spikeIdx = startPt + spikeIdx - 1; %set spikeIdx relative to block
            %% clustering to remove spike-like non spikes ( to be implemented)
            %     feat = zeros(numel(spikeIdx),.2*fs+1);
            %     for i = 1:numel(spikeIdx)
            %         tmpdat = data(spikeIdx(i)-.05*fs:spikeIdx(i)+.15*fs);
            %         feat(i,:) = tmpdat;
            %     end
            %     %eva = evalclusters(feat,'kmeans','gap','KList',[1:6]);
            %     %cluster into 4
            %     close all
            %     kidx = kmeans(feat,3);
            %     for i = 1:max(kidx)
            %         figure;
            %         tmpdat = feat(kidx==i,:);
            %         hold on;
            %         for j = 1:size(tmpdat,1)
            %             plot(tmpdat(j,:));
            %         end
            %         title(sprintf('Cluster %d',i));
            %         set(gca,'XTickLabel',str2num(get(gca,'XTickLabel'))/fs);
            %         xlabel('s')
            %     end

            %spikeIdx = spikeIdx(kidx==3)

            eventTimesUSec = [eventTimesUSec; spikeIdx/fs*1e6];
            eventChannels = [eventChannels; ones(numel(spikeIdx),1)*i];
        end
    end
end
eventTimesUSec = [eventTimesUSec eventTimesUSec]; %return in Nx2 [start stop] array
fprintf('\n%d spikes found\n',size(eventTimesUSec,1));
end
