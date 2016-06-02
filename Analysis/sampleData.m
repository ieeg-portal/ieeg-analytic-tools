function [combinedAnnots, combinedChannels] = sampleData(dataset, params)
  for r = 1: length(allData)
    allLengths(r,1) = length(allData(r).channels);
  end
%     sampleThese{r,:} = randperm(allLengths(r));
  sampleThese = sort(randsample(length(allLengths), numDetections, true, allLengths));
  numSamples = hist(sampleThese, 1:length(allLengths))';
  these = cell(length(allData),1);
  
  for r = 1: length(allData)
    if numSamples(r) > 0
      these{r} = sort(randi(allLengths(r), [numSamples(r), 1]));
%       close all force;
%       f_scoreDetections(session.data(r), layerName, allData(runThese(r)).timesUsec(these,:), [1:4], 'testing', dataKey(runThese(r),:));
%       keyboard;
    end
  end

  for r = 1: length(parameters.runThese)
    if ~isempty(these{parameters.runThese(r)})
      close all force;
      f_scoreDetections(session.data(r), layerName, allData(parameters.runThese(r)).timesUsec(these{parameters.runThese(r)},:), [1:4], 'testing', dataKey(parameters.runThese(r),:));
      keyboard;
    end
  end
end
end



