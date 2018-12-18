
function feats = features_comprehensive(data, fs,params,varargin)

%     %power from 1-48hz 
%     freqRange = 1:48;
%     P = pmtm(data,[],size(data,1),fs);
%     feats = log10(abs(P(freqRange,:)))';
%     feats = reshape(feats, 1,[]);

calcPower = 0;
calcCorr = 0;
calcCWT = 0;
for i = 1:numel(params)
    switch params{i}
        case 'power'
            calcPower = 1;
        case 'corr'
            calcCorr = 1;
        case 'cwt'
            calcCWT = 1;
        case 'LL'
            calcLL = 1;
        otherwise
            error('Unknown parameter %s',varargin{i});
    end
end
   nChan = size(data,2);
   if ~any(any(isnan(data))) 
        feats = [];
        if calcPower
            P = pmtm(data,[],1:fs/2,fs);
            binSize = 5; %hz
            freqBins = 1:binSize:size(P,1);
            Pbins = zeros(numel(freqBins),size(data,2));
            for i = 1:numel(freqBins)-1
                Pbins(i,:) = sum(P(freqBins(i):freqBins(i+1),:));
            end
            Pbins = log10(abs(Pbins));
            feats = [feats reshape(Pbins, 1,[])];
        end
        if calcCorr
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
            toadd = toadd(find(~tril(ones(size(toadd)))))';
            feat = [feat toadd];
        end
        if calcCWT
            %% add wavelets for spike
            scales = 1:60;
            coeffs = zeros(size(data,2),numel(scales)*size(data,1));
            for j = 1:size(data,2)
                coeffs(j,:) = reshape(cwt(data,scales,'mexh'),1,numel(scales)*size(data,1));
            end
            coeffs = abs(coeffs);
            norm_coeffs = bsxfun(@minus, coeffs, min(coeffs,[],2));
            divnorm = (max(coeffs,[],2)-min(coeffs,[],2));
            norm_coeffs = bsxfun (@rdivide, norm_coeffs, divnorm);
            feats = [feats norm_coeffs];
        end
        if calcLL
            
    else
        feats = NaN(1,896); %need to generalize default size
    end
    
end