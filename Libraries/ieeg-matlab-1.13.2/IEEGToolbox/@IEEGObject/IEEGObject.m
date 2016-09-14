classdef (Abstract) IEEGObject < handle
  
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
  
  properties(Access = private)
    parent
  end

  methods (Access = protected)
    function info = specialPropsInfo(obj)  %#ok<MANU>
      info = struct('name',{},'size',[0 0], 'format','');
    end
    
  end
  
  methods (Sealed = true)
    
    function out = up(obj)
      %UP  Returns parent object in hierarchy.
      % OUT = UP(OBJ) returns the parent object of the current object OBJ.
      
      try
        out = [obj.parent];
      catch ME
        error('IEEGOBJECT:UP',...
          ['Not all object have a parent object or the parents are '...
          'not all of the same class.']);
      end
    end
    
    function tsi = getTSI(obj)
      %GETTSI  Returns the Java TimeSeriesInterface object.
      % TSI = GETTSI(OBJ) returns the Java TimeSeriesInterface object
      % associated with this object. This method can be called on all
      % classes in this toolbox as long as they are instantiated as part of
      % an IEEGSESSION. 
      %
      % This means that the object needs to have a parent object and the
      % root of the hierarchy needs to be an object of class IEEGSESSION.
      
      aux = obj;
      while ~isempty(aux.up)
        aux = aux.up;
      end

      tsi = getTSIprop(aux);
      
    end
    
    function m = methods(obj)
      %METHODS  Shows all methods associated with the object.
      %   METHODS(OBJ) displays all methods of the object OBJ that
      %   are defined for the subclass OBJ. Methods belonging to the
      %   SFR Toolbox are not shown. Clicking on the methods link
      %   will display the full description on the method.

      blockmethods = {'addlistener' 'delete' 'disp' 'eq' 'ge' 'ne' 'gt'  ...
        'le' 'lt' 'notify' 'isvalid' 'findobj' 'findprop' 'copy' ...
        'addprop' 'subsref' 'setsync' 'getTSIprop' 'populateAnnLayer'...
        };

      if nargout
        fncs = builtin('methods', obj);
        blockIdx = cellfun(@(x) any(strcmp(x, blockmethods)), fncs);
        fncs(blockIdx) = [];
        m = fncs;
        return;  
      end

      %Display methods sorted by the length of the method name and
      %then alphabetically. 

      fprintf('\n%s Methods:\n',class(obj));

      %Define indenting steps for unusual long method names.
      STEP_SIZES = [20 23 26 29 32 35 38 41 44 47 50];
      SAMPLES_TOO_CLOSE = 2;

      fncs = builtin('methods', obj);
      blockIdx = cellfun(@(x) any(strcmp(x, [blockmethods])), fncs);
      fncs(blockIdx) = [];

      % -- Get H1 lines  
      txts{1,length(fncs)} = [];
      for i=1:length(fncs)
        aux = help(sprintf('%s.%s',class(obj), fncs{i}));
        tmp = regexp(aux,'\n','split');
        tmp = regexp(tmp{1},'\s*[\w\d()\[\]\.]+\s+(.+)','tokens','once');
        if ~isempty(tmp)
          txts(i) = tmp;
        end
      end

      %The class specific methods
      [~,I] = sort(lower(fncs));
      fncs = fncs(I);
      txts = txts(I);

      L = cellfun('length', fncs);        
      for iSize = 1:length(STEP_SIZES)
        if iSize == length(STEP_SIZES)
          iUse = 1:length(txts);
        else
          iUse = find(L <= STEP_SIZES(iSize) - SAMPLES_TOO_CLOSE);
        end
        txtsUse = txts(iUse);
        fncsUse = fncs(iUse);
        LUse    = L(iUse);
        txts(iUse) = [];
        fncs(iUse) = [];
        L(iUse)    = [];
        for i=1:length(txtsUse)
          link = sprintf('<a href="matlab:help(''%s>%s'')">%s</a>',...
            class(obj),fncsUse{i},fncsUse{i});
          pad = char(32*ones(1,(STEP_SIZES(iSize)-LUse(i))));
          disp([ ' ' link pad txtsUse{i}]);
        end
        
      end
      display(sprintf('\n'));

    end

    function disp(obj)
      %DISP  Displays the object in the console.
      %   DISP(OBJ) displays the object in the console. This method formats the
      %   data in the object and displays the object including links to
      %   informative methods.

      % Check if matlab is running in terminal. If so, no links are used.
      if usejava('desktop')
        showLinks = true;
      else
        showLinks = false;
      end

      % Create links to methods
      
      Link1 = sprintf('<a href="matlab:help(''%s'')">%s</a>',class(obj),class(obj));
      Link2 = sprintf('<a href="matlab:methods(%s)">Methods</a>',class(obj));
      Link3 = sprintf('<a href="matlab:IEEGObject.openPortalSite()">main.ieeg.org</a>');

      if length(obj) == 1 

        % Check if object is deleted.
        if isvalid(obj)

          fieldn  = fieldnames(obj);
          
          specialProps = specialPropsInfo(obj);


          valTxts{1,length(fieldn)} = [];
          
          % Iterate over fieldNames
          for i = 1:length(fieldn)
                        
            inSpecialProps = strcmp(fieldn{i}, {specialProps.name});
            if any(inSpecialProps)
              % Do special stuff
              spIndex = find(inSpecialProps,1);
              
              % Allow for multiple length data
              if isfield(specialProps(spIndex), 'toString')
                valTxts{i} = sprintf(': %s',specialProps(spIndex).toString);
              elseif specialProps(spIndex).size(1) ~= -1
                valTxts{i} = sprintf(': [%ix%i %s]',specialProps(spIndex).size(1), ...
                specialProps(spIndex).size(2),specialProps(spIndex).format);
              else
                valTxts{i} = sprintf(': [%~x%i %s]', ...
                specialProps(spIndex).size(2),specialProps(spIndex).format);
              end
              
            else
              curProp = obj.(fieldn{i});
              
              if ischar(curProp)
                if length(curProp) < 50 && size(curProp,1)<=1
                  valTxts{i} = [': ''' curProp ''''];
                else
                  s = size(curProp);
                  valTxts{i} = sprintf(': [%ix%i char]',s(1), s(2));
                end
              elseif iscellstr(curProp)
                aux = cellfun(@(x) ['''' x '''  '], curProp, 'UniformOutput', false);
                if ~isempty(aux);aux(end) = strtrim(aux(end));end
                  valTxts{i} = [': {' [aux{:}] '}'];
                  if length(valTxts{i})>50
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': {%s cell}',sizestr);
                  end
              elseif isnumeric(curProp)
                if length(curProp)==1
                  valTxts{i} = num2str(curProp,': %g');
                elseif length(curProp)<10 && ismatrix(curProp) && any(size(curProp) <= 1)
                  %Needs to be a row vector
                  if size(curProp,1) > 1
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
                  else
                    valTxts{i} = [': [' regexprep(num2str(curProp,'% g'),' +',' ') ']'];
                  end
                  if length(valTxts{i}) > 50
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
                  end
                else
                  s = size(curProp);
                  sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                  valTxts{i} = sprintf(': [%s %s]',sizestr,class(curProp));
                end
              elseif islogical(curProp)
                if curProp; valTxts{i} = ': True';else valTxts{i} = ': False';end
              else 
                s = size(curProp);
                sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
              end
            end
           
          end

          sizeStr = [];
        else
          % Object is deleted, show deleted info and return from method.
          if showLinks
              display([ '  deleted '  Link1]);
              display([sprintf('\n  ') Link2 ', ' Link3 sprintf('\n')]);
          else
              display([ '  deleted '  class(obj)]);
          end
          return
        end

      else
        % Display array of objects.
        sizeStr = sprintf('%ix%i ',size(obj,1), size(obj,2));
        fieldn   = fieldnames(obj);
        valTxts{1,length(fieldn)} = [];
      end


      % --- Actual printing to display ---
      
      % Display top links
      maxPropNameLength = max(cellfun(@length, fieldn));
      if showLinks
        display([ '  ' sizeStr  Link1 ':'  sprintf('\n')]);
      else
        display([ '  ' sizeStr  class(obj) ':'  sprintf('\n')]);
      end

      % Display Properties
      for i=1:length(valTxts)
        pad = char(32*ones(1,(maxPropNameLength - length(fieldn{i})  +2)));
        disp([ ' ' pad ' '  fieldn{i} valTxts{i} ]);
      end

      % Display methods
      if showLinks
        display([sprintf('\n  ') Link2 ', ' Link3  sprintf('\n')]);
      end
      
      % --- ---


    end
  end
  
  methods
    function snapID = getSnapID(obj)
      %GETSNAPID  Provides snapshot ID for current Dataset.
      %
      % SNAPID = GETSNAPID(OBJ) provides the snapshot ID for the current
      % dataset. This method can be called from all objects in the
      % hierarchy below the IEEGDATASET object.
      
      aux = obj;
      while ~isa(aux,'IEEGDataset')
        if ~isempty(aux.up)
          aux = aux.up;
        else
          throwAsCaller(MException('IEEGObject:GETSNAPID',...
            'Snapshot ID not available.'));
        end
      end
      
      snapID = aux.getSnapID;
      
    end

  end
  
  methods(Access = protected, Sealed = true)
    function obj = setparent(obj, parentObj)
      
      assert(isa(parentObj,'IEEGObject'),...
        'Parent object for an IEEGObject can only be another IEEGObject.')
      
      obj.parent = parentObj;
    end
  end
  
  methods (Static, Sealed = true)
    function openPortalSite() 
      %OPENPORTALSITE  Opens the portal in an external browser.
      
      web('main.ieeg.org','-browser');
    end
  end
  
end