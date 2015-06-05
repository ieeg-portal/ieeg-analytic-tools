function params = loadParameters
% Initialize variables
%params.dataKey = humanNV_dataKey

params.datasets = {
    'NVC1001_23_002'
    };

params.IEEGid = 'hoameng';
params.IEEGpwd = 'hoa_ieeglogin.bin';
params.preprocess = 1;

%Input:
%   'dataset'       :   IEEG dataset
%   'channels'      :   vector of channels
%   'winLen'        :   winLen = vector of windowlengths (s) to calculate
%                       features over
%   'outlabel'      :   Suffix to save features to
%   (datasetname_outlabel.mat)
%   'filtFlag'      :   [0/1] 1: filter data [1 70] bandpass, [58 62]
%   bandstop
%   'filtCheck'     :   [0/1] 1: Plot data before and after filtering for
%   one block for manual checking
%Output:
%   'feat'          :   Calculated feature for each window
params.feature = 'll';
params.winLen = 2*60*60;
params.filtFlag = 0;
params.diag = 0;
params.blockLen = 4*60*60;
params.saveLabel = 'LL2hr'
params.channels = 1:16;
% 
% switch params.label
% case 'spike'              % spike-threshold
%   switch params.technique
%     case 'threshold'
%       params.blockDur = 1;  % hours; amount of data to pull at once
%   end
% case 'burst'
%   switch params.technique
%     case 'linelength'     % burst-linelength
%       params.function = @(x) sum(abs(diff(x))); % sum(x.*x); % feature function
%       params.windowLength = 1;         % sec, duration of sliding window
%       params.windowDisplacement = 0.5;    % sec, amount to slide window
%       params.blockDurHr = 1;            % hours; amount of data to pull at once
%       params.smoothDur = 0;   % sec; width of smoothing window
%       params.minThresh = 2e5;    % X * stdev(signal); minimum threshold to detect burst; 
%       params.minDur = 2;    % sec; min duration of the seizures
%       params.addAnnotations = 1; % upload annotations to portal
%       params.viewData = 1;  % look at the data while it's running?
%       params.saveToDisk = 0;  % save calculations to disk?
%   end
% case 'seizure'
%   switch params.technique
%     case 'energy'     % seizure-area
%       params.function = @(x) sum(x.*x); % feature function
%       params.windowLength = 2;         % sec, duration of sliding window
%       params.windowDisplacement = 1;    % sec, amount to slide window
%       params.blockDurHr = 1;            % hours; amount of data to pull at once
%       params.smoothDur = 30;   % sec; width of smoothing window
%       params.minThresh = 15e8;    % X * stdev(signal); minimum threshold to detect burst; 
%       params.minDur = 10;    % sec; min duration of the seizures
%       params.addAnnotations = 1; % upload annotations to portal
%       params.viewData = 0;  % look at the data while it's running?
%       params.saveToDisk = 0;  % save calculations to disk?
%   end
% end


