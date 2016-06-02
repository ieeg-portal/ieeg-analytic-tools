% Main wrapper script
% User should only need to edit the initialize.m file

% Run initialization
params = initialize_task;

% Load data
session = loadData(params);

for i = 1:numel(session.data)
%% Preprocess

%% Action

% pull annotations
   [~, times, ] = getAllAnnots(session.data(i),'Seizure_CCS'); 
fs = session.data(i).sampleRate;
% Extract features for one hour , 5 second windows, prior to each seizure
for j = 1:size(times,2)
    startPt = (times(j,1)/1e6 - 60*60)*fs;
    endPt = times(j,2)/1e6*fs;
    
    %extract windows

% Extract Features
 %feat = calcFeature_v5_par(session.data(i),params);
 
% Run Detections

% Cluster detections

end

%% Visualization
% View annotation timeline
for i = 1:numel(session.data)
   durationDays = session.data(1).channels(1).get_tsdetails.getDuration/1e6/60/60/24;
   [~, times, ] = getAllAnnots(session.data(i),'Seizure_CCS'); 
   hist(times(:,1)/1e6/60/60/24,durationDays)
   [~, times, ] = getAllAnnots(session.data(i),'Seizure_CES'); 
   hist(times(:,1)/1e6/60/60/24,durationDays)
end


