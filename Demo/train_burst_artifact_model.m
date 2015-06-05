function models = train_burst_artifact_model(savename)

%% Train burst artifact model for Asla based on Doug's annotations

%SETUP
clear all;

session = IEEGSession('I010_A0001_D001','hoameng','hoa_ieeglogin.bin');
session.openDataSet('I010_A0002_D001');
session.openDataSet('I010_A0003_D001');
fs = session.data(1).sampleRate;

%% GET ALL BURSTS AND LABELS 

%RAT 1
[~, timesUSec1, eventChannels1] = getAllAnnots(session.data(1),'Doug-cl2-correct');
[~, timesUSec2, eventChannels2] = getAllAnnots(session.data(1),'Doug-cl3-correct');
[~, timesUSec3, eventChannels3] = getAllAnnots(session.data(1),'Doug-cl2-incorrect');
[~, timesUSec4, eventChannels4] = getAllAnnots(session.data(1),'Doug-cl3-incorrect');
times = [timesUSec1;timesUSec2;timesUSec3;timesUSec4];
eventChannels = [eventChannels1 eventChannels2 eventChannels3 eventChannels4];
data1 = cell(size(times,1),1);
for i = 1:size(times,1)
    data1{i} = session.data(1).getvalues(times(i,1)/1e6*fs:times(i,2)/1e6*fs,eventChannels{i});
end
labels1 = [ones(size(timesUSec1,1),1); ones(size(timesUSec2,1),1);ones(size(timesUSec3,1),1)*-1;ones(size(timesUSec4,1),1)*-1];

%RAT 2
[~, timesUSec1, eventChannels1] = getAllAnnots(session.data(2),'Doug-cl2-correct');
[~, timesUSec2, eventChannels2] = getAllAnnots(session.data(2),'Doug-cl3-correct');
[~, timesUSec3, eventChannels3] = getAllAnnots(session.data(2),'Doug-cl2-incorrect');
[~, timesUSec4, eventChannels4] = getAllAnnots(session.data(2),'Doug-cl3-incorrect');
times = [timesUSec1;timesUSec2;timesUSec3;timesUSec4];
eventChannels = [eventChannels1 eventChannels2 eventChannels3 eventChannels4];
data2 = cell(size(times,1),1);
for i = 1:size(times,1)
    data2{i} = session.data(2).getvalues(times(i,1)/1e6*fs:times(i,2)/1e6*fs,eventChannels{i});
end
labels2 = [ones(size(timesUSec1,1),1); ones(size(timesUSec2,1),1);ones(size(timesUSec3,1),1)*-1;ones(size(timesUSec4,1),1)*-1];

%RAT 3
[~, timesUSec1, eventChannels1] = getAllAnnots(session.data(3),'Doug-cl2-correct');
[~, timesUSec2, eventChannels2] = getAllAnnots(session.data(3),'Doug-cl3-correct');
[~, timesUSec3, eventChannels3] = getAllAnnots(session.data(3),'Doug-cl2-incorrect');
[~, timesUSec4, eventChannels4] = getAllAnnots(session.data(3),'Doug-cl3-incorrect');
times = [timesUSec1;timesUSec2;timesUSec3;timesUSec4];
eventChannels = [eventChannels1 eventChannels2 eventChannels3 eventChannels4];
data3 = cell(size(times,1),1);
for i = 1:size(times,1)
    data3{i} = session.data(3).getvalues(times(i,1)/1e6*fs:times(i,2)/1e6*fs,eventChannels{i});
end
labels3 = [ones(size(timesUSec1,1),1); ones(size(timesUSec2,1),1);ones(size(timesUSec3,1),1)*-1;ones(size(timesUSec4,1),1)*-1];

%GATHER BURSTS AND LABELS
data = [data1;data2;data3];
labels = [labels1;labels2;labels3];

%% CALCULATE FEATURES
%calculate for first dataset to find number of features
t = calcFeatureFromSignal(data{1},fs); 
numFeat = numel(t);

%CALCULATE FEATURES FOR EACH DATASET
feat = zeros(size(data,1),numFeat);
for i = 1:size(data,1)
    feat(i,:) = calcFeatureFromSignal(data{i},fs);
end

%NORMALIZE BECAUSE LASSO IS NOT SCALE INVARIANT AND FEATURES MUST BE
%COMPARABLE
mf = mean(feat);
nf = sqrt(sum(feat.^2));
feat = feat - repmat(mf,size(feat,1),1); %center
feat = feat ./ repmat(sqrt(sum(feat.^2)),size(feat,1),1); %div by 2norm

%FEATURE SELECTION: FIND INTERSECTION OF SELECTED FEATURES ACROSS 4
%DIFFERENT LASSO CV ITERATIONS
featIdx = cell(4,1);
[B stats] = lasso(feat,labels,'CV',5);
featIdx{1} = find(B(:,stats.IndexMinMSE)~=0);
[B stats] = lasso(feat,labels,'CV',5);
featIdx{2} = find(B(:,stats.IndexMinMSE)~=0);
[B stats] = lasso(feat,labels,'CV',5);
featIdx{3} = find(B(:,stats.IndexMinMSE)~=0);
[B stats] = lasso(feat,labels,'CV',5);
featIdx{4} = find(B(:,stats.IndexMinMSE)~=0);
C = intersect(featIdx{1},intersect(featIdx{2},intersect(featIdx{3},featIdx{4})));
keepcv5 = [3 7 8 9 10 11 12 14 15 16 19 21 23 24]; %original selected features for Asla p20 10/18/2014
keep = keepcv5;
feat = feat(:,keep);

%% PLOT FEATURE HISTOGRAMS FOR REFERENCE
for i = 1:size(feat,2);
    subplot(floor(sqrt(size(feat,2))),ceil(sqrt(size(feat,2)))+1,i)
    [fh, fx] = hist(feat(labels==1,i),15);
    bar(fx,fh/trapz(fx,fh),'FaceColor','r'); 
    hold on;
    [fh, fx] = hist(feat(labels==-1,i),30);
    bar(fx,fh/trapz(fx,fh),'FaceColor','b');
    bH = get(gca,'children');
    pH = arrayfun(@(x) allchild(x),bH);
    set(pH,'FaceAlpha',0.3);
end

%% SEPARATE INTO TWO GROUPS FOR ROUGH ACCURACY ESTIMATE 
g1 = feat(labels==1,:);
g2 = feat(labels==-1,:);
tlabels = [ones(70,1); ones(70,1)*-1];
tfeat = [g1(1:70,:); g2(1:70,:)];
tfeat2 = [g1(71:end,:);g2(71:end,:)];
tlabels2 = [ones(59,1);ones(279,1)*-1];
model = svmtrain(tlabels,tfeat,'-t 0 -c 13');
[a b c] = svmpredict(tlabels2,tfeat2,model); %~89% acc
fnr = sum(tlabels2==-1 & a==1)/sum(tlabels2==-1)
fpr = sum(tlabels2==1 & a==-1)/sum(tlabels2==1)
%% BUILD MODELs USING SVM AND RIDGE REGRESSION FROM SELECTED FEATURES
[B stats] = lasso(feat,labels,'Alpha',0.01);
models.lasso.B = B(:,1); %Asla model: [1.3364    1.6143    1.3906    3.7255   -4.1784    9.0249   -1.6786   -0.0896   -0.7111   -2.2408   -1.9583 3.0950   -1.7145    1.4478]
models.lasso.intercept = stats.Intercept(1); %Asla model: -.4603
models.svm.model = libsvmtrain(labels,feat);

save(savename,'models');
