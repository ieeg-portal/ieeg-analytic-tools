classdef (Sealed) IEEGSession < IEEGObject
  %IEEGSESSION  IEEG-Portal class that contains session information.
  %
  % OBJ = IEEGSESSION('SnapshotName', 'userName', 'pwdFile') initiates
  % an IEEG-Portal session and provides access to the snapshot with
  % name 'SnapshotName'. The 'userName' and 'pwdFile' are used to
  % authenticate the user on the portal. See CREATEPWDFILE method for
  % instructions on how to create a password-file. 
  %
  % OBJ = IEEGSESSION(... SERVER) allows the user to use a different server
  % for access. Options include 'ieeg.org', 'qa', and 'local'. This option
  % should only be used by IEEG-Portal developers.
  %
  % For example:
  %       out = IEEGSession('I001_P034_D01', 'userName', '/pwdfile.bin');
  %
  % see also: IEEGSession.createPwdFile

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Copyright 2013 Trustees of the University of Pennsylvania
  % 
  % Licensed under the Apache License, Version 2.0 (the "License");
  % you may not use this file except in compliance with the License.
  % You may obtain a copy of the License at
  % 
  % http://www.apache.org/licenses/LICENSE-2.0
  % 
  % Unless required by applicable law or agreed to in writing, software
  % distributed under the License is distributed on an "AS IS" BASIS,
  % WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  % See the License for the specific language governing permissions and
  % limitations under the License.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  properties (Access = private)
    tsi
    password      = '';
    isActive      = false;
    useServer     = 'ieeg.org';
    isSecure      = true;
    context       = '';
    pwdFile       = '';
  end

  properties (Dependent, SetAccess = private)
    server        = ''
  end
  
  properties (SetAccess = private)
    userName      = '';
    % meta          = 'Not_Implemented';
    data          = IEEGDataset;
  end
  
  properties(Constant, Access = private)
    serverUrl     = 'https://www.ieeg.org/services'; 
    QAserverUrl   = 'https://view-qa.elasticbeanstalk.com/services';
    localServerUrl  = 'http://localhost:8080/ieegview/services/';
  end

  methods
    function value = get.server(obj)
      value = obj.useServer;
    end
  end
    
  methods (Sealed = true)
    function obj = IEEGSession(varargin)
      %IEEGSESSION  Creates an object of class IEEGSESSION.
      %
      % OBJ = IEEGSESSION('SnapshotName', 'userName', 'pwdFile') initiates
      % an IEEG-Portal session and provides access to the snapshot with
      % name 'SnapshotName'. The 'userName' and 'pwdFile' are used to
      % authenticate the user on the portal. See CREATEPWDFILE method for
      % instructions on how to create a password-file. 
      %
      % OBJ = IEEGSESSION(..., SERVER) allows the user to use a different
      % server for access. Options include 'prod', 'qa', and 'local'. This
      % option should only be used by IEEG-Portal developers.
      %
      % For example:
      %       out = IEEGSession('I001_P034_D01', 'userName', '/pwdfile.bin');
      %
      % see also: IEEGSession.createPwdFile
      
      switch nargin
        case 0
          return
        case 3
          snapName = varargin{1};
          obj.userName = varargin{2};
          obj.pwdFile = varargin{3};
          url = [IEEGSession.serverUrl];
        case {4,5}
          snapName = varargin{1};
          obj.userName = varargin{2};
          obj.pwdFile = varargin{3};
          assert(ischar(varargin{4}), ...
            'Input SERVER needs to be one of: ''ieeg.org'', ''qa'', or ''local''.');
                    
          switch varargin{4}
            case 'ieeg.org'
              obj.useServer = 'ieeg.org';
              url = [IEEGSession.serverUrl];
            case 'qa'
              obj.useServer = 'qa';
              url = [IEEGSession.QAserverUrl]; 
            case 'local'
              obj.useServer = 'local';
              url = [IEEGSession.localServerUrl]; 
            otherwise
              error('Incorrect input argument.');
          end

      end
                  
      % Include JAVA libraries etc.
      version = IEEGSession.ieegsetup();
      
      % Get password. This method only provides a way to create an
      % IEEGSession without having to type in the password in the console.
      % The password is not encrypted on disk.
      h = fopen(obj.pwdFile,'r');
      obj.password = fread(h,'*char');
      obj.password = obj.password';
      fclose(h);
      
      % All local passwords should be 'password'
      if strcmp(obj.useServer,'local')
        obj.password = 'password';
      end
            
      tsiPropertiesPath = fileparts(which('tsi.properties'));
      
      % Get TSI object
      try
        obj.tsi = edu.upenn.cis.db.mefview.services.TimeSeriesInterface.newInstance(url,...
          obj.userName,obj.password, tsiPropertiesPath);
      catch ME
          if isa(ME, 'matlab.exception.JavaException')
            if isa(ME.ExceptionObject,'edu.upenn.cis.db.mefview.internal.com.mongodb.MongoException$Network')
                switch ME.ExceptionObject.getCode
                    case -2
                        error(sprintf(['\nThe IEEG-Toolbox cannot connect to the MongoDB. '...
                        'Is MongoDB properly installed and running? '...
                        'You can disable the MongoDB by commenting out all entries in the tsi.properties file.'])) %#ok<SPERR>
                    otherwise
                        rethrow(ME)
                end
            else
                rethrow(ME);
          
            end
          else
              rethrow(ME);
          end
      end
        
        
      % Check version 
      if ~obj.tsi.isVersionOkay(version);
        fprintf(2,['\nWarning: A newer version of the IEEG-Toolbox exists. \n'...
          'Please download the latest version from www.ieeg.org to prevent errors.\n']);
      end
      
      % Add Dataset object.
      obj.data = IEEGDataset(snapName, obj);
              
    end
    
    function out = getTSIprop(obj)
      %GETJAVATSI  Returns associated Java TimeSeriesInterface object.
      %
      % OUT = GETJAVATSI(OBJ) returns the Java object that is used to to
      % access the IEEG-Portal webservices.

      out = obj.tsi;
    end
    
    function obj = openDataSet(obj, dataset)
      % OPENDATASET  Adds new dataset to current session.
      %
      %   OBJ = OPENDATASET(OBJ, 'SnapshotName') adds a new dataset to the
      %   current session. The 'SnapshotName' is a string that uniquely
      %   identifies a snapshot on the portal. If the snapshot exists, it
      %   is appended to the DATA property of the IEEGSESSION object.
      %
      %   OBJ = OPENDATASET(OBJ, DATASET) adds a new dataset to the current
      %   session. This methods is automatically called when you derive a
      %   new snapshot from another snapshot during this session. 
      %
      %   see also: IEEGDATASET.DERIVEDATASET
      
      switch class(dataset)
        case 'char'
          for i = 1: length(obj.data)
            if strcmp(obj.data(i).snapName, dataset)
              warning('Cannot add IEEGDATASET object that already exists in current session.')
              return
            end
          end
          newDS = IEEGDataset(dataset, obj);
        case 'IEEGDataset'
          % check if dataset is already present in session.
          for i = 1: length(obj.data)
            if strcmp(obj.data(i).snapName, dataset.snapName)
              warning('Cannot add IEEGDATASET object that already exists in current session.')
              return
            end
          end
          newDS = dataset;
        otherwise
          error('Incorrect input argument for DATASET.');
      end
    
      obj.data = [obj.data newDS];
       
    end
  end
  
  methods(Static, Sealed = true)
    function varargout = createPwdFile(username, password, varargin)
      %CREATEPWDFILE  Creates a pwd-file to be used with the IEEG Portal
      %   PATH = CREATEPWDFILE('username', 'password') create a pwd-file that is used
      %   by the IEEG Toolbox to connect to the IEEG portal. The method returns the
      %   full path to the created file.
      %
      %   PATH = CREATEPWDFILE('username', 'password', 'filename') does the same thing
      %   but uses the provided filename instead of using a UI to select a
      %   file-name.
      %
      %   !! The implementation of this code is not in any way secure as the
      %   password is still stored as a string and loaded into matlab during the
      %   IEEGCONNECT method.  However, it provides a simple solution to access the
      %   password without having to specify the password in any scripts or having
      %   to supply the password in a user interface in Matlab. This makes it
      %   unlikely that the password is accidentally shared when tools are uploaded
      %   to the portal.
      %

      try
        switch nargin
          case 2
            % Append default filename with partial username. If username is too
            % short, do not append filename.
            if length(username) < 4
              appFileName = '';
            else
              appFileName = [username(1:3) '_'];
            end

            defaultName = sprintf('%sieeglogin.bin',appFileName);
            [fileName, pathName, ~] = uiputfile('*.*', ...
              'Select a location to save the password file',defaultName);

            filePath = fullfile(pathName, fileName);
          case 3
            assert(ischar(varargin{1}),'IEEGPWDFILE: Incorrect input argument.');
            [pathName, fileName, ext] = fileparts(varargin{1});

            if isempty(pathName); pathName = pwd; end
            assert(exist(pathName,'dir')==7,...
              'IEEGPWDFILE: The supplied path does not exist.');

            filePath = fullfile(pathName, [fileName ext]);
          otherwise
            error('IEEGPWDFILE:INPUT',['IEEGPWDFILE: Incorrect number of '...
              'input arguments.']);
        end

        % Write the password as a binary to file.
        fid = fopen(filePath,'w');
        fwrite(fid, password);
        fclose(fid);    
        fprintf(2,'-- -- IEEG password file saved -- --\n');

        % Define output of method if requested.
        if nargout
          varargout = {filePath};
        else
          varargout = {};
        end

      catch ME
        throwAsCaller(ME)
      end

    end
  end
  
  methods (Static, Access = private, Sealed = true)
    function version = ieegsetup() 
      %IEEGSETUP  Initializes the IEEG-Toolbox.
      %
      % This method adds the java classes to the java-path in Matlab.

        if com.mathworks.mlwidgets.html.HTMLPrefs.getUseProxy()
            proxyHost = com.mathworks.mlwidgets.html.HTMLPrefs.getProxyHost();
            proxyPort = com.mathworks.mlwidgets.html.HTMLPrefs.getProxyPort();
            display(['IEEGSETUP: Using MATLAB configured proxy [' char(proxyHost) ':' char(proxyPort) ']']);
            java.lang.System.setProperty('http.proxyHost', proxyHost);
            java.lang.System.setProperty('http.proxyPort', proxyPort);
        end
      
        thisFile = mfilename('fullpath');
        [toolboxDir, ~, ~] = fileparts(thisFile);
        toolboxDir =  fileparts(toolboxDir);
        ieegjar = strcat(toolboxDir, '/lib/ieeg-matlab.jar');

        display('IEEGSETUP: Adding ''ieeg-matlab.jar'' to dynamic classpath');
        javaaddpath(ieegjar);

        jpath = javaclasspath('-all');
        foundLog4j = false;
        for i=1:size(jpath, 1);
            jar = jpath{i};
            idx = strfind(jar, strcat(filesep, 'log4j'));
            if ~isempty(idx)
                display('IEEGSETUP: Found log4j on Java classpath.');
                foundLog4j = true;
                break;
            end;
        end;
        if (~foundLog4j)
            log4jjar  = strcat(toolboxDir, '/lib/log4j.jar');
            display('IEEGSETUP: Adding ''log4j.jar'' to dynamic classpath');
            javaaddpath(log4jjar);
        end;

      java.lang.Thread.currentThread.setContextClassLoader(edu.upenn.cis.db.mefview.services.ClassLoaderHelper.getClassLoader)
      org.apache.log4j.LogManager.resetConfiguration
      org.apache.log4j.PropertyConfigurator.configure(strcat(toolboxDir, '/lib/log4j.properties'))
      
      % Get version of Toolbox
      versionFile = fullfile(toolboxDir,'lib','version');
      h = fopen(versionFile);
      version = strtrim(fscanf(h,'%c'));
      fclose(h);
      
    end
  end

end