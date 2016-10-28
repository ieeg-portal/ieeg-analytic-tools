function renameAnnotations(datasets,oldLayer,newLayer)

%%
% Usage: renameAnnotations(datasets,oldLayer,newLayer)
% 
%
%
%
for i = 1:numel(datasets)
   fprintf('Renaming layers from %s \n',datasets(i).snapName);
    layers = [datasets(i).annLayer];
    layerNames = {layers.name};
    tmp = cellfun(@(x)regexpi(x,oldLayer)>0,layerNames,'UniformOutput',0);
    tmp = cellfun(@(x)(~isempty(x)),tmp);
    layerIdxs = find(tmp~=0);
    if isempty(layerIdxs)
        fprintf('No layer found\n');
    else
        for j = layerIdxs
            %if no channels specified, remove entire layer
            resp = input(sprintf('Rename layer %s ...? (y/n): ',layerNames{j}),'s');
            if strcmp(resp,'y')
                try
                    datasets(i).annLayer(j).rename(newLayer);
                    fprintf('...done!\n');
                catch ME
                    fprintf('...fail! %s\n',ME.exception);
                end
            end
        end
    end
end