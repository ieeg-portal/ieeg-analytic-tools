function [ch_keep, ch_remove, stat] = identifyArtifactChannels_par(datasetNames,params,mult)
%datasetNames = params.datasetID;

IEEGid = params.IEEGid;
IEEGpwd = params.IEEGpwd;
ch_keep = cell(numel(datasetNames),1);
ch_remove = cell(numel(datasetNames),1);
stat = cell(numel(datasetNames),1);
%mult = 3; %3 tends to be a good multiplier
warning('off','all')

parfor i = 1:numel(datasetNames)
    fprintf('Checking %s\n',datasetNames{i});
    try
        lvar = load(sprintf('%s_rAC2.mat',datasetNames{i}));
        fprintf('Found Mat for %s\n',datasetNames{i});
        subj_ch_remove = lvar.subj_ch_remove;
        subj_ch_keep = lvar.subj_ch_keep;
        meanSlope = lvar.meanSlope;
    catch
        fprintf('Removing artifact channels for %s...\n',datasetNames{i});
        session = IEEGSession(datasetNames{i},IEEGid,IEEGpwd);
        numChannels = numel(session.data.rawChannels);
        meanSlope = zeros(numChannels,1);
        for ch = 1:numChannels
            startTimeUSec = session.data.rawChannels(ch).get_tsdetails.getStartTime;
            durationUSec = session.data.rawChannels(ch).get_tsdetails.getDuration;
            try
                LL = session.data.getvalues(startTimeUSec,min(durationUSec,60*60*1e6),ch);
            catch
                LL = session.data.getvalues(startTimeUSec,min(durationUSec,60*60*1e6),ch);
            end
            meanSlope(ch) = mean(abs(diff(LL)));
        end
        allCh = 1:numChannels;
        subj_ch_remove = find(meanSlope>(mean(meanSlope) + mult*std(meanSlope)));
        subj_ch_keep =  allCh(~ismember(allCh,subj_ch_remove));
        parsave(sprintf('%s_rAC2.mat',datasetNames{i}),subj_ch_remove,subj_ch_keep,meanSlope);
    end
    ch_remove{i} = subj_ch_remove;
    stat{i} = meanSlope;
    ch_keep{i} = subj_ch_keep;
end
    
        



        

