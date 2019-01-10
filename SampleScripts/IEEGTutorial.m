%%
% IEEG PORTAL MATLAB TUTORIAL
%
% Classes:
% IEEGSession
% IEEGDataset
% IEEGTimeseries - connecting to a java class library (get_tsdetails)
% IEEGAnnotationLayer
%
% Several functions are also part of the custom matlab toolbox for
% IEEG available here: https://github.com/ieeg-portal/portal-matlab-tools

% add toolbox to Matlab's path to access functions
addpath(genpath('../'))

% Once you've signed up and have been approved on the ieeg.org website, you can establish a key that will give you access permissions to connect to our server and interact with datasets'
% This creates a .bin file that contains your login (unencrypted)
IEEGSession.createPwdFile('username','password')

%% ENTER OWN USERNAME AND PASSWORD FILE HERE
ieegUser = 'hoameng';
ieegPwd = 'hoa_ieeglogin.bin';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
% First, create an IEEGSession object, which is a Matlab class. This contains your login credentials a well as a dataset that you'd like to open.
session = IEEGSession('I004_A0003_D001',ieegUser,ieegPwd);
% note that many datasets follow the nomenclature of I*A/P*D, where 'I' indicates the institution id, 'A/P' indicates animal or patient, and 'D' indicates dataset number.

% View the contents of the IEEGSession object
session

%% Let's take a look at some of the dataset details
session.data

%get sample rate
fs = session.data.sampleRate

%show channels
%Each channel is an IEEGTimeseries object
session.data.rawChannels

%
session.data.rawChannels(1)

%You can also access more methods with the IEEGTimeseries object
session.data.rawChannels(1).methods

%get duration in usec. All times handled by the portal are in microseconds.
session.data.rawChannels(1).get_tsdetails.getDuration

% the getvalues method allows you to get data from a specified object.
%get first 100 values in channels 1 and 5
session.data.getvalues(1:100,[1 5]);

%you can also get values based on time:
startTime = 1e6
duration = 10e6
session.data.getvalues(startTime,duration,[1 5])

%% ANNOTATIONS
% In my opinion, annotation objects are an integral feature in working with the portal
% Annotations mark time and channels in each dataset, allowing you to identify important segments and quickly mark, extract, or process through them.or
% These annotations can also be created manually through the web interface, where I often have clinicians mark events that are meaningful.in


% Show annotation layer names
{session.data.annLayer.name}

%find 'Train' annotation layer
session.data.annLayer(1)

% grab 10 events.
% IEEGAnnotation methods:
startTime = 1
annotations = session.data.annLayer(1).getEvents(startTime,10)

%grab data of first event
data = session.data.getvalues(annotations(1).start/1e6*fs:((annotations(1).start)/1e6+30)*fs,1:16);

%plot first channel 
plot(data(:,1));

%% Utility functions
% Several Utility functions have been created and uploaded to the portal-matlab-tools 
% github. These functions are abstracted from common tasks that I have performed. This 
% includes getting extended datasets, retrieving all annotations, getting annotations

% Each call to getvalues has some overhead associated with contacting the server. 
% At times when you want to retrieve or operate on a lot of data, it may make sense 
% to simply load all of the data into ram. However, you cannot simply use a getvalues 
% call for the entire dataset (unless it is small enough). This is because there is a 
% hard limit on the number of sample points that are allowed to be sent. Try to get too 
% much, and it will fail. getExtendedData is simply a wrapper to getvalues to get all of the data
help getExtendedData

% To get all the values, use the getAllData function.
help getAllData

% Similarly, we have utility functions to interact with annotations
% getAllAnnots will retrieve all annotation objects as well as
% times/channels
[annotations, timesUSec, channels] = getAnnotations(session.data(1),'Seizures')

% uploadAnnotations will upload certain annotations to a given layer name
% on the Portal
help uploadAnnotations



%% Working with more than one dataset
% One of the benefits of the cloud is having a standard data format that
% faciliates automated or batch analysis. 
% Open another dataset using the session
session.openDataSet('I004_A0003_D001-TrainingAnnots')

% Now, look at the IEEGSession object
session

% Similarly, access each dataset object
session.data(1)
session.data(2)

%% Advanced
% Parallel processing, while not explicitly supported, also works.
datasetNames = {'I004_A0003_D001-TrainingAnnots','I004_A0003_D001-TestingAnnots'};
energyFeatures = cell(2,1);
parfor i = 1:2
    session = IEEGSession(datasetNames{i},ieegUser,ieegPwd);
    % do stuff
    tmp = session.data.getvalues(1:100,1);
    energyFeatures{i} = sum(tmp.^2)
    % 
end

%% Working with snapshots
% inclCh = session.data(1).rawChannels(1:16)
% session.data(1).deriveDataset('newDatasetName',inclCh)

%% Advanced
% 
session.data.methods
session.data(1).get_tsdetails.methods
session.data.setFilter
session.data.setResample



%% Conversion
session= IEEGSession('I004_A0003_D001',ieegUser,ieegPwd);
% Add MEF_writer java library
javaaddpath('DataConversion/java_MEF_writer/MEF_writer.jar')

% set mef params
mefGapThresh = 10000; % msec; min size of gap in data to be called a gap
mefBlockSize = 15; % sec; size of block for mefwriter to write

%% READ DATA
sampRange = [1 1000];
data = session.data.getvalues(sampRange(1):sampRange(2),1);
subjectID = 'IWSP7test'
fs = session.data.sampleRate

    %% open mef
mw = edu.mayo.msel.mefwriter.MefWriter([subjectID '.mef'], mefBlockSize, fs,mefGapThresh); %10000 samples

    %% write meta data to mef
    mw.setVoltageConversionFactor(1) % data * CF = uV
    mw.setSamplingFrequency(fs)
    mw.setInstitution('PENN')
    mw.setSubjectID(subjectID)
    mw.setChannelName('Channel 1')

    startuUTC = 1; %00:00:00 UTC on 1 January 1970
    
    startTimeUTC = startuUTC + sampRange(1)/fs*1e6;
    endTimeUTC = startuUTC + sampRange(2)/fs*1e6;

    % get timestamp, convert to uUTC
    ts = startTimeUTC:(1/fs)*1e6:endTimeUTC;
    mw.writeData(data(:,1), ts, length(data(:,1)));
    mw.close
    mw
    
 % IEEG CLI

%
