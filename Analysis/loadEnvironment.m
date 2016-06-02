function [session, dataKey] = loadEnvironment(session, parameters)
    %	Usage: [dataKey, params, featFn] = loadEnvironment(params);
    % Should be called by analyzeDataOnPortal.m
    %	
    %	loadEnvironment() will load user specific information for the
    %	IEEG Pipeline.
    %
    % Input:
    %   params		-	a structure containing at least the following:
    %     params.homeDirectory: eg '~\MATLAB\', a string indicating the home
    %       directory for Matlab.  This directory should include subdirectories
    %       - 'P06-Pipeline' - contains the IEEG pipeline code
    %       - 'P0X-Name-data' - study-specific directory (params.runDir below).
    %         This directory should include the following files:
    %           f_XXXX_dataKey, where XXXX = params.study
    %           f_XXXX_params
    %           f_XXXX_defineFeatures
    %       - 'ieeg-matlab-X.X' - latest version of the IEEG Toolbox, available
    %         here: https://code.google.com/p/braintrust/wiki/Downloads
    %
    % Output:
    %   dataKey - a table with subject index, portal ID, and other info
    %   params  - params structure with applicable fields added to it
    %   featFn  - a cell of feature functions for clustering/classification
    %
    % Jason Moyer 7/20/2015 
    % University of Pennsylvania Center for Neuroengineering and Therapeutics
    %
    % History:
    % 7/20/2015 - v1 - creation
    %.............

    % dbstop in loadEnvironment at 58;
    % set paths
    % load session
    % load .csv

    % add path for IEEG toolbox
    addpath(genpath(parameters.IEEGInfo.toolboxPath));
    
    % add eegpipeline/Analysis to path
    addpath(genpath(parameters.analysisPath));

    % load .csv file with dataKey for study
    % dataKey is a table linking portalID to indices, rat name, etc
    dataKey = readtable(parameters.DatasetInfo.datakeyFile);
      
    parameters.InitialDetection.default.function = ...
      @(x) (sum(abs(diff(x)))); % default feature function
    parameters.InitialDetection.default.minDuration = 5; % sec; default min duration of detection
    parameters.InitialDetection.default.maxDuration = 100; % sec; default min duration of detection
    parameters.InitialDetection.default.minThreshold = 3e2; % default min threshold for detection
    parameters.InitialDetection.default.maxThreshold = ...
      4 * parameters.InitialDetection.default.minThreshold; % default max threshold for detection
    parameters.InitialDetection.default.windowLength = 2; % sec, default duration of sliding window
    parameters.InitialDetection.default.windowDisplacement = 1; % sec, default amount to slide window
    parameters.InitialDetection.default.smoothDur = 5; % sec; default width of smoothing window

    % Establish IEEG Portal sessions.  Constantly clearing and reestablishing
    % sessions will eventually cause an out of memory error, so a better way to
    % do it is to only clear and reload if runThese changed.
    % First, load session if it doesn't exist.
    if isempty(session)  % load session if it does not exist
        animalIdx = parameters.DatasetInfo.animalsToRun(1);
        session = IEEGSession(dataKey.Portal_ID{animalIdx}, ...
            parameters.IEEGInfo.userName,...
            parameters.IEEGInfo.credentialsFile);
        for animalIdx = 2:length(parameters.DatasetInfo.animalsToRun)
            session.openDataSet(dataKey.Portal_ID{animalIdx});
        end
    else    % clear and throw exception if session doesn't have the right datasets
        if (~strcmp(session.data(1).snapName, ...
          dataKey.Portal_ID(parameters.DatasetInfo.animalsToRun(1)))) || ...
          (length(session.data) ~= length(parameters.DatasetInfo.animalsToRun))
            session = [];
            warning off;
            session = loadEnvironment(session, parameters);
            warning on;
        end
    end
end

