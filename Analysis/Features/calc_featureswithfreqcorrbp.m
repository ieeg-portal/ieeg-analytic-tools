
function feats = calc_featureswithfreqcorrbp(data, fs)

%     %power from 1-48hz 
%     freqRange = 1:48;
%     P = pmtm(data,[],size(data,1),fs);
%     feats = log10(abs(P(freqRange,:)))';
%     feats = reshape(feats, 1,[]);
   if ~any(any(isnan(data))) 
        P = pmtm(data,[],1:fs/2,fs);

        binSize = 5; %hz
        freqBins = 1:binSize:size(P,1);
        Pbins = zeros(numel(freqBins),size(data,2));
        for i = 1:numel(freqBins)-1
            Pbins(i,:) = sum(P(freqBins(i):freqBins(i+1),:));
        end

        Pbins = log10(abs(Pbins));
        feats = reshape(Pbins, 1,[]);
        fc = corr(P);
        fc = triu(fc,1);
        fc = fc(fc~=0)';

        %correlation between channels
        %feats = [feats triu(corrcoef(data),-1)];

        %cross correlation
        [acor, lag] = xcorr(data,round(.25*fs),'coeff');
        [r,c] = find(acor == max(max(acor)));
        r =r(1);
        toadd = reshape(acor(r,:),size(data,2),[]);
        toadd = triu(toadd,1);
        toadd = toadd(toadd~=0)';
        
        %% add avg bandpower for each channel for spatial aspect


        feats = [feats toadd fc bandpower(data)];
    else
        feats = NaN(1,896);
    end
    
end