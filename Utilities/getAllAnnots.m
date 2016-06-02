function [allEvents, timesUSec, channels] = getAllAnnots(dataset,layerName)
<<<<<<< HEAD
% function will return a cell array of all IEEGAnnotation objects in
% annotation layer annLayer

% Input
%   'dataset'   :   IEEGDataset object
%   'layerName'  :   'string' of annotation layer name

=======
% Function will return a cell array of all IEEGAnnotation objects in
% annotation layer annLayer
% [allEvents, timesUSec, channels] = getAllAnnots(dataset,layerName)
% Input
%   'dataset'   :   IEEGDataset object
%   'layerName'  :   'string' of annotation layer name
>>>>>>> 45667d6cb1273defd11272f8308fddcc159728fe
% Output
%   'allEvents' :   All annotations
%   'timesUSec' :   Nx2 [start stop] times in USec
%   'channels'  :   cell array of channel idx for each annotation

% Hoameng Ung 6/15/2014
<<<<<<< HEAD
% 8/26/2014 - updated to return times and channels
% 8/28/2014 - changed input to annLayer Str
% 4/14/2015 - updated error handling
=======
% v2 8/26/2014 - updated to return times and channels
% v3 8/28/2014 - changed input to annLayer Str
% v4 4/14/2015 - updated error handling
% v5 7/28/2015 - Updated to support ieeg-matlab-1.13.2

>>>>>>> 45667d6cb1273defd11272f8308fddcc159728fe

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