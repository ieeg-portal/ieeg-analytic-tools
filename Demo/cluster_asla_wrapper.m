
%LOAD ALL DATASETS
session = IEEGSession('I010_A0001_D001','hoameng','hoa_ieeglogin.bin');
subj = 2:24;
for i = subj
    dataName = sprintf('I010_A00%.2d_D001',i);
    try
        session.openDataSet(dataName);
    catch
        fprintf('Unable to load %s\n',dataName)
    end
end

channelIdxs = cell(numel(session.data),1);
for i = 1:numel(session.data)
    channelIdxs{i} = 1:2;
end

%BURST DETECTION
% for i = 1:numel(session.data)
%      fprintf('Detecting in : %s\n',session.data(i).snapName);
%      try
%          filtFlag = 1;
%         [burstTimes, burstChannels] = burst_detector_v2(session.data(i),channelIdxs{i},2,100,1.25,9,filtFlag);
%         uploadAnnotations(session.data(i), 'burst_detections',burstTimes,burstChannels,'burst');
%      catch ME
%         disp(ME)
%         fprintf('Failed detecting in: %s\n',session.data(i).snapName);
%      end
% ends

%% CLUSTER BURSTS ONCE DETECTED ABOVE
%INITIAL CLUSTER
idxByDataset = initialBurstClusterAsla(session.data,'burst_detections'); 
for i = 1:numel(session.data)
    idx = idxByDataset{i}; %GET IDXS FOR DATASET
   	annots = getAllAnnots(session.data(i),'burst_detections'); %GET ALL ANNOTS
    for j=1:max(idx) %FOR EACH CLUSTER
        fprintf('Adding cluster %d...',j)
        newLayerName = sprintf('burst_detections_%d',j);
        try
            session.data(i).removeAnnLayer(newLayerName); %TRY TO REMOVE IN CASE ALREADY PRESENT
        catch
        end
        annLayer = session.data(i).addAnnLayer(newLayerName);
        ann=annots(idx==j);
        numAnnot = numel(ann);
        startIdx = 1;
        %add annotations 5000 at a time (freezes if adding too many)
        for k = 1:ceil(numAnnot/5000)
            fprintf('Adding %d to %d\n',startIdx,min(startIdx+5000,numAnnot));
            annLayer.add(ann(startIdx:min(startIdx+5000,numAnnot))); %add corresponding annotation
            startIdx = startIdx+5000;
        end
        fprintf('...done!\n')
    end
end

%TRAIN BURST VS ARTIFACT CLASSIFIER
models = train_burst_artifact_model('B-Amodel.mat');

%CLASSIFY AND UPLOAD
[bursts, artifacts] = classify_bursts(session.data,{'burst_detections_2','burst_detections_3'},'B-Amodel.mat',{'burst_real','burst_artifact'});

