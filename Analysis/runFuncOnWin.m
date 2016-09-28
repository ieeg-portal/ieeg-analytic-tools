function out = runFuncOnWin(x,fs,winLen,winDisp,featFn)
% Usage:  out = runFuncOnWin(x,fs,winLen,winDisp,featFn)
% Function function featFn on moving windows.
% Input:
%   x       :   N x Ch
%   fs      :   sample Rate
%   winLen  :   window length in seconds
%   winDisp :   window displacement in seconds
% Output:
%   out     :   N x P matrix

%anonymous functions
%EnergyFn = @(x) mean(x.^2);
%ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
%LLFn = @(x) mean(abs(diff(x)));
NumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));

numWindows = NumWins(length(x),fs,winLen,winDisp);

out = cell(numWindows,1);
for i = 1:numWindows
    %find current window
    data = x(round(1+(i-1)*(winDisp*fs)):round(((i-1)*(winDisp)+winLen)*fs),:);
    out{i} = featFn(data,fs);
end
out = cell2mat(out);
