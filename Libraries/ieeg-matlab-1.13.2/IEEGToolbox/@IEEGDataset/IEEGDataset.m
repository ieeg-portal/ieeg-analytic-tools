classdef (Sealed) IEEGDataset < IEEGObject
  % IEEGDATASET  Class representing a set of Timeseries 
  %
  %   TODO: It is currently not possible to get multichannel data from
  %   datasets with various sampling rates. This should be fixed.
  
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
  
  properties (SetAccess = private)
    snapName      = '';
    
    
    montage    = IEEGMontage.empty
  end
  
  properties (Access = private)
    ts
    snapID        = '';
    filterOrder   = nan;
    filterWn      = nan;
    filterType    = '';
    filterA       = [];
    filterB       = [];
    resampleRate  = nan;    
  end
  
  properties (Dependent = true)
    filter     = '';
    resample   = '';
    sampleRate = [];
    values     = [];
    channelLabels = {};  % Labels as set by montage or 'As Recorded'
  end
  
  properties (SetAccess = private)
    annLayer = [];
    rawChannels = IEEGTimeseries.empty;
    allMontages = IEEGMontage.empty;
    
  end
  
  methods(Access = protected, Sealed = true)
    function info = specialPropsInfo(obj) 
      info = struct('name','values',...
        'size',[nan nan], 'format', 'Unknown','toString','');
      
      %Check size of all TimeSeries Objects
      indSize = struct('name','','size',[], 'format', '');
      for i = 1 : length(obj.rawChannels)
        indSize(i) = specialPropsInfo(obj.rawChannels(i));
      end
      
      iLength = [indSize.size];
      iLength = iLength(1:2:end);
      
      if ~isempty(obj.montage)
        if all(iLength(1)==iLength)
          info.size = [iLength(1) length(obj.montage.pairs) ];
        else
          info.size = [-1 length(obj.montage.pairs)  ];
        end
      else
        if all(iLength(1)==iLength)
          info.size = [iLength(1) length(iLength) ];
        else
          info.size = [-1 length(iLength) ];
        end
      end
      
      
      indFormat = {indSize.format};
      if all(strcmp(indFormat{1},indFormat))
        info.format = indFormat{1};
      else
        info.format = 'Various';
      end
      
      info(2) = struct('name','montage',...
        'size',[nan nan], 'format', 'String', 'toString','');
      
      if ~isempty(obj.montage)
        info(2).toString = obj.montage.name;
      else
        info(2).toString = 'As Recorded';
      end
      
    end

  end
  
  methods(Access = private, Sealed = true)
    function populate_timeseries(obj) 
      obj.rawChannels(obj.ts.size) = IEEGTimeseries();
      detailIterator = obj.ts.iterator;
      ix = 0;
      while detailIterator.hasNext
        ix = ix +1;
        obj.rawChannels(ix) = IEEGTimeseries(detailIterator.next, obj);
        setparent(obj.rawChannels(ix), obj);
      end        
    end
    
    function [values,x] = getdatablock(obj, startIndex, blockLength, chIdx)
      
      % This method assumes that all sampling rates are equal for the
      % requested channels. This is enforced by the GETVALUES method.
      sampleRate = obj.rawChannels(chIdx(1)).sampleRate;
      
      try
        tsi =  obj.getTSI;
      catch ME
        error('IEEGTimeseries not instantiated by IEEGDataset');
      end
      
      assert(startIndex >=0,'StartIndex has to be greater of equal to zero.');
      assert(blockLength > 0, 'BlockLenght has to be greater than zero.');
      assert(min(chIdx) >= 1 && max(chIdx) <= size(obj.channelLabels,1),...
        'Channel Indeces out of range.');
      
    
      % GET UNIQUE CHANNELS FOR MONTAGE
      if ~isempty(obj.montage)
        curMontageCh = obj.montage.channelMap(chIdx,:);
        uniqueIdx = unique(curMontageCh);
      else
        uniqueIdx = chIdx;
      end
      
    
      %Get channelIds  
      
      revIDchID = java.util.ArrayList;
      for i = 1:length(uniqueIdx)
        tsDetails = obj.rawChannels(uniqueIdx(i)).get_tsdetails;

        curRevIDchID = edu.upenn.cis.db.mefview.services.TimeSeriesIdAndDCheck(...
          tsDetails.getRevId(), tsDetails.getDataCheck());
        revIDchID.add(curRevIDchID);
      end
            
      % If Filter > grab 1 extra second at beginning if possible:
      if ~isnan(obj.filterOrder) || ~isnan(obj.resampleRate)
        offset = 1e6;
        if startIndex - offset >= 0
          startIndex = startIndex - offset;
          blockLength = blockLength + 2 * offset;
        else
          offset = startIndex;
          startIndex = 0;
          blockLength = blockLength + 2 * offset;
        end
      else
        offset = 0;
      end
      
      %Make List of TimeSeriesIdAndVer
      seriesListOfLists = tsi.getUnscaledTimeSeriesSetRaw(obj.snapID,... 
        revIDchID, startIndex, blockLength, 1);
         
      
      % Get the data series segments associated with the each channel.
      for iChannel = 1:length(uniqueIdx)

        seriesList = seriesListOfLists(iChannel);
        firstSeries = seriesList(1);

        % On first iteration, create full array for returned values and find the
        % scalefactor.
        if iChannel==1
          values = zeros(firstSeries.getSeriesLength, length(uniqueIdx));
          x = startIndex + (0:(firstSeries.getSeriesLength-1)) * ...
            (1e6/sampleRate);
        end

        values(:, iChannel) = double(firstSeries.getSeries()) * firstSeries.getScale();

        % Set values to NaN if they are in a gap --> webservice returns 0
        gStart = firstSeries.getGapsStart();
        gEnd   = firstSeries.getGapsEnd();
        for i = 1: length(gStart)
            startInx = gStart(i);
            % The gap end is actually 1 more than the last item
            endInx = gEnd(i);
            assert(endInx > startInx, 'Gap End is before Gap Start.');
            values((startInx+1):endInx, iChannel) = NaN;

        end
      end
      
      % MONTAGE DATA
      if ~isempty(obj.montage)
        montValues = zeros(size(values,1), length(chIdx));
        for i=1:length(chIdx)
          montValues(:,i) = values(:,find(chIdx(i) == uniqueIdx,1));
          if curMontageCh(i,1) ~=  curMontageCh(i,2)
            montValues(:,i) = montValues(:,i) - values(: , find(curMontageCh(i,2) == uniqueIdx,1));
          end
        end
        values = montValues;
      end
      
      
      % FILTER data if needed
      if ~isnan(obj.filterOrder)
        values = filterData(obj,values );
      end
      
      % RESAMPLE data if needed
      if ~isnan(obj.resampleRate)
        [resvalues, x] = resample(values, obj.resampleRate, round(sampleRate));
        values = resvalues;
        x = 1e6*x + startIndex + offset;
        if isvector(values)
            values = values(:);
        end
      end
      
      % TRIM offset added for filtering...
      if offset > 0
          display(sprintf('Offset: %f',offset));
          useSF = sampleRate;
          if ~isnan(obj.resampleRate)
              useSF = obj.resampleRate;
          end
          
          offsetValues = round(((offset/1e6) * useSF));
          values = values(offsetValues+1:end-offsetValues, :);
          x = x(offsetValues+1:end-offsetValues);
      end
      
      
    end
    
    function obj = populateObj(obj, tsi, newSnapID)
      % POPULATEOBJ  Populates the object with channels and annotations.
      %
      %   OBJ = POPULATEOBJ(OBJ, TSI, NEWSNAPID) is called by the
      %   constructor and the DERIVESNAPSHOT method of this class and
      %   populates the object with channels and annotations from the
      %   portal.
      
      % Add TimeSeriesDetails
      obj.ts = tsi.getDataSnapshotTimeSeriesDetails(newSnapID);
    
      % Add Timeseries objects.
      obj.rawChannels(obj.ts.size) = IEEGTimeseries();
      detailIterator = obj.ts.iterator;
      ix = 0;
      while detailIterator.hasNext
        ix = ix +1;
        obj.rawChannels(ix) = IEEGTimeseries(detailIterator.next, obj);
        setparent(obj.rawChannels(ix), obj);
      end   
      
      % Add Annotationlayers
      annDetails = tsi.getCountsByLayer(obj.snapID());
      annIterator = annDetails.getCountsByLayer.entrySet.iterator;
      newAnnArr(annDetails.size) = IEEGAnnotationlayer();
      ix = 0;
      while annIterator.hasNext
        ix = ix +1;
        curItem  = annIterator.next;
        curKey   = curItem.getKey;
        curValue = curItem.getValue;
        newAnnArr(ix) = IEEGAnnotationlayer(curKey, curValue, obj);
      end
      if ix>0
        obj.annLayer = newAnnArr;
      end
      
      % Add Montages
      montArray = tsi.getMontages(newSnapID);
      montIter = montArray.iterator;
      newMontArr(montArray.size) = IEEGMontage();
      ix = 0;
      while montIter.hasNext
          ix = ix +1;
          curM = montIter.next;
          newMontArr(ix) = IEEGMontage.build(curM, obj.rawChannels);
      end
      
      if ix>0
          obj.allMontages = newMontArr;
      end
      
    end
  end  
 
  methods
    function obj = IEEGDataset(varargin)
      %IEEGDATASET  Creates object of class IEEGDATASET.
      %
      % OBJ = IEEGDATASET('Name', SESSION) creates a new IEEGDATSET object
      % belonging to an IEEGSESSION object. A Dateset object can contain
      % multiple channels of data and multiple annotation layers. 
      %
      % OBJ = IEEGDATASET() returns an empty IEEGDATASET object.
      
      switch nargin
        case 0
          return
        case 2
          obj.snapName = varargin{1};
          setparent(obj, varargin{2});
        otherwise
          error('IEEGDATASET:IEEGDATASET',...
            'Incorrect number of input arguments for constructor.');
      end
      
      % Try to find snapID based on snapName.
      try        
        tsi = obj.getTSI;
        obj.snapID = char(tsi.getDataSnapshotIdByName(obj.snapName));
      catch ME
        if strfind(ME.message,'NoSuchDataSnapshot')
          throwAsCaller(MException('IEEGSession:init',...
            sprintf('No snapshot with name ''%s'' exists on portal.',...
            obj.snapName)));
        else
          rethrow(ME)
        end
      end
      
      % Add Timeseries objects.
      tsi = obj.getTSI;
      populateObj(obj, tsi, obj.snapID);   
          
    end
  
    function values = get.values(obj) %#ok<MANU,STOUT>
      throwAsCaller(MException('IEEGTimeseries:getvalues',...
        'Please use the GETVALUES method to request data.'));
    end
    
    function fs = get.resample(obj)
      if ~isnan(obj.resampleRate)
        fs = sprintf('%i Hz',obj.resampleRate);
      else
        fs = 'Not resampled';
      end
      
    end
    
    function filter = get.filter(obj)
      if ~isnan(obj.filterOrder)
        filter = sprintf('%i-th order, %s-pass, Wn=%f',...
          obj.filterOrder, obj.filterType, obj.filterWn);
      else
        filter = 'No Filter';
      end
    end
    
    function fs = get.sampleRate(obj)
      
      if isnan(obj.resampleRate)
        allSampleRate = [obj.rawChannels.sampleRate];
        if all(allSampleRate==allSampleRate(1))
          fs = allSampleRate(1);
        else
          fs = nan;
        end
      else
        fs = obj.resampleRate;
      end
    end
    
    function labels = get.channelLabels(obj)
        
        if isempty(obj.montage)
          labels = cell(length(obj.rawChannels),2);
          labels(:,1) = {obj.rawChannels.label};
        else
          pairs = obj.montage.pairs;
          labels = cell(length(pairs),2);
          for i=1: length(pairs)
            labels(i,:) = {pairs(i).source pairs(i).ref};
          end
          
          
        end
        
    end
    
  end
  
  methods (Sealed = true)
    function value = getsession(obj)
      %GETSESSION  Returns Session object associated with current obj.
      
      value = obj.session;      
    end
    
    function varargout = getvalues(obj, varargin)
      %GETVALUES  Requests data from the IEEG-Portal.
      %
      % VALUES = GETVALUES(OBJ, IDX, CHX) returns values associated with
      % object OBJ and IDX, where IDX is a 1xn vector of indeces and CHX is
      % a 1xn vector of channel indeces. The method assumes that the
      % timeseries are continuous and missing data are represented by Nans.
      %
      % VALUES = GETVALUES(OBJ, STARTTIME, BLOCKLENGTH, CHX) returns values
      % associated with the object OBJ, where STARTTIME is the time of the
      % first sample in usec, BLOCKLENGTH is the duration of the
      % requested data in usec, and CHX is a 1xn vector of channel indeces.
      %
      %
      % For example:
      %       values = obj.getvalues(1:1000, 1:4);
      %     which is the same as:
      %       values = getvalues(obj, 1:1000, 1:4);
      %
      %       values = obj.getvalues(0, 1e6, 1:4);
      
      switch nargin
        case 3
          % Assert that all requested channels have the same sampling
          % frequency.
          chIdx = varargin{2};
          
          % Catch ':' string
          if ischar(chIdx)
            assert(strcmp(chIdx,':'),'Incorrect input argument for CHIDX');
            chIdx = 1:length(obj.rawChannels);
          end
          
          allSampleRates = [obj.rawChannels.sampleRate];
          allReqSampleRate = allSampleRates(chIdx);
          
          assert(all(allReqSampleRate==allReqSampleRate(1)),...
            ['Requesting multiple channels simultaneously requires all '...
            'channels to have the same sampling frequency. Please '...
            'limit the channel selection to a subset with equal sampling '...
            'rates.']);
          
          tIdx = double(varargin{1});
          startIndex = floor((1e6*(tIdx(1)-1))./allReqSampleRate(1));
          blockLength = (1e6*(tIdx(end)-tIdx(1)+1))./allReqSampleRate(1);
          
          
          assert(all(chIdx>=1)&& all(chIdx<=length(obj.rawChannels)),...
            'Channel indeces out of range.');
          [values, time] = getdatablock(obj, startIndex, blockLength, chIdx);
          
          % Force the values to be equal length as requested vector. This
          % can differ by one value due to rounding errors.
          if isnan(obj.resampleRate)
            varargout{1} = values(1:length(varargin{1}),:);
            varargout{2} = time(1:length(varargin{1}));
          else
            varargout{1} = values;
            varargout{2} = time;
          end
          
        case 4
          startIndex = varargin{1};
          blockLength = varargin{2};
          
          chIdx = varargin{3};
          
          % Catch ':' string
          if ischar(chIdx)
            assert(strcmp(chIdx,':'),'Incorrect input argument for CHIDX');
            chIdx = 1:length(obj.rawChannels);
          end
          
          assert(all(chIdx>=1)&& all(chIdx<=length(obj.rawChannels)),...
            'Channel indeces out of range.');
          
          
          [varargout{1}, varargout{2}] = getdatablock(obj, startIndex, blockLength, chIdx);
          
        otherwise
          error('Incorrect number of input arguments.');
      end
      
