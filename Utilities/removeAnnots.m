function removeAnnots(datasets,exp)
%function will remove all annotation layers matching regexp exp from IEEGDatasets. 
%CAUTION: PERMANENTLY REMOVE 


for i = 1:numel(datasets)
    fprintf('Removing layers from %s \n',datasets(i).snapName);
    try
    layers = [datasets(i).annLayer];
    layerNames = {layers.name};
    tmp = cellfun(@(x)regexp(x,exp)>0,layerNames,'UniformOutput',0);
    tmp = cellfun(@(x)(~isempty(x)),tmp);
    layerIdxs = find(tmp~=0);
        for j = layerIdxs
            resp = input(sprintf('Remove layer %s ...? (y/n): ',layerNames{j}),'s');
            if strcmp(resp,'y')
                try
                    datasets(i).removeAnnLayer(layerNames{j});
                    fprintf('...done!\n');
                catch
                    fprintf('...fail!\n');
                end
            end
        end
    catch
        fprintf('No layers found\n');
    end
    
end