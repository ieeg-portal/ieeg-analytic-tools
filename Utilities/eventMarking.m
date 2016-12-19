function out = eventMarking(dataset,eventTimesUSec,eventChannels,varargin)
%Function will pull random snippets from input, prompt for user marking of
%different types, upload as different annotations.

    %Plot random segments for classification
    numToVet = 20;
    intelligent = 0; 
    for i = 1:2:nargin-3
        switch varargin{i}
            case 'numToVet'
                numToVet = varargin{i+1};
            case 'intelligent'
                intelligent = varargin{i+1};
            case 'feature_params'
                feature_params = varargin{i+1};
            otherwise
                error('Unknown parameter %s',varargin{i});
        end
    end
    
    %intelligent mode:
    % extract features from times, cluster using gap statistic, then
    % randomly select to make sure each cluster is repredosented
    if intelligent
        fprintf('Initiating intelligent mode...\n');
        tmp.eventTimesUSec = eventTimesUSec;
        tmp.eventChannels = eventChannels;
        fprintf('Extracting features...\n');
        feats = runFuncOnAnnotations(dataset,@features_comprehensive,'feature_params',feature_params,'runOnWin',0,'useAllChannels',0,'customTimeWindows',tmp);
        feats = cell2mat(feats);
        fprintf('Running PCA...\n');
        [coeff, score, latent, tsquared] = pca(feats);
        E = evalclusters(score,'kmeans','Gap','klist',[2:10]);
        idx = kmeans(score,5);
        markers = {'r*','b*','g*','k*','c*'};
        for i = 1:numel(E.OptimalK)
            tmpdat = score(idx==i,:);
            scatter3(tmpdat(:,1),tmpdat(:,2),tmpdat(:,3),markers{i});
            hold on;
        end
    end
    
    
    randIdx = randi(size(eventTimesUSec,1),1,numToVet);
    fp = [];
    tp = [];
    fs = dataset.sampleRate;
    nCh = numel(dataset.rawChannels);
    %for each point
    type = cell(numToVet,1);
    k = 1;
    while k <= numel(randIdx)
        j = randIdx(k);
        %get data        
        duration = (eventTimesUSec(j,2) - eventTimesUSec(j,1))/1e6;
        padsec = round((10-duration)/2);
        startIdx = ((eventTimesUSec(j,1)/1e6)-padsec)*fs;
        endIdx = ((eventTimesUSec(j,2)/1e6)+padsec)*fs;
        tmpdata = dataset.getvalues(startIdx:endIdx,1:nCh);
        if numel(eventChannels)==1
            quickPlotEEG(tmpdata,fs,'Pad',padsec,'Highlight Channels',eventChannels);
        else
            quickPlotEEG(tmpdata,fs,'Pad',padsec,'Highlight Channels',eventChannels{j});
        end
        annotation('textbox', 'Position', [0.1 0.9 0.1 0.1], 'String', sprintf('%0.2f s',eventTimesUSec(j,1)/1e6), 'EdgeColor', 'none', 'VerticalAlignment', 'middle');
        clipboard('copy',eventTimesUSec(j,1)/1e6)
        reply = input(sprintf('Event %d/%d, Type?: ',k,numToVet),'s');
        if strcmp(reply,'back')
            k = k - 1;
        else
            type{k} = reply;
            k = k + 1;
        end
    end
    uniqueType = unique(type);
    save(sprintf('%s_type%d.mat',dataset.snapName,now),'randIdx','type');
    for l = 1:numel(uniqueType)
        idx = find(cellfun(@(x)strcmp(x,uniqueType(l)),type));
        times = eventTimesUSec(idx,:);
        ch = eventChannels(idx);
        uploadAnnotations(dataset,['Type ' uniqueType{l}],times,ch,['Type ' uniqueType{l}],'append');
    end
end
    