%       assert(length(varargout{2}) == size(varargout{1},1),...
%         'Unequal size timestamps and data.');
    end
    
    function setResample(obj, fs)
      % SETRESAMPLE  Sets the desired resample rate.
      %
      %   SETRESAMPLE(OBJ, FS) sets the resample rate to FS (Hz). This
      %   should be lower than the original sampling rate of the signal.
      %   Setting the resample rate does not automatically include
      %   anti-aliassing. This should be set separately using the SETFILTER
      %   method.
      %
      %   -- In case of implementing an anti-aliassing filter --
      %   Because the maximum resulotion of the returned signal is
      %   23 bit, we recommend a antialiassing filter with a cutoff of 1/2
      %   the sample rate and a attenuation of greater than 300db at the
      %   nyquist rate. (This can be achieved using a 15-order butterworth
      %   filter at 0.5*nyquist).
      
      obj.resampleRate = fs;
    end
    
    function out = isResampled(obj)
      % ISRESAMPLED  Returns boolean that indicates if dataset is resampled.
      %   OUT = ISRESAMPLED(OBJ) returns boolean that indicates if the
      %   dataset is resampled.
      %
      %   see also: setResample, resetResample
      
      out = ~isnan(obj.resampleRate);
      
    end
    
    function removeMontage(obj)
      % REMOVEMONTAGE  Resets montage to view data "As Recorded"
      %   REMOVEMONTAGE(OBJ) resets the dataset view to "As Recorded". 
      %
      %   See also:
      %     IEEGDataset.setMontage
      
      obj.montage = IEEGMontage.empty;
    end
    
    function setMontage(obj, montage)
      % SETMONTAGE  Sets the montage for the current dataset.
      %   SETMONTAGE(OBJ, IEEGMontage) sets the current montage for this
      %   dataset to the IEEGMontage object. This changes the view of the
      %   data that is returned by getValues.
      %
      %   To remove a montage, call this method with an empty array or use
      %   the REMOVEMONTAGE method.
      %
      %   See also:
      %     IEEGDasaset.removeMontage
        
        if isempty(montage)
          obj.montage = IEEGMontage.empty;
          return
        end
      
        assert(~isempty(find(obj.allMontages==montage, 1)),...
        'Montage is not part of this dataset')
        
        obj.montage = montage;
    end
    
    function resetResample(obj)
      % RESETRESAMPLE  Removes resampling option
      %
      %   RESETRESAMPLE(OBJ) removes the resampling from the pipeline. The
      %   data will be returned with the original sampling frequency.
      
      obj.resampleRate = nan;
    end
    
    function setFilter(obj, n, Wn, type)
      % SETFILTER  Set filter parameters for this dataset.
      %
      %   SETFILTER(OBJ, N, WN, 'Type') constructs a constant phase
      %   butterworth filter which is applied to all subsequent data
      %   requests. N is the order of the filter and should be a multiple
      %   of 2. WN is the cutoff frequence of the filter in Hz. TYPE is one
      %   of 'low', 'high', 'stop'.
      %
      %   The filter is implemented using the FILTFILT method to remove
      %   pahse shifts. 
      %
      %   Slightly more data is requested from the portal to reduce
      %   filter settling times during each request.
      
      % Check if Toolbox exists
      v = ver;
      if ~any(strcmp('DSP System Toolbox', {v.Name}))
        fprintf(2, 'Matlab''s DSP System Toolbox is required for filtering\n');
        return
      end
      
      assert(ismember(type,{'low' 'high' 'stop'}),...
        'Filter type must be one of: ''low'', ''high'', ''stop''.');
      
      assert(min(Wn) > 0 && max(Wn) < obj.rawChannels(1).sampleRate/2,...
        'Cutoff freq must be between 0 and the nyquist-frequency of the data.');
            
      obj.filterOrder = n;
      obj.filterType = type;
      obj.filterWn = Wn /(obj.rawChannels(1).sampleRate/2);  
      
      [obj.filterB, obj.filterA ] = butter(obj.filterOrder,obj.filterWn,obj.filterType);
    end
    
    function resetFilter(obj)
      % RESETFILTER  Removes filter from data request pipeline.
      %
      %   RESETFILTER(OBJ) removes existing filter settings from the
      %   object.
      
      obj.filterOrder = nan;
      obj.filterType = '';
      obj.filterWn = nan;    
    end
    
    function h = filterSummary(obj)
      % FILTERSUMMARY  Displays filter-response curves.
      %
      %   H = FILTERSUMMARY(OBJ) displays the response curves of the
      %   applied filter. If the user has the "Matlab Signal Processing
      %   Toolbox", FVTOOL is used to display the data. Otherwise, FREQZ is
      %   used to display the data. The method returns the handle to the
      %   FVTOOL in case this is used, otherwise H is an empty array.
      %

      % Check if filter is set
      if isnan(obj.filterOrder)
        fprintf(2, 'No filter is set for this dataset.\n');
        return
      end
      
      % Check if Toolbox exists
      v = ver;
      if any(strcmp('Signal Processing Toolbox', {v.Name}))
        h = fvtool(obj.filterB,obj.filterA);
        set(h,'Fs',obj.rawChannels(1).sampleRate);
      else
        h= [];
        freqz(obj.filterB,obj.filterA);     
      end
      
    end
    
    function newLayer = addAnnLayer(obj, name)
      % ADDANNLAYER  Add new AnnotationLayer.
      %
      %   NEWLAYER = ADDANNLAYER(OBJ, 'name') adds a new annotation layer
      %   to the current object. The name of the layer must by unique for
      %   the dataset object.
      
      % Check if name already exists      
      if ~isempty(obj.annLayer)
        allLayerNames = {obj.annLayer.name};
        assert(~any(strcmp(name,allLayerNames)),...
          sprintf('Layer with name ''%s'' already exists.',name));
        newLayer = IEEGAnnotationlayer(name, obj);
        obj.annLayer = [obj.annLayer newLayer];
      else
        newLayer = IEEGAnnotationlayer(name, obj);
        obj.annLayer = newLayer;
      end
        
    end
    
    function snapID = getSnapID(obj)
      snapID = obj.snapID;
    end
    
    function obj = rename(obj, newName)
      % RENAME  Changes the name for the current object.
      %
      % OBJ = RENAME(OBJ, 'newName') changes the name of the snapshot
      % locally and on the server. The snapshotID remains the same. You can
      % only rename a snapshot if you are the 'owner' of the snapshot, which
      % usually means that you created the snapshot on the portal.
      %
      % If you are not the 'owner' of a snapshot and you try to rename the
      % snapshot, the method will throw an exception. If you want to create
      % your own snapshot based on the current object, use the
      % DERIVESNAPSHOT method. You will be able to specify the name of the
      % newly derived snapshot.
      %
      % see also: DERIVESNAPSHOT
      
      oldName = obj.snapName;
      assert(ischar(newName),'New Name must be a string.');
      tsi = obj.getTSI;
      
      try
        tsi.setDataSnapshotName(obj.snapID, oldName, newName);
        obj.snapName = newName;
      catch ME
        if strfind(ME.message,'AuthenticationFailure')
          throwAsCaller(MException('IEEGDATASET:RENAME',...
            'You are not authorized to change the name of this snapshot.'));
        elseif strfind(ME.message,'DuplicateLabel')
          throwAsCaller(MException('IEEGDATASET:RENAME',...
            'A snapshot with this label already exists, please choose another name.'));
        end
        
        rethrow(ME);
      end
      
    end
    
    function out = deriveDataset(obj, newName, varargin)
      %DERIVEDATASET  Returns new IEEGSession based on current object.
      %
      % OUT = DERIVEDATASET(OBJ, NEWNAME) derives a new snapshot based on
      % the current object and adds a new IEEGDataset object associated
      % with this new snapshot to the current IEEGSESSION. It creates a
      % snapshot that is identical to the snapshot associated with the
      % current object with the exception that the current user is owner of
      % the new snapshot. This allows the user to edit the contents of the
      % returned snapshot.
      %
      % OUT = DERIVEDATASET(OBJ, NEWNAME, TOOLNAME) creates a new snapshot
      % on the IEEG-Portal and adds a new IEEGDataset object associated
      % with this new snapshot to the current IEEGSESSION. NEWNAME is a
      % string identifying the new snapshot and TOOLNAME is a string
      % identifying the tool that is associated with this snapshot.The
      % TOOLNAME can be used to identify the code on the IEEG-Portal that
      % was used with this snapshots to generate results, or identify the
      % type of analysis-results that is stored in this snapshot.
      %
      % OUT = DERIVEDATASET(..., CHANNELS) derives a new snapshot with a
      % subset of the channels of the current snapshot. CHANNELS is a 1xn
      % array with IEEGCHANNEL objects that should be included in the new
      % snapshot. The IEEGCHANNEL objects must be present in the current
      % IEEGDATASET object.
      %
      % For example:
      %       inclCh = obj.rawChannels([1 3 5 7])
      %       newDataset = obj.deriveDataset('newDatasetName', inclCh);
      %
      
      
     
      narginchk(2, 4);    % Check number of arguments.      
      
      newSnapID = '';
      tsi = obj.getTSI;
      toolName = ' ';
      switch nargin
        case 2
          % Get new TSDetails
          try
            newSnapID = tsi.deriveDataSnapshot(newName, ...
              obj.snapID, toolName);
          catch ME
            if isa(ME.ExceptionObject,...
                'edu.upenn.cis.db.mefview.services.IeegWsRemoteAppException')
              errorCode = ME.ExceptionObject.getErrorCode;
              switch char(errorCode)
                case 'DuplicateName'
                  throwAsCaller(MException('IEEGDATASET:DERIVESNAPSHOT',...
                    'A snapshot with this label already exists, please choose another name.'));
                otherwise
                  rethrow(ME);
              end
              
            else
              
            rethrow(ME);
            end
          end
        case 3

          % Determine if 3rd input is toolname or channels.
          switch class(varargin{1})
            case 'IEEGTimeseries'
              newSnapID = '';
              newCh = varargin{1};
            case 'char'
              try
                newSnapID = tsi.deriveDataSnapshot(newName, ...
                  obj.snapID, toolName);  
              catch ME
                if isa(ME.ExceptionObject,...
                    'edu.upenn.cis.db.mefview.services.IeegWsRemoteAppException')
                  errorCode = ME.ExceptionObject.getErrorCode;
                  switch char(errorCode)
                    case 'DuplicateName'
                      throwAsCaller(MException('IEEGDATASET:DERIVESNAPSHOT',...
                        'A snapshot with this label already exists, please choose another name.'));
                    otherwise
                      rethrow(ME);
                  end

                else

                rethrow(ME);
                end
              end
            otherwise
              error('Unsupported input argument.')
          end
        case 4
          assert(isa(varargin{2},'IEEGTimeseries'),...
            'Incorrect input argument.');
          assert(ischar(varargin{1}),...
            'Incorrect input argument.');
          newCh = varargin{2};
          toolName = varargin{1};
      end
  
      % If no TSDetails defined now, get TSDetails, with tool and channels.
      if isempty(newSnapID)
        allInDataset = obj.rawChannels;
        assert(all(ismember(newCh,allInDataset)), ...
          'The supplied channels should all be present in the current dataset');

        chIds = cell(1, length(newCh));
        for i = 1: length(chIds)
          chIds{i} = char(newCh(i).get_tsdetails.getRevId);
        end

        try
          newSnapID = tsi.deriveDataSnapshot(newName, chIds, ...
            obj.snapID, toolName);  
        catch ME
         if isa(ME.ExceptionObject,...
              'edu.upenn.cis.db.mefview.services.IeegWsRemoteAppException')
            errorCode = ME.ExceptionObject.getErrorCode;
            switch char(errorCode)
              case 'DuplicateName'
                throwAsCaller(MException('IEEGDATASET:DERIVESNAPSHOT',...
                  'A snapshot with this label already exists, please choose another name.'));
              otherwise
                rethrow(ME);
            end

          else

          rethrow(ME);
          end
        end
      end
      
      % Create new Dataset obj.
      newD = IEEGDataset(newName, obj.up);
      newD = populateObj(newD, tsi,newSnapID);
      
      % Add new Dataset to current session
      session = obj.up;
      openDataSet(session,newD);
      
      % Return Session
      out = session.data(end);
      
    end
    
    function obj = removeAnnLayer(obj, annLayerName)
      %REMOVEANNLAYER  Removes layer and annotations from Dataset.
      % 
      % OBJ = REMOVEANNLAYER(OBJ, 'AnnotationLayerName') removes the
      % annotationlayer with the specified name from the dataset. This
      % deletes all the annotations in the layer on the portal. Be carefull
      % using this method as the results cannot be undone.
      
      % Check that AnnotationLayer exists in Dataset
      if ~isempty(obj.annLayer)
        allLayerNames = {obj.annLayer.name};
        layerIdx = find(strcmp(annLayerName,allLayerNames),1);
        assert(~isempty(layerIdx),...
          sprintf('Layer with name ''%s'' does not exist in Dataset.',...
          annLayerName));
      end
      
      % Delete annotations from layer if not empty
      if getNrEvents(obj.annLayer(layerIdx)) > 0
        tsi = obj.getTSI;
        tsi.removeTsAnnotationsByLayer(obj.snapID, annLayerName);
      end
      
      % Remove layer from Dataset object
      obj.annLayer(layerIdx) = [];
      
    end
    
  end
    
  methods (Access = private)
    function out  = filterData(obj, data)
      % FILTERDATA filters data
      
      % Limitations:
      % 1) assumes that nans are on all channels. 
      % 2) Set nans to mean
      

      isnandata = isnan(data(:,1));
      data(isnandata,:) = repmat(nanmean(data), length(find(isnandata)),1);
      out = filtfilt(obj.filterB, obj.filterA, data);
      out(isnandata,:) = nan;
      
    end

  end
  
end
