%%
% Script for spike detection on data from the Kapur lab (private) through two stages
% 1. Hypersensitive spike detection with Janca 2016 detector
% 2. Second stage refinement through custom random forest classification
%
% Note: Requires portal matlab tools and IEEG Toolbox
% 
%
% Hoameng Ung, PhD 2016
% University of Pennsylvania
% hoameng.ung@gmail.com
% Copyright 2016

%% Establish IEEG Sessions
% Establish IEEG Sessions through the IEEGPortal. This will allow on demand
% data access

%add folders to path 
addpath(genpath('../../../../Libraries/ieeg-matlab-1.13.2')); %path to ieeg portal matlab toolbox

%these should point to portal-matlab-tools
addpath(genpath('../portalGit/Analysis'))
addpath(genpath('../portalGit/Utilities'))

%Load data
params = initialize_task_spike;
% Load data
session = loadData(params);
 
% % Get training set
class1_layers = {'PFC','I','C'};
class2_layers = {'Noise'};

%% RUN SPIKE JA

%set channels
channelIdxs = cell(numel(session.data),1);
for i = 1:numel(session.data)
    channelIdxs{i} = 1:numel(session.data(i).rawChannels);
end

for i = 1:numel(session.data)
    [spikeTimes, spikeChannels,DE] = spike_ja_wrapper(session.data(i),channelIdxs{i});
    uploadAnnotations(session.data(i),'spike_ja',spikeTimes,spikeChannels,'spike','overwrite');
end

%find those in original true and false layers, find nearest spike_ja spike,
%and reassign to "true spike", "false spike"
for i = 1:numel(session.data)
    leftWin = 0.1;
    rightWin = 0.1;
    
    % CLASS 1
    allTimes = [];
    allChannels = [];
    for j = 1:numel(class1_layers)
       [~,timesUSec,channels] = getAnnotations(session.data(i),class1_layers{j});
       allTimes = [allTimes; timesUSec];
       allChannels = [allChannels ; channels];
    end
    [~,cand_times, cand_channels] = getAnnotations(session.data(i),'spike_ja');

    idx = zeros(size(cand_times,1),1);
    for k = 1:size(cand_times,1)
        tmp = find((cand_times(k,1)-leftWin*1e6)<allTimes(:,1) & (cand_times(k,2)+rightWin*1e6)>allTimes(:,2));
        if ~isempty(tmp)
            idx(k) = 1;
        end
    end
    idx = logical(idx);
    c1_spikes = cand_times(idx);
    c1_chan = cand_channels(idx); 
    uploadAnnotations(session.data(i),'true_spikes',c1_spikes,c1_chan,'spike','append')

    % CLASS 2
    allTimes = [];
    allChannels = [];
    for j = 1:numel(class2_layers)
       [~,timesUSec,channels] = getAnnotations(session.data(i),class2_layers{j});
       allTimes = [allTimes; timesUSec];
       allChannels = [allChannels ; channels];
    end
    [~,cand_times, cand_channels] = getAnnotations(session.data(i),'spike_ja');

    idx = zeros(size(cand_times,1),1);
    for k = 1:size(cand_times,1)
        tmp = find((cand_times(k,1)-leftWin*1e6)<allTimes(:,1) & (cand_times(k,2)+rightWin*1e6)>allTimes(:,2));
        if ~isempty(tmp)
            idx(k) = 1;
        end
    end
    idx = logical(idx);
    c2_spikes = cand_times(idx);
    c2_chan = cand_channels(idx); 
    uploadAnnotations(session.data(i),'false_spikes',c2_spikes,c2_chan,'noise','append')
end

%% pull true and false spikes, train detector, detect rest of candidate spikes
for i = 1:numel(session.data)
    feat = runFuncOnAnnotations(session.data(i),@features_comprehensive,'layerName','false_spikes','useAllChannels',0,'feature_params',{'cwt'},'PadStartBefore',0.05,'PadEndAfter',0.2);
    feat2 = runFuncOnAnnotations(session.data(i),@features_comprehensive,'layerName','true_spikes','useAllChannels',0,'feature_params',{'cwt'},'PadStartBefore',0.05,'PadEndAfter',0.2);
    %run on origin markings
    feat3 = runFuncOnAnnotations(session.data(i),@features_comprehensive,'layerName','spike_ja','useAllChannels',0,'feature_params',{'cwt'},'PadStartBefore',0.05,'PadEndAfter',0.2);

    trainset = [cell2mat(feat);cell2mat(feat2)];
    colmeans = mean(trainset);
    labels = [zeros(numel(feat),1);ones(numel(feat2),1)];
    [evectors, score, evalues] = pca(trainset);
    trainset = score;
    
    testset = cell2mat(feat3);
    testset= testset-repmat(colmeans,size(feat3,1),1);
    testset = testset*evectors;

	mod = TreeBagger(500,trainset,labels,'method','Classification','OOBPredictorImportance','on','Cost',[0 20; 1 0]);
	save('RFmod.mat','mod');
    oobErrorBaggedEnsemble = oobError(mod);
    plot(oobErrorBaggedEnsemble)
    xlabel 'Number of grown trees';
    ylabel 'Out-of-bag classification error';


    [yhat,scores] = oobPredict(mod);
    [conf, classorder] = confusionmat(categorical(labels), categorical(yhat))

    imp = mod.OOBPermutedPredictorDeltaError;
    predictorNames = {};
    for pc = 1:max(30,size(trainset,2))
        predictorNames{pc} = sprintf('%d',pc');
    end
    figure;
    bar(imp);
    ylabel('Predictor importance estimates');
    xlabel('PC');
    h = gca;
    h.XTick = 1:2:60
    h.XTickLabel = predictorNames
    h.XTickLabelRotation = 45;
    h.TickLabelInterpreter = 'none';

%   plot imp back to original wavelet space
%   pcs = 1:60;
%   waveCoeff = imp(pcs)*evectors(:,pcs)';
%   rwave = reshape(waveCoeff,60,[]);
%   imagesc(rwave);
%   colorbar;
%   xlim([50, 400])
%   xlabel('Sample')
%   ylabel('Scale')
%   set(gca,'FontSize',14);
%   set(gca,'YDir','normal');
    
    [yhat ypred] = predict(mod,testset);
    [~,detected_times,detected_channels] = getAnnotations(session.data(i),'spike_ja');
    [a, class] = max(ypred,[],2);
    uploadAnnotations(session.data(i),'detected_spike',detected_times(class==2),detected_channels(class==2),'spike','overwrite');
end


