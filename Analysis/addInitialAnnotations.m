function addInitialAnnotations(dataset, layerName, eventTimesUSec, eventChannels, label)
%	Usage: f_addAnnotations(dataset, params);
% should be called by f_initialDetection()
%	
%	f_addAnnotations() adds annotations to the portal.  This is really the
%	same code as uploadAnnotations but it reads the annotations from file.
%	The annotations are saved to a file in f_initialDetection since they all
%	need to be uploaded to the portal at once but large datasets need to be
%	processed in blocks.
%
%
% Input:
%   dataset - singe IEEG session dataset
%   params		-	a structure containing at least the following:
%     params.homeDirectory
%     params.runDir  
%     params.feature 
%
% Output:
%   to portal -> detections uploaded to portal as a layer called 'initial-XXXX'
%
% History:
% 7/20/2015 - v1 - creation
%.............

  % remove existing annotation layer
  try 
    fprintf('\nRemoving existing layer\n');
    dataset.removeAnnLayer(layerName);
  catch 
    fprintf('No existing layer\n');
  end
  
  % create new layer, figure out how many unique channels there are
  annLayer = dataset.addAnnLayer(layerName);
%   uniqueAnnotChannels = unique([eventChannels{:}]);
  ann = cell(length(eventChannels),1);
  fprintf('Creating annotations...\n');

  % create annotations one channel at a time
  for i = 1:numel(eventChannels)
    ann{i} = IEEGAnnotation.createAnnotations(eventTimesUSec(i,1), eventTimesUSec(i,2), 'Event', label, dataset.rawChannels(eventChannels{i}));
%     ann = [ann IEEGAnnotation.createAnnotations(eventTimesUsec(i,1), eventTimesUsec(i,2), 'Event', params.label, dataset.channels(i))];
%     tmpChan = uniqueAnnotChannels(i);
%     ann = [ann IEEGAnnotation.createAnnotations(eventTimesUsec(eventChannels==tmpChan,1), eventTimesUsec(eventChannels==tmpChan,2),'Event', params.label,dataset.channels(tmpChan))];
  end
  fprintf('done!\n');

  % upload annotations 5000 at a time (freezes if adding too many)
  numAnnot = numel(ann);
  startIdx = 1;
  fprintf('Adding annotations...\n');
  for i = 1:ceil(numAnnot/5000)
    fprintf('Adding %d to %d\n',startIdx,min(startIdx+5000,numAnnot));
    annLayer.add([ann{startIdx:min(startIdx+5000,numAnnot)}]);
    startIdx = startIdx+5000;
  end
  fprintf('done!\n');
end
