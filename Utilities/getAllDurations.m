function [dataset_id, durations] = getAllDurations(datasets)
%function will calculate durations (in seconds) of the first channel for each dataset in
%datasets
%Input:
%   datasets:   [n x 1] IEEGDataset array
%Output:
%   dataset_id: [n x 1] cell array of IEEGDataset snapname
%   durations:  [n x 1] numeric array of durations in seconds

subj = cell(numel(datasets),1);
dR = zeros(numel(datasets),1);
for i = 1:numel(datasets)
    subj{i} = datasets(i).snapName;
    dR(i) = datasets(i).rawChannels(1).get_tsdetails.getDuration/1e6;
end
durations = dR;
dataset_id = subj;
% 