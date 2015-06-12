function [ch_keep, ch_remove, stat] = removeArtifactChannels_par(params)
datasetNames = params.datasetID;
IEEGID = params.IEEGid;
IEEGPWD = params.IEEGpwd;
ch_keep = cell(numel(datasetNames),1);
ch_remove = cell(numel(datasetNames),1);
stat = cell(numel(datasetNames),1);
warning('off','all')
parfor i = 1:numel(datasetNames)
    fprintf('Checking %s\n',datasetNames{i});
    try
        lvar = load(sprintf('%s_rAC.mat',datasetNames{i}));
        fprintf('Found Mat for %s\n',datasetNames{i});
        subj_ch_remove = lvar.subj_ch_remove;
        subj_ch_keep = lvar.subj_ch_keep;
        meanSlope = lvar.meanSlope;
    catch
        fprintf('Removing artifact channels for %s...\n',datasetNames{i});
        session = IEEGSession(datasetNames{i},IEEGID,IEEGPWD);
        numChannels = numel(session.data.channels);
        meanSlope = zeros(numChannels,1);
        for ch = 1:numChannels
            startTimeUSec = session.data.channels(ch).get_tsdetails.getStartTime;
            durationUSec = session.data.channels(ch).get_tsdetails.getDuration;
            LL = session.data.getvalues(startTimeUSec,durationUSec,ch);
            meanSlope(ch) = mean(abs(diff(LL)));
        end
        allCh = 1:numChannels;
        subj_ch_remove = find(meanSlope>(mean(meanSlope) + 5*std(meanSlope)))
        subj_ch_keep =  allCh(~ismember(allCh,ch_remove{i}));
        parsave(sprintf('%s_rAC.mat',datasetNames{i}),subj_ch_remove,subj_ch_keep,meanSlope);
    end
    ch_remove{i} = subj_ch_remove
    stat{i} = meanSlope;
    ch_keep{i} = subj_ch_keep
end
    
        