function uploadAnnotations(dataset,layerName,eventTimesUSec,eventChannels,label,overwrite)
%	Usage: uploadAnnotations(dataset, layerName, eventTimesUSec,eventChannels,label,overwriteFlag);
%	
%	dataset		-	IEEGDataset object
%	layerName	-	string of name of annotation layer
%	eventTimesUSec	-	array of event times in microsec
%	eventChannels	-	cell array of channel indices corresponding to each event
%	label		-	string label for events
%   overwrite   -   boolean, if true, overwrites existing layers
%
%	Function will upload to the IEEG portal the given events obtained from running various detection
%	algorithms (e.g. spike_AR.m). Annotations will be associated with eventChannels and given a label.
%
%   v2 3/15/2015 - Hoameng Ung - added variable channel support
%   v3 7/15/2015 - added variable event support
%   v4 10/13/2015 - added overwrite flag, wrapper func

if ~isempty(dataset.annLayer)
    existingLayers = {dataset.annLayer.name};
    if sum(strcmp(layerName,existingLayers))==0 %no layer exists
        createAndAdd(dataset,layerName,eventTimesUSec,eventChannels,label)
    else 
        if overwrite
            try 
                fprintf('\nRemoving existing layer\n');
                dataset.removeAnnLayer(layerName);
            catch 
                fprintf('No existing layer\n');
            end
            createAndAdd(dataset,layerName,eventTimesUSec,eventChannels,label)
        else
            fprintf('Layer %s in %s exists, skipping dataset\n',layerName,dataset.snapName);
        end
    end
else 
    createAndAdd(dataset,layerName,eventTimesUSec,eventChannels,label)
end
end

function createAndAdd(dataset,layerName,eventTimesUSec,eventChannels,label)
annLayer = dataset.addAnnLayer(layerName);
ann = [];
fprintf('[%s] Creating annotations for %s...',datestr(clock),dataset.snapName);
%create cell array of unique channels in eventChannels
strEventChannels = cellfun(@num2str,eventChannels,'UniformOutput',0);
uniqueChannels = unique(strEventChannels);
uniqueChannels = cellfun(@str2num,uniqueChannels,'UniformOutput',0);
for i = 1:numel(uniqueChannels)
    fprintf('Creating annotations for channel %d',uniqueChannels{i});
    idx = cellfun(@(x)isequal(x,uniqueChannels{i}),eventChannels);
    if size(eventTimesUSec,2)>1
        ann = [ann IEEGAnnotation.createAnnotations(eventTimesUSec(idx,1),eventTimesUSec(idx,2),'Event',label,dataset.rawChannels(uniqueChannels{i}))];
    else
        ann = [ann IEEGAnnotation.createAnnotations(eventTimesUSec(idx,1),eventTimesUSec(idx,1),'Event',label,dataset.rawChannels(uniqueChannels{i}))];
    end
end
fprintf('done!\n');
numAnnot = numel(ann);
startIdx = 1;
%add annotations 5000 at a time (freezes if adding too many)
fprintf('Adding annotations to layer %s...\n',layerName);
for i = 1:ceil(numAnnot/500)
    fprintf('Adding %d to %d\n',startIdx,min(startIdx+500,numAnnot));
    errorCount = 0;
    trialCount = 0;
    while errorCount == trialCount
        try
            trialCount = trialCount + 1;
            annLayer.add(ann(startIdx:min(startIdx+500,numAnnot)));
        catch
            errorCount = errorCount + 1;
            fprintf('Error!..Retrying time %d\n',trialCount);
        end
    end
    startIdx = startIdx+500;
end
fprintf('done!\n');
end
