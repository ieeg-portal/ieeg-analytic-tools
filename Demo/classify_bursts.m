function [bursts, artifacts] = classify_bursts(datasets,layerNames,modelFn,saveLayer)
%e.g.
%classify_upload_bursts(session.data,{'burst_detections_2','burst_detections_3'},'B-Amodel.mat');
%layerNames = cell array of strings of layerNames to pull bursts from
load(modelFn);

%FOR EACH DATASET, LOAD ALL BURSTS, CLASSIFY, REUPLOAD
for i = 1:numel(datasets);
    fprintf('Running on %s \n',datasets(i).snapName);
    
    %GET ALL TIMES AND CHANNELS FROM LAYERS
    timesUSec = [];
    eventChannels = [];
    %get all bursts to classify
    for j = 1:numel(layerNames)
        [~, times, eventCh] = getAllAnnots(datasets(i),layerNames{j});
        timesUSec = [timesUSec; times];
        eventChannels = [eventChannels; eventCh];
    end
    
    %GET ALL DATA 
    data = cell(size(timesUSec,1),1);
    for j = 1:size(timesUSec,1)
        data{j} = session.data(i).getvalues(timesUSec(j,1)/1e6*fs:timesUSec(j,2)/1e6*fs,eventChannels{j});
    end
    
    %CALCULATE FEATURES
    t = calcFeatureFromSignal(data{1},fs);
    numFeat = numel(t);
    feat = zeros(size(data,1),numFeat);
    for j = 1:size(data,1)
        feat(j,:) = calcFeatureFromSignal(data{j},fs);
    end
    
    %MAY NEED TO CHANGE TO ACCOMODATE MULTIPLE CHANNELS
    eventChannels = cell2mat(eventChannels);

    %REMOVE ALL DETECTIONS ON CHANNEL 2 (FOR ASLA ONLY)
    timesUSec(eventChannels==2,:) = [];
    feat(eventChannels==2,:) = [];
    eventChannels(eventChannels==2) = [];
   %  mf = mean(feat);
   %  nf = sqrt(sum(feat.^2));
   
    %NORMALIZE
    feat = feat - repmat(mf,size(feat,1),1); %center
    feat = feat ./ repmat(sqrt(sum(feat.^2)),size(feat,1),1); %div by 2norm
    feat = feat(:,keep);
    
    %PREDICT LABELS
    %SVM
    yhat = svmpredict(ones(size(feat,1),1),feat,models.svm.model);
    %LASSO
    %yhat = feat*w + intercept;
    %yhat(yhat<0) = -1;
    %yhat(yhat>0) = 1;
    
    bursts.timesUSec = timesUSec(yhat==1,:);
    bursts.eventChannels = eventChannels(yhat==1,:);
    artifacts.timesUSec = timesUSec(yhat==-1,:);
    artifacts.eventChannels= eventChannels(yhat==-1,:);
    uploadAnnotations(session.data(i),saveLayer{1},timesUSec(yhat==1,:),eventChannels(yhat==1),'burst')
    uploadAnnotations(session.data(i),saveLayer{2},timesUSec(yhat==-1,:),eventChannels(yhat==-1),'artifact')
end