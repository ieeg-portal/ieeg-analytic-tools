function [allEvents, timesUSec, channels] = getAnnotations(dataset,layerName)
% Usage: [allEvents, timesUSec, channels] = getAnnotations(dataset,layerName)
% function will return a cell array of all IEEGAnnotation objects in
% annotation layer annLayer

% Input
%   'dataset'   :   IEEGDataset object
%   'layerName'  :   'string' of annotation layer name

% Output
%   'allEvents' :   All IEEGAnnotationObjects
%   'timesUSec' :   Nx2 [start stop] times in USec
%   'channels'  :   cell array of channel idx for each annotation

% Hoameng Ung 6/15/2014
% 8/26/2014 - updated to return times and channels
% 8/28/2014 - changed input to annLayer Str
% 4/14/2015 - updated error handling
% 2/12/2016 - rename, misc comments, previously getAllAnnots

allEvents = [];
timesUSec = [];
channels = [];
startTime = 1;
allChan = [dataset.rawChannels];
allChanLabels = {allChan.label};
annLayer = dataset.annLayer(strcmp(layerName,{dataset.annLayer.name}));
if ~isempty(annLayer)
    while true
        currEvents = annLayer.getEvents(startTime,1000);
        if ~isempty(currEvents)
            allEvents = [allEvents currEvents];
            timesUSec = [timesUSec; [[currEvents.start]' [currEvents.stop]']];

            ch = {currEvents.channels};
            [~, b] = cellfun(@(x)ismember({x.label},allChanLabels),ch,'UniformOutput',0);
            channels = [channels b];

            startTime = currEvents(end).stop+1;
        else
            break
        end
    end
else
    disp('No Annotation Layer exists. Current annotations are')
    {dataset.annLayer.name}
end
channels = channels'; %make into Nx1 column of cells