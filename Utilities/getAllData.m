function data = getAllData(dataset,channels,blockLen)
%Usage: data = getAllData(IEEGDataset,channels)
%Gets all data in IEEGDataset dataset for specified channels.
%   Usage: data = getAllData(dataset,channels)
%   dataset    -    IEEGDataset
%   channels   -    array of channel indices
%   blockLen   -    length of each block to get in seconds
%   Gets all data in IEEGDataset dataset for specified channels.
%NOTE: If large dataset, use getExtendedData, which gets data one channel
%at a time

duration = dataset.rawChannels(1).get_tsdetails.getDuration;
fs = dataset.sampleRate;

numPoints = duration/1e6*fs;
numBlocks = ceil(numPoints/blockLen);

data = cell(numBlocks,1);
for i = 1:numBlocks
    startPt = 1+(i-1)*blockLen;
    endPt = i*blockLen;
    fprintf('Getting block %d of %d\n',i,numBlocks');
    try
        data{i} = dataset.getvalues(startPt:min(endPt,numPoints),channels);
    catch
        data{i} = dataset.getvalues(startPt:min(endPt,numPoints),channels);
    end
end
data = cell2mat(data);
