function data = getExtendedData(dataset,idxs, ch)
%Function will get data in pieces if necessary, similar arguments as
%getvalues
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
       
