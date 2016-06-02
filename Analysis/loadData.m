function session = loadData(params)

session = IEEGSession(params.datasetID{1},params.IEEGid,params.IEEGpwd);
for i = 2:numel(params.datasetID)
    try
     session.openDataSet(params.datasetID{i});
    catch
        fprintf('Couldn''t load %s \n',params.datasetID{i})
    end
end