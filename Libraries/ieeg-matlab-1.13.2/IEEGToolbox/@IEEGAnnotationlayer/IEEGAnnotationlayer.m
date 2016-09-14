classdef IEEGAnnotationlayer < IEEGObject
  %IEEGANNOTATIONLAYER  Objects containing annotations for single layer. 
  %
  % Annotationlayer objects contain annotation objects belonging to a
  % single annotation layer.
  %
  % This class caches downloaded annotations in the private 'evntCache'
  % property. The class assumes that the annotations on the server are
  % static and will not function properly when annotations are added by an
  % external method/user to the dataset on the server. Use the
  % CLEAREVENTCACHE method to clear the cache. 
  %
  % The cache is automatically cleared if the GETEVENTS method is called
  % with a start-time outside the range of currently cached annotations or
  % when a different set of channels is requested. It is therefore best
  % practice to request annotations using the GETNEXTEVENTS and
  % GETPREVIOUSEVENTS.
  
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
    
  properties(SetAccess = private)
    name   ='' % Name of the Annotationlayer.
  end
  
  properties(Access = private)
    nrAnnotations = 0; % Total number of annotations for layer.
    chRange = [0 0]; % Period in usec for which events are cached. 
    evntCache  % Array of Annotations that are prevously downloaded.
  end
  
  properties (Dependent = true)
    evnts    % Array of IEEGAnnotation objs.
  end
  
  methods
    function values = get.evnts(obj) %#ok<MANU,STOUT>
      throwAsCaller(MException('IEEGAnnotationlayer:getevnts',...
        'Please use the GETEVENTS method to request data.'));
    end
  end
    
  methods (Sealed = true)
    function obj = IEEGAnnotationlayer(varargin)
      % IEEGANNOTATIONLAYER  Create annotation-layer object.
      %
      %   OBJ = IEEGANNOTATIONLAYER() returns an empty annotation object.
      %
      %   OBJ = IEEGANNOTATIONLAYER('Name', NRANNOTATIONS, PARENT)
      
      switch nargin
        case 0
          % Return empty layer.
          return
        case 1
          obj.name = varargin{1};
        case 2
          obj.name = varargin{1};
          setparent(obj, varargin{2});
        case 3
          % 
          obj.name = varargin{1};  
          obj.nrAnnotations = varargin{2};
          setparent(obj, varargin{3});
          
        otherwise
          error('Incorrect number of input arguments.');
      end
    end
            
    function obj = add(obj, annArray)
      %ADD  Adds one or more annotations to layer.
      %
      % OBJ = ADD(OBJ, ANNARRAY) adds all IEEGAnnotation objects in
      % ANNARRAY to the IEEGAnnotationlayer object. This method will
      % upload the annotations to the portal. It is therefore much more
      % efficient to add an array of annotations, rather than calling this
      % methods on multiple single annotation objects.
      
      
      import edu.upenn.cis.db.mefview.services.*;
      
      assert(isa(annArray,'IEEGAnnotation'),...
        'ANNARRAY has to be of class IEEGANOTATION.');
      assert(~isempty(obj.up),...
        ['You can only add annotations to an annotation-layer that ' ...
        'is associated with a dataset and session.']);
      assert(~isempty(obj.up.up),...
        ['You can only add annotations to an annotation-layer that ' ...
        'is associated with a dataset and session.']);
      
      % Assert that channels exist in TSI, compare revIDs not objects
      % because that is what matters. Correct way would be to implement
      % equals method for Timeseries object but this is too slow.
         
      % Get revIDS in Dataset
      allCh = obj.up.rawChannels;
      allRevIDs = allCh.getRevID;
      
      % Check if global 
      isGlobal = [annArray.isGlobal];
      assert(all(isGlobal) || all(~isGlobal),...
        ['You cannot add a mixed array of Global and Channel '...
          'specific annotations in the same call.']);
      
      if all(~isGlobal)
        % Get unique revIDS in added Annotations
        allChA = unique([annArray.channels]);
        allRevIDsA = allChA.getRevID;
        
        if ischar(allRevIDsA)
          assert(any(strcmp(allRevIDsA,allRevIDs)),...
              sprintf(['ANNARR contains channels that ' ...
              'are not present in the associated dataset.']));  
        else
          for iRev = 1: length(allRevIDsA)
            assert(any(strcmp(allRevIDsA(iRev),allRevIDs)),...
              sprintf(['ANNARR contains channels that ' ...
              'are not present in the associated dataset.']));  
          end
        end
      end

      
      % Upload annotations to portal.
      tsi = obj.getTSI;
      annotationList = tsi.createAnnotationList();
      annotator = obj.up.up.userName;
      nrAnns = length(annArray);
      
      for iAnn = 1: nrAnns
        if isnan(annArray(iAnn).stop)
          stopTime = annArray(iAnn).start;
        else
          stopTime = annArray(iAnn).stop;
        end
        
        
        ann = edu.upenn.cis.db.mefview.services.TimeSeriesAnnotation(...
          annotator, annArray(iAnn).start, stopTime,...
          annArray(iAnn).type, annArray(iAnn).description, obj.name);
        
        

        if isGlobal(iAnn)
          for i = 1: length(allCh)
            ann.addAnnotated(allCh(i).get_ts);
          end
        else
          for i = 1: length(annArray(iAnn).channels)
            ann.addAnnotated(annArray(iAnn).channels(i).get_ts);
          end
        end

        annotationList.add(ann);
      end
      
      snapID = obj.getSnapID;
      
      try
        tsi.addAnnotationsToDataSnapshot(snapID, annotationList);
      catch ME
        if isa(ME.ExceptionObject, 'edu.upenn.cis.db.mefview.services.IeegWsRemoteAppException')
          if strcmp(char(ME.ExceptionObject.getErrorCode),...
              'AuthorizationFailure')
            throw(MException('IEEGAnnotationlayer:ADD', ...
              ['You don''t have writing privileges for this dataset. '...
              'Please derive a snapshot from the dataset object before '...
              'you add annotations.']));
          else
            rethrow(ME);
          end
        else
         rethrow(ME);
        end 
      end
      
      % Clear cache to make sure that anns will be synced correctly.
      obj.clearEventCache;
      
      % Update number of annotations in current object.
      obj.nrAnnotations = obj.nrAnnotations + length(annArray);

      
    end
    
    function obj = remove(obj, annLayer) %#ok<INUSD>
      % REMOVE  Removes annotations from annotation layer.
      %   This method is currently not implemented. You can delete
      %   individual annotations within a layer using the web-console, or
      %   delete an entire layer using the REMOVEANNLAYER methods of the
      %   IEEGDATASET class.
      %
      %   see also: IEEGDataset.removeAnnLayer
      
      throwAsCaller(MException('IEEGAnnotationLayer:Remove',...
        ['This method is currently not implemented. Use the '...
        'REMOVELAYER method of the IEEGDATASET class to remove the entire '...
        'annotation layer, or delete individual annotations in the web-console.']))
      
    end
    
    function obj = clearEventCache(obj)
      %CLEAREVENTCACHE  Remove any downloaded annotations from cache.
      %
      % OBJ = CLEAREVENTCACHE(OBJ) removes any annotations that were
      % previously downloaded from the object's cache. This forces get
      % GETEVENT methods to download all the requested annotations from the
      % server.
      %
      % see also: GETPREVIOUSEVENTS, GETNEXTEVENTS, GETEVENTS
      
      obj.evntCache = IEEGAnnotation.empty;
      obj.chRange = [0 0];
    end
    
    function ann = getPreviousEvents(obj, annotation, varargin)
      %GETPREVIOUSEVENTS  Returns an array of events prior to an event.
      %
      % ANNARRAY = GETPREVIOUSEVENTS(OBJ, ANNOTATION) returns an
      % array of IEEGANNOTATION objects that precede the IEEGANNOTATION
      % object ANNOTATION. CHANNELS is an array of IEEGTIMESERIES objects.
      % Only annotations on the provided channels will be returned.
      %
      % ANNARRAY = GETPREVIOUSEVENTS(OBJ, STARTTIME) returns an
      % array of IEEGANNOTATION objects that precede the provided STARTTIME
      % in usec.
      %
      % ANNARRAY = GETPREVIOUSEVENTS(..., MAXNREVENTS) MAXNREVENTS can
      % manually be specified to change the maximum number of returned
      % objects. This number cannot exceed 100.
      %
      % The method returns an empty array of IEEGANNOTATION objects if
      % no annotations are available.
       
      DEFAULTMAX = 250;
          
      assert(nargin >= 2, 'Incorrect number of input arguments.');
      
      switch nargin
        case 2
          maxNrEvents = DEFAULTMAX;
        case 3
          if isnumeric(varargin{1}) && length(varargin{1})==1
            maxNrEvents = floor(varargin{1});
          else
            error('Incorrect arguments');
          end
        otherwise
         error('Incorrect arguments');
      end
      
      % Find starttime for annotation based on input argument.
      if isa(annotation, 'IEEGAnnotation')
        startTime = annotation.start;  
      elseif isnumeric(annotation) && length(annotation)==1
        startTime = annotation;
      else
        error('Incorrect input argument.');
      end
      
      
      % If no object exist in Cache, determine the overlap in chache with
      % requested annotations.
      if ~isempty(obj.evntCache)
          
          % Check if StartTime is within chached items
          if startTime >= obj.evntCache(1).start && ...
              (startTime <= obj.evntCache(end).start || obj.chRange(2)==-1)
            
            allTimes = [obj.evntCache.start];
            
            % First Ann outside range. Should always return a value,
            % because of if-statement above.
            cOffset = find(allTimes >= startTime, 1); 
            cLength = cOffset - 1 ; % Getting smaller than...
            
            % Check if all/no annotations are already in cache
            if cLength >= maxNrEvents 
              ann = obj.evntCache(cOffset-maxNrEvents:cOffset-1);
              return
            elseif cOffset == 1
              ann = IEEGAnnotation.empty;
            elseif obj.chRange(1) == 0
              ann = obj.evntCache(1:(cOffset-1));
              return
            end
            
          else
            % Start outside range --> Empty cache.
            obj.evntCache = IEEGAnnotation.empty;
            obj.chRange = [0 0];
            cLength = 0;
          end
      else
        % Cache is empty, but chRange and chCache could still be populated.
        cLength = 0;
      end
      
      % -- Need to download one/more annotations --
      
      % Get TSI Object, SNAPID, and TimeSeries
      tsi     = obj.getTSI;
      snapID  = obj.getSnapID;
      
      nrAnnFromServer = maxNrEvents - cLength;
      assert(nrAnnFromServer <= 1000,...
            ['Maximum number of returned annotations from '...
            'server in single call is 1000.']);
      
      % Using StartTime in usec.
      annotations = tsi.getTsAnnotationsLtStartTime(snapID, ...
        startTime, obj.name, cLength, nrAnnFromServer);

      if annotations.size > 0
        ann(annotations.size) = IEEGAnnotation();
        annIterator = annotations.iterator;

        ix = 0;
        while annIterator.hasNext
          ix = ix +1;
          ann(ix) = IEEGAnnotation.createFromWebservice(annIterator.next, obj); %#ok<AGROW>
        end
        
        % Reverse ann-vector
        ann = ann(ix:-1:1);
      else 
        ann = [];
      end
      
      % Set/Add to cache
      if all(obj.chRange == 0) %Cache does not exist.
        obj.evntCache = ann;
        obj.chRange = double([ann(1).start ann(end).start]);
      elseif ~isempty(ann) % Chache exists, add and chance range.
        obj.evntCache = [ann obj.evntCache ];
        ann = obj.evntCache(1 : cLength + length(ann));
        obj.chRange(1) = double(ann(1).start);
      end

      % Set CachedRange to end of file if no more ann on server.
      if length(annotations) < (maxNrEvents - cLength)
        obj.chRange(1) = 0;
      end
      
    end
    
    function ann = getNextEvents(obj, annotation, varargin)
      %GETNEXTEVENTS  Returns an array of events following an event.
      %
      % ANNARRAY = GETNEXTEVENTS(OBJ, ANNOTATION) returns an
      % array of IEEGANNOTATION objects that follow the IEEGANNOTATION
      % object ANNOTATION. 
      %
      % ANNARRAY = GETNEXTEVENTS(..., MAXNREVENTS) MAXNREVENTS can
      % manually be specified to change the maximum number of returned
      % objects. This number cannot exceed 100.
      % 
      % The method returns an empty array of IEEGANNOTATION objects if
      % no annotations are available.
      
      assert(isa(annotation,'IEEGAnnotation'),...
        'ANNOTATION needs to be of class IEEGANNOTATION.');
      assert(nargin >= 2, 'Incorrect number of input arguments.');

      DEFAULTMAX = 250;
            
      switch nargin
        case 2
          maxNrEvents = DEFAULTMAX;
        case 3
          if isnumeric(varargin{1}) && length(varargin{1})==1
            maxNrEvents = floor(varargin{1});
          else
            error('Incorrect input argument.');
          end
        otherwise
          error('Incorrect input arguments.');
      end
            
      if ~isempty(obj.evntCache)
         
          % Check if annotation exists in cache.
          cacheIdx = find(annotation == obj.evntCache, 1);
          if ~isempty(cacheIdx)
            
            cOffset = cacheIdx + 1;
            cLength = length(obj.evntCache) - cOffset + 1;
            
            % Check if number of annotations are already in cache
            if cLength >= maxNrEvents
              ann = obj.evntCache(cOffset:cOffset+maxNrEvents-1);
              return
            elseif obj.chRange(2) == -1
           
              % All annotations are already downloaded
              if cOffset < length(obj.evntCache)
                % return annotations if cOffset is not end of cache.
                ann = obj.evntCache(cOffset:end);
              else
                % Return empty if trying to get ann. outside cache.
                ann = [];
              end            
              
              return
            end
            
          else
            % Annotation not in cache --> Empty cache.
            obj.evntCache = IEEGAnnotation.empty;
            cLength = 0;
            obj.chRange = [0 0];
          end

      else
        % Cache is empty, but chRange and chCache could still be populated.
        % This happens when no annotations exist.
        cLength = 0;
      end
      
      % -- Need to download one/more annotations --
      
      % Get TSI Object, SNAPID, and TimeSeries
      tsi     = obj.getTSI;
      snapID  = obj.getSnapID;     
      startTime = annotation.start;
      
      nrAnnFromServer = maxNrEvents - cLength;
      assert(nrAnnFromServer <= 1000,...
            ['Maximum number of returned annotations from '...
            'server in single call is 1000.']);
      
      % Get next annotations using StartTime in usec. Offset equal
      % cLenght+1 because first returned annotation is same as provided
      % annotation.
      annotations = tsi.getTsAnnotations(snapID, startTime, ...
        obj.name, cLength+1, nrAnnFromServer);

      ann(annotations.size) = IEEGAnnotation();
      annIterator = annotations.iterator;

      ix = 0;
      while annIterator.hasNext
        ix = ix + 1;
        ann(ix) = IEEGAnnotation.createFromWebservice(annIterator.next, obj);
      end 
      
      % Set/Add to cache
      if all(obj.chRange == 0) %Cache does not exist.
        obj.evntCache = ann;
        obj.chRange = [startTime + 0.001 ann(end).start];
      else
        obj.evntCache = [obj.evntCache ann];
        ann = obj.evntCache(cOffset : cOffset + cLength + length(ann) - 1);
        obj.chRange(2) = ann(end).start;
      end
      
      % Set CachedRange to end of file if no more ann on server.
      if size(annotations) < (maxNrEvents - cLength)
        obj.chRange(2) = -1;
      end
          
    end
    
    function ann = getEvents(obj, startTime, varargin)
      % GETEVENTSBYTIME  Returns an array of events by time.
      %
      %   ANNARRAY = GETEVENTS(OBJ, STARTTIME) returns an array of
      %   IEEGANNOTATION objects following the STARTTIME in usec. By
      %   default, a maximum of 250 annotations are returned. See
      %   alternative method calls to specify this number manually.
      %
      %   ANNARRAY = GETEVENTS(..., MAXNREVENTS) MAXNREVENTS can
      %   manually be specified to change the maximum number of returned
      %   objects. This number cannot exceed 1000. 
      %   
      %   The method returns an empty array of IEEGANNOTATION objects if
      %   no annotations are available.
      
      DEFAULTMAX = 250;
      assert(nargin >= 2, 'Incorrect number of input arguments.');
            
      switch nargin
        case 2
          assert(~isempty(obj.up),...
            ['The ANNOTATIONLAYER object needs to be associated '...
            'with a DATASET object']);
          maxNrEvents = DEFAULTMAX;
        case 3
          if isnumeric(varargin{1}) && length(varargin{1})==1
            maxNrEvents = floor(varargin{1});
          else
            error('Incorrect arguments');
          end

        otherwise
          error('Incorrect number of input arguments.');
      end
      
      assert(isnumeric(startTime) && length(startTime) == 1,...
        'Unsupported input argument for GETEVENTS.');
      
      if ~isempty(obj.evntCache)
         
          % Check if StartTime is within chached items
          if (startTime >= obj.chRange(1) && ...
              (startTime <= obj.chRange(2) ||obj.chRange(2)== -1))
            
            allTimes = [obj.evntCache.start];
            
            % Find first element in cache that is bigger/equal than
            % start-Time. Should always return value because of parent
            % if-statement.
            cOffset = find(allTimes >= startTime,1);

            % Determine how many elements are cached.
            cLength = length(obj.evntCache) - cOffset + 1;
            
            % Check if number of annotations are already in cache
            if cLength >= maxNrEvents
              ann = obj.evntCache(cOffset:cOffset+maxNrEvents-1);
              return
            elseif obj.chRange(2) == -1
              % All annotations are already downloaded
              ann = obj.evntCache(cOffset:end);
              return
            end
            
          else
            % Start outside range cache --> Empty cache. 
            obj.evntCache = IEEGAnnotation.empty;
            cLength = 0;
            obj.chRange = [0 0];
          end

      else
        % Cache is empty, but chRange and chCache could still be populated.
        % This happens when no annotations exist.
        cLength = 0;
      end
      
      % -- Need to download one/more annotations --
      
      % Get TSI Object, SNAPID, and TimeSeries
      tsi     = obj.getTSI;
      snapID  = obj.getSnapID;

      nrAnnFromServer = maxNrEvents - cLength;
      
      assert(nrAnnFromServer <= 1000,...
            ['Maximum number of returned annotations from '...
            'server in single call is 1000.']);

      % Getting Annotations using StartTime in usec. Offset from startTime
      % is given by cLength.
      annotations = tsi.getTsAnnotations(snapID, startTime, ...
        obj.name, cLength, nrAnnFromServer);

      % Create matlab IEEGAnnotation objects from returned result.
      if annotations.size
        ann(annotations.size) = IEEGAnnotation();
        annIterator = annotations.iterator;

        ix = 0;
        while annIterator.hasNext
          ix = ix +1;
          ann(ix) = IEEGAnnotation.createFromWebservice(...
            annIterator.next, obj);
        end 
      else
        ann = IEEGAnnotation().empty;
      end
      
      % If ann is empty --> reached end of annotations on server.
      % Otherwise, add returned annotations to cache.
      if ~isempty(ann)
        
        % If cache is empty, set cache, otherwise append cache
        if all(obj.chRange == 0)
          obj.evntCache = ann;
          obj.chRange = double([startTime ann(end).start]);
        else
          % Append cache
          obj.evntCache = [obj.evntCache ann];
          
          % Get annotations that should be returned from cache.
          ann = obj.evntCache(cOffset : cOffset + cLength + length(ann) - 1);
          
          % Don't change start of cache, update end.
          obj.chRange(2) = double(ann(end).start);
        end

        % Set CachedRange to end of file if no more ann on server.
        if size(annotations) < (maxNrEvents - cLength)
          obj.chRange(2) = -1;
        end
        
      else
        obj.chRange(2) = -1;
      end
        
    end
    
    function out = getCachedRange(obj)
      %GETCACHERANGE  Returns range of cached events in usec.
      %
      % OUT = GETCACHEDRANGE(OBJ) returns the time interval over which the
      % available events are cached locally. 
      
        out = obj.chRange;
    end
    
    function out = getNrEvents(obj)
      %GETNREVENTS  Returns the total number of events in this layer.
      %
      % OUT = GETNREVENTS(OBJ) returns the number of events that are stored
      % in this annotation layer.
      
      out = obj.nrAnnotations;
    end
    
    function obj = rename(obj, newName)
      %RENAME  Renames the current annotationlayer
      %
      % OBJ = RENAME(OBJ, 'newName') renames the current annotationlayer.
      % The new annotationlayer name cannot already exist in the dataset. 
      
      assert(ischar(newName),'NEWNAME must be a string.');
      
      % Check all names in parent dataset
      parent = obj.up;
      if ~isempty(parent)
        allNames = {parent.annLayer.name};
        assert(~any(strcmp(newName, allNames)),...
          ['Could not change the name; AnnotationLayer with this name '...
          'already exists in Dataset.']);      
      
      
      tsi = obj.getTSI;
      snapID = obj.getSnapID;
      
      % Change Layer Name on portal
      tsi.moveTsAnnotations(snapID, obj.name, newName);
      end
      
      % Change name in Matlab object;
      obj.name = newName;
      
      % Clear Cache
      obj.clearEventCache;
      
    end
    
  end
  
  methods(Access = protected, Sealed = true)
    function info = specialPropsInfo(obj) 
      info = struct('name','evnts',...
        'size',[nan nan], 'format', 'IEEGAnnotation');
      
      info.size = [1 obj.nrAnnotations];
      
    end
    
  end

end