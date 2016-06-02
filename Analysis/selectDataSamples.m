function [dataSamples] = selectDataSamples(session, parameters, dataKey)
  
  IDlayer = parameters.InitialDetections.layerName;
  numDetections = parameters.reviewDetections.numDetections;
  numAnimals = length(dataKey.Index);
  
  if length(session.data) ~= numAnimals
    session = IEEGSession(dataKey.Portal_ID{1}, ...
      parameters.IEEGInfo.userName,...
      parameters.IEEGInfo.credentialsFile);
    for r = 2:numAnimals
      session.openDataSet(dataKey.Portal_ID{r});
    end
  end
  
  numberOfAnnotations = zeros(length(dataKey.Index), 1);  
  for r = 1: numAnimals
    try
      idx = strcmp(IDlayer, {session.data(r).annLayer.name});
      numberOfAnnotations(r) = session.data(r).annLayer(idx).getNrEvents;
    catch
    end
  end
%     sampleThese{r,:} = randperm(allLengths(r));
  sampleThese = sort( randsample(numAnimals, numDetections, true, numberOfAnnotations) );
  numSamples = hist(sampleThese, 1:numAnimals)';
  
  dataSamples = cell(numAnimals, 1);
  for r = 1: numAnimals
    if numSamples(r) > 0
      dataSamples{r} = sort(randperm(numberOfAnnotations(r), numSamples(r)));
    end
  end
end



