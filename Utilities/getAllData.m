function data = getAllData(dataset,channels)

blockLen = 5000;
duration = dataset.channels(1).get_tsdetails.getDuration;
fs = dataset.sampleRate;

numPoints = duration/1e6*fs;
numBlocks = ceil(numPoints/blockLen);

data = cell(numBlocks,1);
for i = 1:numBlocks
    startPt = 1+(i-1)*blockLen;
    endPt = i*blockLen;
    data{i} = dataset.getvalues(startPt:min(endPt,numPoints),channels);
end
data = cell2mat(data);