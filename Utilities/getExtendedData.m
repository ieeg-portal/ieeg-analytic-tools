function data = getExtendedData(dataset,idxs, ch)
%   Usage: data = getExtendedData(dataset,idxs, ch)
%	
%	dataset	-	IEEGDataset object
%	idxs	-	string of name of annotation layer
%	ch      -	array of idx
%   Function will get data in pieces by channel if necessary, similar arguments as
%   getvalues
% Note: if this function throws errors, try getting less data (reducing indices). 

total = numel(idxs)*numel(ch);
dataLim = 500*130*2000;
if total < dataLim
    data = dataset.getvalues(idxs,ch);
else
    fprintf('Splitting get data request...\n');
    if numel(idxs) < dataLim
        data = zeros(numel(idxs),numel(ch));
        for i = 1:numel(ch)
            data(:,i) = dataset.getvalues(idxs,ch(i));
        end
    end %% implement for each part, for each channel
end
       
