classdef (Sealed) IEEGAnnotation < IEEGObject
  % IEEGANNOTATION  Class that represents a single annotation.
  %
  % This class represents single annotations in the IEEG-Portal. A single
  % annotation can span multiple channels and have a TYPE, START/STOP-TIME.
  %
  % If start and stoptime are equal, the HASDURATION flag is set to false.
  % If the annotation is present on all channels in the parent Dataset, the
  % ISGLOBAL flag is set to true.
  %
  % The STARTTIME and STOPTIME values indicate the event-time in
  % micro-seconds since the beginning of the dataset. The first value of
  % the dataset is considered to be sampled at t==0.
  %
  % Use the static method CREATEANNOTATIONS to create multiple annotations
  % using a single method call. 
  %
  %
  
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
    annID        % Annotation ID string.
    channelTS    % Timeseries object of channels
    channelObjs  % Populated with indeces channels in Dataset.
  end
  
  properties (SetAccess = private)
    type        = '';
    description = '';
    isGlobal    = true;  % Indicates if annotation is present on all channels.
    hasDuration = false; 
    start = nan; % Start time of the event in usec.
    stop = nan;  % Stop time of the event in usec.
  end
  
  properties (SetAccess = private, Dependent)
    channels = IEEGTimeseries; % Channel is populated based on channelTS once accessed.
  end
  
  
  methods
    function set.channels(obj,value)
      obj.channelObjs = value;
    end
    
    function value = get.channels(obj)
      
      % The channel property will try to return objects of type
      % IEEGTimeseries. When objects of class IEEGAnnotation are created,
      % the JAVA Timeseries objects are stored in the objects instead of
      % the IEEGTimeseries objects to increase efficiency. The
      % IEEGTimeseries objects are determined from the JAVA Timeseries
      % objects when the channel property is first requested.
      
      if isempty(obj.channelObjs)
        if ~isempty(obj.up)
          ChannelObjs = obj.up.up.rawChannels;
          timeSeries  = ChannelObjs.get_ts;

          value(size(obj.channelTS)) = IEEGTimeseries();
          ix = 1;
          for iCh = 1: length(timeSeries)
            if obj.channelTS.contains(timeSeries(iCh))
              value(ix) = ChannelObjs(iCh);
              ix = ix + 1;
            end
          end

          assert(ix == (size(obj.channelTS)+1),...
            'Annotated channel not found, please contact developers.');
          
          obj.channelObjs = value;
        else
          value = obj.channelTS;
        end
      else
        value = obj.channelObjs;
      end
      
    end
    
  end
  
  methods (Sealed)
    function obj = IEEGAnnotation(varargin)
      %IEEGANNOTATION  Creates an annotation object.
      %
      % OBJ = IEEGANNOTATION(TIME, TYPE, DESCRIPTION) creates a global annotation
      % object on all channels in a snapshot. TIME is a numeric or a 1x2
      % array of numerics denoting the start, and stop-times of the
      % annotation. Value is a numeric and TYPE is a string indicating the
      % type of annotation.
      %
      % OBJ = IEEGANNOTATION(TIME, TYPE, DESCRIPTION, CHANNELARR) creates an
      % annotation on a specific subset of channels. CHANNELARR is an array
      % of IEEGTimeseries objects. 
      %
      % Once an ANNOTATION is added to a DATASET, the associated channels
      % are matched agains the channels in the DATESET. In case that no
      % channels are supplied in the constructor, all channels of the
      % dataset are added to annotation.
      
      switch nargin
        case 0
          return
        case 3
          
          tms = varargin{1};
          assert(any(length(tms)==[1 2]), ...
            'Incorrect number of values in TIME.');
          assert(isnumeric(tms), 'TIME should be a numeric.');
          
          obj.start = tms(1);
          if length(tms)==2
            obj.stop = tms(2);
            obj.hasDuration = true;
          end

          obj.description = varargin{3};
          assert(ischar(obj.description),...
          'DESCRIPTION should be of class CHAR.');
          
          obj.type = varargin{2};
          assert(ischar(obj.type),'TYPE should be of class CHAR.');
          
          % On all channels when added to Dataset.
          obj.isGlobal = true;          
          obj.channels = IEEGTimeseries.empty();
          
        case 4
           
          tms = varargin{1};
          assert(any(length(tms)==[1 2]), ...
            'Incorrect number of values in TIME.');
          assert(isnumeric(tms), 'TIME should be a numeric.');
          
          obj.start = tms(1);
          if length(tms)==2
            obj.stop = tms(2);
            obj.hasDuration = true;
          end

          obj.description = varargin{3};
          assert(ischar(obj.description),...
          'DESCRIPTION should be of class CHAR.');
          
          obj.type = varargin{2};
          assert(ischar(obj.type),'TYPE should be of class CHAR.');
          
          obj.isGlobal = false;
          assert(isa(varargin{4},'IEEGTimeseries'),...
            'CHANNELARR has to be of class IEEGTIMESERIES.');
          
          obj.channelObjs = varargin{4};
          obj.channelTS = obj.channelObjs.get_ts;
          
        otherwise
          error('Incorrect number of input arguments.');
      end
    end
    
    function out = getAnnID(obj)
      % GETANNID  Returns ID(s) for the annotations on the portal.
      %
      %   OUT = GETANNID(OBJ) returns a string or a cellarray of strings
      %   containing the IDs for the annotation objects on the portal. 
      
      assert(isvector(obj), ...
        'OBJ must be a single object or a vector of objects.');
      
      if length(obj) == 1
        out = obj.annID;
      else
        out = {obj.annID};
      end
      
    end
    
    function ann = filterByChannel(ann, channels)
      % FILTERBYCHANNEL Filters array of annotations by channel(s).
      %
      %   ANN = FILTERBYCHANNEL(ANNARRAY, CHANNELS) filters the input
      %   annotation array, ANNARRAY, by the provided CHANNELS array.
      %   CHANNELS is a 1d vector of IEEGTimeSeries objects of the channels
      %   that should be included in the output. 
      %
      %   For Example:
      %     ch  = session.data.rawChannels(1:3);
      %     ann = obj.getEvents(0);
      %     filteredAnn = ann.filterByChannel(ch);
      
      mask = cellfun(@any,(cellfun(@(x) ismember(channels,x), ...
        {ann.channels}, 'uniformOutput',false)));
      
      ann = ann(mask);
      
    end
    
  end
  
  methods(Access = protected, Sealed)
    function info = getdatainfo(obj) %#ok<MANU>
      info = struct('size',[nan nan], 'format', 'Unknown');
    end
  end
  
  methods(Static, Sealed)
    function objs = createAnnotations(startTimes, varargin)
      %CREATEANNOTATIONS  Factory to create multiple annotations.
      %
      % OBJS = CREATEANNOTATIONS(STARTTIMES, TYPEARR) returns an array of
      % IEEGAnnotation objects. STARTTIMES is a vector of timestamps
      % indicating the time at which the event takes place in usec. The
      % startTimes are referenced to the beginning of the dataset, where
      % t=0 is the first sample of the dataset. TYPEARR is a string or a
      % cellarray of strings indicating the type of events that are
      % created. When no channels are supplied, the annotation is
      % considered a global annotation and includes all channels once added
      % to a dataset.
      %
      % OBJS = CREATEANNOTATIONS(STARTTIMES, STOPTIMES, TYPEARR) provides
      % annotations with a specific duration. STOPTIMES is a vector of
      % equal lenght as STARTTIMES and contains timestamps that indicate
      % the end of each annotation in usec.
      %
      % OBJS = CREATEANNOTATIONS(STARTTIMES, TYPEARR, DESCARR) provides similar
      % results as described above but includes a string or cell-array of
      % strings with a description for each/all annotations.
      %
      % OBJS = CREATEANNOTATIONS(STARTTIMES, STOPTIMES, TYPEARR, DESCARR)
      % similar as above including stop-times.
      %
      % OBJS = CREATEANNOTATIONS(..., CHANNELARR) adds the annotations to a
      % specific channel or set of channels. CHANNELARR is an array of
      % IEEGTIMESERIES.
      %
      % If TIMEARR is a vector, the returned objects will only have a
      % single timestamp, if it is an nx2 array, they will have a
      % start-time and end-time.
      %
      %
      % Example:
      %   anns = IEEGAnnotation.createAnnotations([1 2],  ...
      %           {'Event','Event'}, {'Marker 1' 'Marker 2'});
     
      
      
      % Check number of input arguments.
      narginchk(2,5);
      
      chObjs = IEEGTimeseries.empty();
      limitChannels = false;
      descArr = '';
      isSingleEvent = true;
      stopTimes = [];
      
      switch nargin
        case 2 %StartTime, Type
          typeArr = varargin{1};
        case 3 %Start, Type, Channel || Start, Stop, Type || Start, Type, Desc
          if isa(varargin{2},'IEEGTimeseries')
            chObjs = varargin{2};
            limitChannels = true;
            typeArr = varargin{1};
          elseif isnumeric(varargin{1})
            stopTimes = varargin{1};
            isSingleEvent = false;
            typeArr = varargin{2};
          else
            typeArr = varargin{1};
            descArr = varargin{2};
          end
        case 4 %Start, Stop, Type, Desc || Start, Stop, Type, Channel
          if isa(varargin{3},'IEEGTimeseries')
            limitChannels = true;
            stopTimes = varargin{1};
            isSingleEvent = false;
            typeArr = varargin{2};
            chObjs = varargin{3};
          else
            stopTimes = varargin{1};
            isSingleEvent = false;
            typeArr = varargin{2};
            descArr = varargin{3};
          end
        case 5 %Start, Stop, Type, Desc, Channel
          limitChannels = true;
          stopTimes = varargin{1};
          isSingleEvent = false;
          typeArr = varargin{2};
          descArr = varargin{3};
          chObjs = varargin{4};
      end

      % Check inputs
      assert(isvector(startTimes), 'STARTTIMES must be vector.');
      assert(isvector(stopTimes) || isempty(stopTimes), 'STOPTIMES must be vector or empty.');
      if ~isempty(stopTimes)
        assert(length(stopTimes)==length(startTimes),...
          'START and STOP-times must be vectors of equal length.');
      end
      
      
      % Check typeArr
      switch class(typeArr)
        case 'char'
        case 'cell'
          assert(isvector(typeArr),...
            'TYPE CELL-ARRAY can only be 1-dimensional.');
          assert(length(typeArr) == length(startTimes),...
            'TYPE and STARTTIMES vector should have equal number of elements.');
        otherwise
          error('Unsupported class for TYPE.');
      end
      
      % Check Description
      switch class(descArr)
        case 'char'
        case 'cell'
          assert(isvector(descArr),...
            'DESCRIPTION CELL-ARRAY can only be 1-dimensional.');
          assert(length(descArr) == length(startTimes),...
            'DESCRIPTION and STARTTIMES vector should have equal number of elements.');
        otherwise
          error('Unsupported class for DESCRIPTION.');
      end
      
      nrObjs = length(startTimes);
      objs(nrObjs) = IEEGAnnotation;
      for i = 1:nrObjs
        if ischar(typeArr) == 1
          curType = typeArr;
        else
          curType = typeArr{i};
        end
        
        if ischar(descArr) == 1
          curDesc = descArr;
        else
          curDesc = descArr{i};
        end
        
        
        if isSingleEvent
          if limitChannels
            objs(i) = IEEGAnnotation(startTimes(i),curType, curDesc,chObjs);
          else
            objs(i) = IEEGAnnotation(startTimes(i),curType, curDesc);
          end
        else
          if limitChannels
            objs(i) = IEEGAnnotation([startTimes(i) stopTimes(i)],curType, curDesc,chObjs);
          else
            objs(i) = IEEGAnnotation([startTimes(i) stopTimes(i)],curType, curDesc);
          end
        end
        
      end

    end
    
    function [out, layer]  = createFromWebservice(annotation, parent)
      %CREATEFROMWEBSERVICE  Method to parse IEEGANNOTATION from webservice
      %
      % This method is used by the IEEG-Portal Toolbox to parse the java
      % objects returned by the portal into a valid matlab IEEGANNOTATION
      % object.
      
      annotatedSeries = annotation.getAnnotatedSeries;
      annotatedCh = annotatedSeries;
      
      startTime = cell(annotation.getStartTimeUutc);
      startTime = startTime{1};
      
      endTime = cell(annotation.getEndTimeUutc);
      endTime = endTime{1};
      
      typ = cell(annotation.getType);
      typ = typ{1};
      
            
      out = IEEGAnnotation([startTime endTime], typ, '');
      out.channelTS = annotatedCh;
      out.annID = cell(annotation.getRevId);
      out.annID = out.annID{1};
      
      desc = annotation.getDescription;
      if ~isempty(desc)
        desc = cell(desc);
        out.description = desc{1};
      end

      layer = cell(annotation.getLayer);
      layer = layer{1};
      setparent(out,parent);
      
    end
  end
  
end

