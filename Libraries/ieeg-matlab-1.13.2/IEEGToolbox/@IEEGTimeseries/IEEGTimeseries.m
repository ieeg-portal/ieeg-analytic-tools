classdef (Sealed) IEEGTimeseries  < IEEGObject 
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
    ts;
    dataInfo;
    revID;
  end
  
  properties 
    label = '';
    sampleRate = 0;
  end
  
  properties (Dependent)
    values
  end
  
  methods
    function values = get.values(obj) %#ok<MANU,STOUT>
      throwAsCaller(MException('IEEGTimeseries:getvalues',...
        'Please use the GETVALUES method to request data.'));
    end
  end
  
  methods(Access = protected, Sealed)
    
    function info = specialPropsInfo(obj) 
      info = struct('name','values',...
        'size',obj.dataInfo.size, 'format', obj.dataInfo.format);
      
     
    end

    
  end
  
  methods (Sealed)
  
    function obj = IEEGTimeseries(varargin)
      switch nargin
        case 0
          return
        case 1
            obj.ts = varargin{1};
            obj.valid = true;
            obj.label = char(obj.ts.getLabel);
            obj.sampleRate = obj.ts.getSampleRate;
            
            nrSamples = floor((obj.ts.getDuration/1e6)*obj.sampleRate);
            obj.dataInfo = struct('size', [nrSamples 1], 'format','double');
            obj.revID = obj.ts.getRevId;
        case 2
            obj.ts = varargin{1};
            obj.label = char(obj.ts.getLabel);
            obj.sampleRate = obj.ts.getSampleRate;
            
            nrSamples = floor((obj.ts.getDuration/1e6)*obj.sampleRate);
            obj.dataInfo = struct('size', [nrSamples 1], 'format','double');
            obj.revID = obj.ts.getRevId;
          
            setparent(obj,varargin{2});
       end
    end
      
    function [out ix] = sort(obj)
      % SORT  Sorts array of IEEGTimeseries
      %
      % [Y, IX] = SORT(OBJ) sorts the timeseries objects by their label. 
      
      allLabels = {obj.label};
      [~, ix] = sort(allLabels);
      out = obj(ix);
      
    end
    
    
    % TOO SLOW...
%     function out = ismember(obj, obj2)
%       if ~isa(obj2, 'IEEGTimeseries')
%         out = false;
%         return
%       end
%       
%       if length(obj) > 1
%         
%         tree = java.util.TreeSet;
%         for i =1:length(obj2); tree.add(obj2(i).revID);end
%         
%         tree2 = java.util.TreeSet;
%         for i =1:length(obj); tree2.add(obj(i).revID);end
%         
%         out = tree.containsAll(tree2);
%         
%         
%       else
%         tree = java.util.TreeSet;
%         for i =1:length(obj1); tree.add(obj1(i).revID);end
%           
%         out = tree.contains(obj.revID);  
%         
%       end
%       
%       
%       
%     end
%     
%     function out = eq(obj, obj2)
%       
%       assert(isvector(obj) && isvector(obj2),...
%         'Equals method not defined for multidimensional IEEGTimeseries arrays.');
%       
%       if isa(obj2, 'IEEGTimeseries')
%         if length(obj)==1
%           if length(obj2) ==1 
%             out = obj.ts.getRevId.equals(obj2.ts.getRevId);
%           else
%             out = false(1,length(obj2));
%             for i = 1:length(out)
%               out(i) = obj.revID.equals(obj2(i).revID);
%             end
%           end
%         else
%           if length(obj2) ==1 
%             out = false(1,length(obj));
%             for i = 1:length(out)
%               out(i) = obj(i).revID.equals(obj2.revID);
%             end
%           else
%             out = false(1,length(obj));
%             for i = 1:length(out)
%               out(i) = obj(i).revID.equals(obj2(i).revID);
%             end
%           end
%         end
%       else
%         out = false;
%       end
%     end
    
    function out = getRevID(obj)
      
      lobj = length(obj);
      if lobj==1
        out = char(obj.get_ts.getRevId);
      else
        out = cell(lobj,1);
        for i=1:lobj
          out{i} = char(obj(i).get_ts.getRevId);
        end
      end
    end
    
    function ts = get_tsdetails(obj)
      % GET_TS  Returns the JAVA TimeseriesDetails object.
      
      lobj = length(obj);
      if lobj > 1
        ts(lobj) = obj(lobj).ts;
        for i = 1:(lobj-1)
          ts(i) = obj(i).ts;
        end
      else
        ts = obj.ts;
      end
    end
    
    function ts = get_ts(obj)
      % GET_TS  Returns the JAVA Timeseries object.
      
      lobj = length(obj);
      if lobj > 1
        ts(lobj) = obj(lobj).ts.getTimeSeries;
        for i = 1:(lobj-1)
          ts(i) = obj(i).ts.getTimeSeries;
        end
      else
        ts = obj.ts.getTimeSeries;
      end
    end

    function nrSamples = getNrSamples(obj)
      info = specialPropsInfo(obj);
      nrSamples = info.size(1);
    end
    
    function values = getvalues(obj, varargin)
      %GETVALUES  Requests data from the IEEG-Portal.
      %
      % VALUES = GETVALUES(OBJ, IDX) returns values associated with object
      % OBJ and IDX, where IDX is a 1xn vector of indeces. The method
      % assumes that the timeseries is continuous and missing data are
      % represented by Nans. 
      %
      % VALUES = GETVALUES(OBJ, STARTTIME, BLOCKLENGTH) returns values
      % associated with the object OBJ, where STARTTIME is the time of the
      % first sample in usec, and BLOCKLENGTH is the duration of the
      % requested data in usec.
      
      switch nargin
        case 2
          tIdx = varargin{1};
          startIndex = floor((1e6*(tIdx(1)-1))./obj.sampleRate);
          blockLength = (1e6*(tIdx(end)-tIdx(1)+1))./obj.sampleRate;
          
          values = getdatablock(obj, startIndex, blockLength);
          
        case 3
          startIndex = varargin{1};
          blockLength = varargin{2};
          values = getdatablock(obj, startIndex, blockLength);
          
          
        otherwise
          error('Incorrect number of input arguments.');
      end
    end
    
    function value = getdataset(obj)
      value = obj.dataset;      
    end
  end
  
  methods (Access = private, Sealed = true)
    function values = getdatablock(obj, startIndex, blockLength)
      
      try
        snapID = obj.getdataset.getsession.snapID;
        tsi =  obj.getTSI;
      catch ME
        error('IEEGTimeseries not instantiated by IEEGDataset');
      end

      seriesListOfLists = tsi.getUnscaledTimeSeriesSetRaw(snapID,... 
        char(obj.ts.getRevId), startIndex, blockLength, 1);
    
      % Get the data series segments associated with the each channel.

      seriesList = seriesListOfLists(1);
      firstSeries = seriesList(1);

      % On first iteration, create full array for returned values and find the
      % scalefactor.
      values = double(firstSeries.getSeries()) * firstSeries.getScale();

      % Set values to NaN if they are in a gap
      gStart = firstSeries.getGapsStart();
      gEnd   = firstSeries.getGapsEnd();
      for i = 1: length(gStart)
          startInx = gStart(i);
          % The gap end is actually 1 more than the last item
          endInx = gEnd(i);
          assert(endInx > startInx, 'Gap End is before Gap Start.');
          values((startInx+1):endInx, 1) = NaN;
      end
      
      
    end
  end
  
end
