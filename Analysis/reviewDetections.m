function h = reviewDetections(dataset, inputLayer, scoreThese, channels, outputLayer, dataRow)
    % viewAnnots is a function that will allow viewing and validation of
    % annotations with an IEEGDataset. Labeled annotations can be saved
    % (uploaded to the portal)
    
    % Usage: viewAnnots(dataset, layerName,startAnnot,channels)
    %   'dataset'   :   [IEEGDataset]
    %   'layerName' :   [string] name of layer to be viewed
    %   'startAnnot':   [int] Annotation to start viewer at
    %   'channels'  :   [1xNch] Vector of channels to view
    %   'layerName':   [string] prefix of layers to adds
    %
    %   7/22/2014 - Hoameng Ung
    %   Many additions were added for v2 with help of Ameya Nanivadekar
    %   These include:
    %       1. Vetting choices
    %       2. Multiple channel annotations
    %       3. Channel label status
    %
    %   10/1/2014 - Hoameng Ung
    %   Renamed
    
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
   
%     dbstop in f_scoreDetections at 136;
    
    panelColor = get(0,'DefaultUicontrolBackgroundColor');
    scrSize = (get(0,'ScreenSize')./72)./2.54;
    
    assert(nargin > 2, 'Insufficient number of input arguments.');

    sampleFreq = 1;
    xTitle = 'SampleNr';
%     annLayers = dataset.annLayer;
    
    % If more than standard number of input argument, then check inputs. This
    % fails if the user wants to pass 'sf' to the getData method or if the user
    % wants to pass an annotation structure to the getdata method. This should
    % never really happen.
    getDataAttr  = {};
    
    % Find Samplefreq, only if all channels have equal sample freq.
    allSF = [dataset.rawChannels.sampleRate];
    if all(allSF == allSF(1))
      sampleFreq = allSF(1);
      xTitle = 'Time (s)';
    else
      warning(['Not all channels are sampled at the same rate, '...
        'Using sample index for x-axis.']);
    end
    
%     set(uihandle, 'Visible', 'on');

    % Set up the figure and defaults
    uihandle = figure('Units','centimeters',...
      'Position',[scrSize(3)/1.25 scrSize(4)/4 30 20],...
      'Color',panelColor,...
      'Renderer','painters',...
      'HandleVisibility','callback',...
      'IntegerHandle','off',...
      'Toolbar','none',...
      'MenuBar','none',...
      'NumberTitle','off',...
      'Name','Workspace Plotter',...
      'Visible', 'off',...
      'ResizeFcn',@figResize);

    % Create the top uipanel
    topPanel = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2],...
      'Parent',uihandle,...
      'Clipping','off',...
      'Tag','topP',...
      'ResizeFcn',@topPanelResize);
    
    % Create the bottom uipanel
    bottomPanel = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2],...
      'Parent',uihandle,...
      'Clipping','on',...
      'Tag','botP',...
      'ResizeFcn',@botPanelResize);
    
    % Create the bottom uipanel
    bottomPanel2 = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2 ],...
      'Parent',uihandle,...
      'Clipping','on',...
      'Tag','botP2',...
      'ResizeFcn',@botPanelResize);
    
    % Create the right side panel
    centerPanel = uipanel('bordertype','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1/20 8 88 27],...
      'Parent',uihandle,...
      'Tag','cenP',...
      'ResizeFcn',@cenPanelResize);
    
%     set(topPanel, 'Visible', 'on');
%     set(bottomPanel, 'Visible', 'on');
%     set(bottomPanel2, 'Visible', 'on');
%     set(centerPanel, 'Visible', 'on');

    chanLabels = cell(length(channels),1);
    for i=1:length(chanLabels)
      
%       chanLabels{i} = sprintf('Ch_%i',varargin{2}(i));
      chanLabels{i} = dataset.rawChannels(channels(i)).label;
    end
    
    % Create the center panel
    a1 = axes(...
      'Units','centimeters',...
      'Position', [3 2 88 40],...
      'XLim',[0 1],'YLim',[0,1],...
      'Tag','plotWindow',...
      'Parent',centerPanel,...
      'YTickLabel',chanLabels,'YTickLabelMode','manual','YTick',1:length(channels));
    set(get(a1,'XLabel'),'String',xTitle,'FontSize',12);
    set(get(a1,'YLabel'),'String','Channel Label','FontSize',12);

    if sampleFreq ~= 1
      plotName = sprintf('Dataset Name: %s\tAnimal Name: %s\n', ...
        dataset.snapName, char(dataRow.Rat_ID));
    else
      plotName = sprintf('Dataset Name: %s\tAnimal Name: %s\n', ...
        dataset.snapName, char(dataRow.Portal_ID));
    end
    
    uicontrol(uihandle,'Style', 'text', 'Units','normalized', 'String', plotName,...
    'Position', [0 0 0.25 1], 'Parent', topPanel,'HorizontalAlignment','left',...
    'FontSize',12,'Tag','title');  

    uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[  ../div]',...
    'Position', [0.05 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
    'FontSize',12,'Tag','y-scale');  
  
%     uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[Decimation : -]',...
%     'Position', [0.08 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
%     'FontSize',12,'Tag','decimation');  

    uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[Annotation : -]',...
    'Position', [1.01 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
    'FontSize',12,'Tag','annotation');  

    uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[Current Label : -]',...
    'Position', [2.01 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
    'FontSize',12,'Tag','label');

    uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[Portal Time : -]',...
    'Position', [6.01 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
    'FontSize',10,'Tag','portalTime');

    uicontrol(uihandle,'Style', 'text', 'Units','centimeters', 'String', '[Real Time : -]',...
    'Position', [10.01 0.95 0.25 0.05], 'Parent', centerPanel,'HorizontalAlignment','left',...
    'FontSize',10,'Tag','realTime');

  uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', 'Center Traces',...
    'Position', [0.1 0.1 2 1], 'Callback',@Center,'Parent',bottomPanel2);
    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters','String', 'Gain +',...
    'Position', [2.2 0.1 2 1], 'Callback',@ZoomOutY,'Parent',bottomPanel2);    
    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', 'Gain -',...
    'Position', [4.3 0.1 2 1], 'Callback',@ZoomInY,'Parent',bottomPanel2);

    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', 'Zoom In',...
    'Position', [6.4 0.1 2 1], 'Callback',@ZoomInT,'Parent',bottomPanel2);
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Zoom Out',...
    'Position', [8.5 0.1 2 1], 'Callback',@ZoomOutT,'Parent',bottomPanel2);

    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', 'Prev Event',...
    'Position', [20.6 0.1 4 1], 'Callback',{@NextEvnt,false},'Parent',bottomPanel, 'Tag','PrevEvnt');

    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Next Event',...
    'Position', [25.4 0.1 4 1], 'Callback',{@NextEvnt,true},'Parent',bottomPanel,'Tag','NxtEvnt');

    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'To PDF',...
    'Position', [24.6 0.1 2.4 1], 'Callback',@PrintPDF,'Parent',topPanel, 'Tag','pdfButton');

%     uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters','String','-',...
%     'Position', [19.5 0.1 3 1], 'Callback',@ToggleNEventButton,'Parent',bottomPanel,...
%    'ForegroundColor', [0.4 0.4 0.4],'Tag','EvntSelect','userData',0);

%     if ~isempty(annLayers)
%       evButtonHandles = zeros(length(annLayers),1);
%       for iLayer = 1:length(annLayers)
%    
%         evButtonHandles(iLayer) = uicontrol(uihandle, ...
%           'Style', 'pushbutton', ...
%           'Units','centimeters', ...
%           'String', annLayers(iLayer).name, ...
%           'Position', [(0.1 + (iLayer-1)*4.8 + (iLayer-1)*0.1) 0.1 4.8 1], ...
%           'Tag', annLayers(iLayer).name, ...
%           'Callback',@toggleEventButton, ...
%           'Parent',bottomPanel2, ...
%           'userData',{0 annLayers(iLayer) iLayer []}); % [Vismode IEEGLayer LayerIndex, [AllstartTimes] ]
%         
%         
%       end
%     else
      evButtonHandles = [];
%     end
    
    %add Validation bar
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Seizure',...
    'Position', [0.1 0.1 4 1], 'BackgroundColor', [0 1 0], 'Callback',@EventLbl,'Parent',bottomPanel);

    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Artifact',...
    'Position', [4.9 0.1 4 1], 'BackgroundColor', [1 1 0], 'Callback',@ArtifactLbl,'Parent',bottomPanel);

%     uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Incorrect',...
%     'Position', [9.7 0.1 4 1], 'BackgroundColor', [1 0 0], 'Callback',@IncorrectLbl,'Parent',bottomPanel);
    
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Save',...
    'Position', [20.6 0.1 2 1], 'FontSize', 10, 'Callback',@SaveAnnot,'Parent',bottomPanel2,'Tag','save');
    % changed to [12 -1.2 2 1] to [12 0.1 2 1]
  
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'Erase labels',...
    'Position', [25.3 0.1 2 1], 'Callback',@EraseAnnot,'Parent',bottomPanel2,'Tag','erase');
        
    set(uihandle, 'Visible', 'on');

	% Create Line handles
    lHandles = zeros(size(channels,2),1);
    %rHandles = zeros(size(channels,2),1);
    for i = 1: size(channels,2)
      lHandles(i) = line([0 0], [0 0],'Parent',a1);
    end
    rHandles = zeros(2,1);
    rHandles(1) =  line([0 0], [0 0],'Parent',a1);
    rHandles(2) =  line([0 0], [0 0],'Parent',a1);
    annLayerIdx = strcmp(inputLayer,{dataset.annLayer.name});

    set(a1,'YLim',[0 length(lHandles)+1]);    
    setup = struct(...
      'annIdx', 1, ...
      'channels',channels, ...
      'annLayer', dataset.annLayer(annLayerIdx), ...
      'annotations', [], ...
      'annotLabel', [], ...
      'annRound', 1,...
      'noMoreAnnotations',0,...
      'totalAnn', dataset.annLayer(annLayerIdx).getNrEvents,...
      'savedIdx',0,...
      'sf', sampleFreq,...
      'decimation', [], ...
      'lhandles', lHandles, ...
      'rhandles', rHandles, ...
      'objHandles',dataset, ...
      'center', [], ...
      'compression',[], ...
      'eventButtons',evButtonHandles,...
      'electrodes', [],...
      'GetDataAttr',[],...
      'needZoomX',0,...
      'eventOffsetLine',[]);
         
    anns = getAllAnnots(dataset, inputLayer);
    anns = anns(scoreThese);
%     annLayer = dataset.annLayer(strcmp(layerName,{dataset.annLayer.name}));
%     for i = 1:size(annotTimes,1)
%       anns(i) = annLayer.getEvents(annotTimes(i,1),1);
%     end
    
    tmp = cellfun(@(x)sum(ismember({x.label},chanLabels)),{anns.channels});
    setup.annotations=anns(tmp>0);

    setup.GetDataAttr = getDataAttr;
    setup.annotLabel=zeros(1,length(setup.annotations));
    setup.chanLabels = chanLabels;
    setup.outputLayer = outputLayer;
    setup.startSystem = datenum(dataRow.Start_System, 'dd-mmm-yyyy HH:MM:SS');
    guidata(uihandle, setup);
    h = a1;
end

%% METHODS FOR RESIZING GUI
function figResize(src,~)			
  setup = guidata(src);
	fpos = get(src,'Position');
  children = get(src,'Children');
  topPanel = findobj(children,'Tag','topP');
  botPanel = findobj(children,'Tag','botP');
  botPanel2 = findobj(children,'Tag','botP2');
  centerPanel = findobj(children,'Tag','cenP');
  
  tpos = get(topPanel,'position');

  bpos2 = get(botPanel2,'position');
  set(botPanel2,'Position',...
      [0.2 0.2 fpos(3)-.4 bpos2(4)]);  % here
  bpos2 = get(botPanel2,'position');

  bpos = get(botPanel,'position');
  set(botPanel,'Position',...
      [0.2 bpos2(2)+bpos2(4)+0.1 fpos(3)-.4 bpos(4)])
  bpos = get(botPanel,'position');

  cwidth = max([0.2 fpos(3)-0.4]);
  cheigth = max([0.1 fpos(4) - bpos(4)- bpos2(4)- 0.8 - tpos(4)]);
  cbottom = bpos(2)+bpos(4)+0.2;

  set(centerPanel,'Position',...
      [0.2  cbottom cwidth cheigth]);

  set(topPanel,'Position',...
      [0.2 cheigth+cbottom+0.2 cwidth tpos(4) ]);
  
  if setup.noMoreAnnotations==0
      A1 = findobj(centerPanel,'Tag','plotWindow');
      updateRaw(A1);

%       A2 = findobj(centerPanel,'Tag','decimation');
%       set(A2,'String',sprintf('[Decimation: %i ]',setup.decimation));

      A4 = findobj(centerPanel,'Tag','annotation');
      set(A4,'String',sprintf('[Annotation: %i / %i]',setup.annIdx,numel(setup.annotations)));

      if setup.annotLabel(setup.annIdx)==0
          dispLabel='Unmarked';
          rgbVal=[0.8 0.8 0.8];
      elseif setup.annotLabel(setup.annIdx)==1
          dispLabel='Seizure';
          rgbVal=[0 1 0];
      elseif setup.annotLabel(setup.annIdx)==2
          dispLabel='Artifact';
          rgbVal=[0 1 1];
%       elseif setup.annotLabel(setup.annIdx)==3
%           dispLabel='Incorrect';
%           rgbVal=[1 0 0];
      end

      A5 = findobj(centerPanel,'Tag','label');
      set(A5,'String',sprintf('[Current Label: %s ]',dispLabel),'BackgroundColor',rgbVal);
      
      time(1) = setup.annotations(1).start/1e6 - 5;
      days = floor(time(1)/60/60/24) + 1;
      hour = floor( (time(1) - (days-1)*24*60*60) /60/60);
      minute = floor( (time(1) - (days-1)*24*60*60 - hour*60*60) /60);
      second = floor( (time(1) - (days-1)*24*60*60 - hour*60*60 - minute*60) );

      A6 = findobj(centerPanel,'Tag','portalTime');
      set(A6,'String',sprintf('[Portal Time: %02d:%02d:%02d:%02d ]', days, hour, minute, second)); 

      actualTime = datestr( (setup.annotations(setup.annIdx).start/1e6 - 5)/60/60/24 + setup.startSystem, 'mm/dd/yyyy HH:MM:SS');
      A7 = findobj(centerPanel,'Tag','realTime');
      set(A7,'String',sprintf('[Realtime:%s ]', actualTime)); 
  end
  
end

function topPanelResize(src, ~)		
    PDFbutton = findobj(src,'Tag','pdfButton');
    pos = get(src, 'Position');
    posb = get(PDFbutton, 'Position');
    set(PDFbutton,'Position', [(pos(1)+pos(3) -posb(3)  - 0.4) posb(2) posb(3) posb(4)]);

end

function botPanelResize(src, ~)		
    pos = get(src, 'Position');
    
    prevEvntButton = findobj(src,'Tag','PrevEvnt');
    posb1 = get(prevEvntButton, 'Position');
    set(prevEvntButton,'Position', [(pos(1)+pos(3) -posb1(3) - 5.2) posb1(2) posb1(3) posb1(4)]);  % here

    nxtEvntButton=findobj(src,'Tag','NxtEvnt');
    posb2 = get(nxtEvntButton, 'Position');
    set(nxtEvntButton,'Position', [(pos(1)+pos(3) -posb2(3)  - 0.4) posb2(2) posb2(3) posb2(4)]);

    saveEvntButton=findobj(src,'Tag','save');
    posb3 = get(saveEvntButton, 'Position');
    set(saveEvntButton,'Position', [(pos(1)+pos(3) -posb3(3)  - 0.4) posb3(2) posb3(3) posb3(4)]);  % here
    
    eraseEvntButton=findobj(src,'Tag','erase');
    posb4 = get(eraseEvntButton, 'Position');
    set(eraseEvntButton,'Position', [(pos(1)+pos(3) -posb4(3)  - 2.5) posb4(2) posb4(3) posb4(4)]);
    
end

% function botPanelResize2(src, ~)		
%     pos = get(src, 'Position');
%     
% %     prevEvntButton = findobj(src,'Tag','PrevEvnt');
% %     posb1 = get(prevEvntButton, 'Position');
% %     set(prevEvntButton,'Position', [(pos(1)+pos(3) -posb1(3) - 5.2) posb1(2) posb1(3) posb1(4)]);
% % 
% %     nxtEvntButton=findobj(src,'Tag','NxtEvnt');
% %     posb2 = get(nxtEvntButton, 'Position');
% %     set(nxtEvntButton,'Position', [(pos(1)+pos(3) -posb2(3)  - 0.4) posb2(2) posb2(3) posb2(4)]);
% 
%     saveEvntButton=findobj(src,'Tag','save');
%     posb3 = get(saveEvntButton, 'Position');
%     set(saveEvntButton,'Position', [(pos(1)+pos(3) -posb3(3)  - 0.4) posb3(2) posb3(3) posb3(4)]);
%     
%     eraseEvntButton=findobj(src,'Tag','erase');
%     posb4 = get(eraseEvntButton, 'Position');
%     set(eraseEvntButton,'Position', [(pos(1)+pos(3) -posb4(3)  - 2.5) posb4(2) posb4(3) posb4(4)]);
%     
% end

function cenPanelResize(src,~)		
    rpos = get(src,'Position');
    
    %resize listbox with properties
    listHandle = findobj(get(src,'Children'),'Tag','plotWindow');
    set(listHandle,'Position',[3 1.5 rpos(3)-3.5 rpos(4)-2.5]);
    plotpos = get(listHandle,'position');
    A2 = findobj(src,'Tag','y-scale');
    set(A2,'position',[plotpos(1)-3 plotpos(4)+plotpos(2) 5 0.6]); 
    
%     A3 = findobj(src,'Tag','decimation');
%     set(A3,'position',[plotpos(1)+2 plotpos(4)+plotpos(2) 5 0.6]); 
    
    A4 = findobj(src,'Tag','annotation');
    set(A4,'position',[plotpos(1)+2 plotpos(4)+plotpos(2) 5 0.6]); 
    
    A5 = findobj(src,'Tag','label');
    set(A5,'position',[plotpos(1)+6 plotpos(4)+plotpos(2) 5 0.6]); 
    
    A6 = findobj(src,'Tag','portalTime');
    set(A6,'position',[plotpos(1)+12 plotpos(4)+plotpos(2) 5 0.6]); 

    A7 = findobj(src,'Tag','realTime');
    set(A7,'position',[plotpos(1)+18 plotpos(4)+plotpos(2) 5 0.6]); 
end

%% GLOBAL UPDATE FUNCTIONS
function updateRaw(src, ~)			
%   dbstop in updateRaw at 391
  
	setup = guidata(src);

  CH = get(gcbf,'Children');
  CenP = findobj(CH,'Tag','cenP');
  axesHandle = findobj(CenP,'Tag','plotWindow');
  aux = setup.objHandles;
  
	pos = get(axesHandle, 'Position');
	width = ((pos(3)-pos(1))./2.54)*72; %change to pixels.
        
    %if more annotations are needed
    if setup.annIdx>length(setup.annotations)
        setup.noMoreAnnotations = 1;
        setup.annIdx = setup.annIdx-1;
        msgbox('No more annotations. Hit save if you''d like to save.','End of Events')
    end
    
    if setup.noMoreAnnotations==0
        pad = 5;
        %Get data with pad seconds on each side
        if setup.needZoomX %start and stops already defined, do not reset
            setup.needZoomX = 0;
        else
            setup.startIdx = setup.annotations(setup.annIdx).start/1e6*setup.sf-pad*setup.sf;   % in samples
            if setup.startIdx < 1
                setup.startIdx = 1;
            end
            setup.stopIdx = setup.annotations(setup.annIdx).stop/1e6*setup.sf+pad*setup.sf;
        end

        dataLength = double(setup.stopIdx - setup.startIdx);
        setup.decimation = max([1 round((0.5*dataLength)/width)]); %2 datapoints per pixel

        % Get Data
        data = aux.getvalues(setup.startIdx:setup.stopIdx,setup.channels);
        % If the getdata method returns a structure, get the data property.
        if isstruct(data)
            data = double(data.data);
        else
            data = double(data);
        end
        
        time = double((setup.startIdx:setup.stopIdx))./setup.sf;  % in seconds from start of mef file
        days = floor(time(1)/60/60/24) + 1;
        hour = floor( (time(1) - (days-1)*24*60*60) /60/60);
        minute = floor( (time(1) - (days-1)*24*60*60 - hour*60*60) /60);
        second = floor( (time(1) - (days-1)*24*60*60 - hour*60*60 - minute*60) );

        actualTime = datestr( (setup.annotations(setup.annIdx).start/1e6 - 5)/60/60/24 + setup.startSystem, 'mm/dd/yyyy HH:MM:SS');
        time = time - time(1) + str2double(actualTime(18:19));
        
        if isempty(setup.center)
            setup.center = nanmean(data);
            setup.compression = max(max(data) - nanmean(data));
        end
        if setup.decimation > 1
            data = data(1:setup.decimation:end,:);
            time = time(1:setup.decimation:end);
        end
        colororder = [
            0.00  0.00  1.00
            0.00  0.50  0.00 
            1.00  0.00  0.00 
            0.00  0.75  0.75
            0.75  0.00  0.75
            0.75  0.75  0.00 
            0.25  0.25  0.25
            0.75  0.25  0.25
            0.95  0.95  0.00 
            0.25  0.25  0.75
            0.75  0.75  0.75
            0.00  1.00  0.00 
            0.76  0.57  0.17
            0.54  0.63  0.22
            0.34  0.57  0.92
            1.00  0.10  0.60
            0.88  0.75  0.73
            0.10  0.49  0.47
            0.66  0.34  0.65
            0.99  0.41  0.23
            ];
        tmpchan = ismember(setup.chanLabels,{setup.annotations(setup.annIdx).channels.label}');
        %colorrgb = [0 0 1];
        for i =1: length(setup.channels)
             aux = (data(:,i)'-setup.center(i))./setup.compression + i;

            if tmpchan(i) == 1
                startTime = setup.annotations(setup.annIdx).start/1e6;
                stopTime = setup.annotations(setup.annIdx).stop/1e6;
                %set(setup.rhandles,'XData',[startTime stopTime stopTime startTime],'Ydata',[min(aux) min(aux) max(aux) max(aux)],'FaceColor',grey,'EdgeColor', grey,'FaceAlpha',0.5);
                set(setup.rhandles(1),'XData',[startTime startTime],'Ydata',ylim,'Color', [1 0 0]);
                set(setup.rhandles(2),'XData',[stopTime stopTime],'Ydata',ylim,'Color',[1 0 0]);
                set(setup.rhandles(1),'userdata',i)
                set(setup.rhandles(2),'userdata',i); 
                %set line color to green
                set(setup.lhandles(i),'XData',time, 'YData',aux,'Color','k','LineWidth',1.5);
             else
                set(setup.lhandles(i),'XData',time, 'YData',aux,'Color',colororder(mod(i,20)+1,:),'LineWidth',1.25);
             end
        end
        
        set(axesHandle,'XLim',[min(time) max(time)]);
%         set(axesHandle,'XMajorGrid','on');
%         yscaleText = sprintf('[ %3.5f %s/div ]',...
%         setup.objHandles.attr.gain*(setup.compression), ...
%         setup.objHandles.attr.units);
        yscaleText = sprintf('[ %3.5f %s/div ]',...
            (setup.compression), ...
            'uV');

        cp = findobj(get(gcf,'Children'),'Tag','cenP');  
        
        A2 =findobj(cp,'Tag','y-scale'); 
        set(A2,'String',yscaleText);
        
%         A3 = findobj(cp,'Tag','decimation');
%         set(A3,'String',sprintf('[Decimation: %i ]',setup.decimation));
        
        A4 = findobj(cp,'Tag','annotation');
        set(A4,'String',sprintf('[Annotation: %i / %i]',setup.annIdx,numel(setup.annotations)));
        
        if setup.annotLabel(setup.annIdx)==0
            dispLabel='Unmarked';
            rgbVal=[0.8 0.8 0.8];
        elseif setup.annotLabel(setup.annIdx)==1
            dispLabel='Seizure';
            rgbVal=[0 1 0];
        elseif setup.annotLabel(setup.annIdx)==2
            dispLabel='Artifact';
            rgbVal=[1 1 0];
%         elseif setup.annotLabel(setup.annIdx)==3
%             dispLabel='Incorrect';
%             rgbVal=[1 0 0];
        end
        
        A5 = findobj(cp,'Tag','label');
        set(A5,'String',sprintf('[Current Label: %s ]',dispLabel),'BackgroundColor',rgbVal);
        
        A6 = findobj(cp,'Tag','portalTime');
        set(A6,'String',sprintf('[Portal Time: %02d:%02d:%02d:%02d ]',days,hour,minute,second));

        A7 = findobj(cp,'Tag','realTime');
        set(A7,'String',sprintf('[Real Time: %s ]',actualTime));

    end
    
    guidata(src, setup);
end

function updateEvents(src)			
  % This function iterates over all eventButtons defined in the
  % eventButtons array in the guidata. It is easy to add new event
  % buttons to the gui just by placing them in this array and follow the
  % correct syntax requirements.
  
  setup = guidata(src);
  for i = 1: length(setup.eventButtons)

    % Only update when button is in 'on'-mode.
    ButtonUserData = get(setup.eventButtons(i),'userData');
    if ButtonUserData{1} 
      if ButtonUserData{3}
        DoubleEvent_update(setup.eventButtons(i));
        
        % Not used for IEEG-CODE, yet...
%         switch ButtonUserData{2}.type
%           case 'DoubleEvent'
%             DoubleEvent_update(setup.eventButtons(i));
%           case 'SingleEvent'
%             SingleEvent_update(setup.eventButtons(i));
%           case 'SingleMarker'
%             SingleMarker_update(setup.eventButtons(i));
%           otherwise
%             eval(sprintf('%s_update(src)',get(setup.eventButtons(i),'Tag')));
%         end
      else
        eval(sprintf('%s_update(src)',get(setup.eventButtons(i),'Tag')));
      end
    end
  end
end

%% METHODS FOR GUI BUTTON CALLBACKS
function EventLbl(src, ~)
    setup = guidata(src);
    %Add annotation index to label vector
    setup.annotLabel(setup.annIdx) = 1;
    %Go to next annotation
    setup.annIdx = setup.annIdx + 1;

    guidata(src, setup)
    updateRaw(src)
    Center(src)
end

function ArtifactLbl(src, ~)
    setup = guidata(src);
    %Add annotation index to label vector
    setup.annotLabel(setup.annIdx) = 2;
    %Go to next annotation
    setup.annIdx = setup.annIdx + 1;
    
    guidata(src, setup)
    updateRaw(src)
    Center(src)
end

% function IncorrectLbl(src, ~)
%     setup = guidata(src);
%     %Add annotation index to label vector
%     setup.annotLabel(setup.annIdx) = 3;
%     %Go to next annotation
%     setup.annIdx = setup.annIdx + 1;
% 
%     guidata(src, setup)
%     updateRaw(src)
%     Center(src)
% end

function SaveAnnot(src, ~)
    setup = guidata(src);
    
    numUnmarked=sum(setup.annotLabel(setup.savedIdx+1:end)==0);
    if numUnmarked>0
        choice = questdlg(['There are ',num2str(numUnmarked),' unmarked events that have not been vetted'],...
                'Unmarked Events','Save anyway', 'Return without saving','Save anyway');
    else
        choice = 'Save anyway';
    end
    
    if strcmp(choice,'Save anyway')
        snapshot = setup.objHandles;
        labels = {'seizure','artifact'};
%         labels = {'correct','uncertain','incorrect'};

        % upload annotations
        for i=1:numel(labels)
            outputLayer = sprintf('%s-%s', setup.outputLayer, labels{i});
            startTimes = [setup.annotations(setup.annotLabel == i).start]';
            stopTimes = [setup.annotations(setup.annotLabel == i).stop]';
            eventTimesUSec = [startTimes stopTimes];
            
            channels = {setup.annotations(setup.annotLabel == i).channels}';
            eventChannels = cell(length(channels),1);
            for j = 1: size(channels, 1)
              % tmpchan = ismember(setup.chanLabels,{setup.annotations(setup.annIdx).channels.label}')
              eventChannels{j} = find(ismember(setup.chanLabels,{channels{j}.label}'))';
            end
%             eventLabels = cellstr(repmat(labels{i}, length(channels), 1));
            uploadAnnotations(snapshot, outputLayer, eventTimesUSec, eventChannels, labels{i})
        end
%        setup.savedIdx=setup.savedIdx+setup.annIdx;
%        msgbox('Label annotations saved to IEEG Portal','Success!');
       
    else
        msgbox('Annotations not saved','Retry','warn');
    end
    
%     if strcmp(choice,'Save anyway')
%         snapshot = setup.objHandles;
%         labels = {'event','artifact'};
% %         labels = {'correct','uncertain','incorrect'};
% 
%         %extract annotations
%         for i=1:numel(labels)
%             layerName = [setup.savePrefix '-' labels{i}];
%             annot=setup.annotations(setup.annotLabel(setup.savedIdx+1:end)==i);
%             objs=[];
%             for p=1:length(annot)
%                 objs=[objs IEEGAnnotation.createAnnotations(annot(p).start,annot(p).stop,'Event',layerName,annot(p).channels)];
%             end
%             if ~isempty(objs)
%                 foundLayer = find(strcmp(layerName,{snapshot.annLayer.name}),1);
%                 if ~isempty(foundLayer)
%                     snapshot.annLayer(foundLayer).add(objs);
%                 else
%                     layer = snapshot.addAnnLayer(layerName);
%                     layer.add(objs);
%                 end
%             end
%         end
% 
%        setup.savedIdx=setup.savedIdx+setup.annIdx;
%        msgbox('Label annotations saved to IEEG Portal','Success!');
%        
%     else
%         msgbox('Annotations not saved','Retry','warn');
%     end
    
    guidata(src, setup);
end

function EraseAnnot(src,~)
    setup = guidata(src);
    
    choice = questdlg('Are you sure you want to erase all vetted labels?',...
                'Confirm Erase','Yes', 'No','No');
            
    if strcmp(choice,'Yes')
%         labels = {'correct','uncertain','incorrect'};
        labels = {'seizure','artifact'};
        snapshot = setup.objHandles;
        %for each label, find existing layer and remove
        for i = 1:numel(labels)
            outputLayer = setup.outputLayer;
            foundLayer = find(strcmp(outputLayer,{snapshot.annLayer.name}),1);
            if ~isempty(foundLayer)
                snapshot.removeAnnLayer(outputLayer);
            end
        end
        msgbox('Label annotations erased','Success!');
    end
    
    guidata(src, setup);
end

function ZoomInY(src, ~)            
    setup = guidata(src);
    
    oldCompress = setup.compression;
    setup.compression = oldCompress - 0.25*oldCompress;
    
    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData');
        aux = aux - i;
        aux = aux * (oldCompress./setup.compression);
        set(setup.lhandles(i),'YData', aux +i);   
        
      %  if get(setup.rhandles(1),'userdata')== i
     %       set(setup.rhandles(1),'Ydata',[min(aux+i) max(aux+i)],'Color', [1 0 0]);
     %       set(setup.rhandles(2),'Ydata',[min(aux+i) max(aux+i)],'Color',[1 0 0]);
     %   end
    end
    
    yscaleText = sprintf('[ %3.5f %s/div ]',...
      1*(setup.compression), ...
      'uV');
    cenP = findobj(get(gcf,'Children'),'Tag','cenP');   
    A2 = findobj(cenP,'Tag','y-scale');
    set(A2,'String',yscaleText);
    

    guidata(src, setup)
end

function ZoomOutY(src, ~)           
    setup = guidata(src);
    
    oldCompress = setup.compression;
    setup.compression = oldCompress + 0.25*oldCompress;
    
    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData');
        aux = aux - i;
        aux = aux * (oldCompress./setup.compression);
        set(setup.lhandles(i),'YData', aux +i);    
  %      if get(setup.rhandles(1),'userdata')== i
    %        set(setup.rhandles(1),'Ydata',[min(aux+i) max(aux+i)],'Color', [1 0 0]);
    %        set(setup.rhandles(2),'Ydata',[min(aux+i) max(aux+i)],'Color',[1 0 0]);
    %    end
    end
    yscaleText = sprintf('[ %3.5f %s/div ]',...
      (setup.compression), ...
      'uV');
    cenP = findobj(get(gcf,'Children'),'Tag','cenP');   
    A2 = findobj(cenP,'Tag','y-scale');
    set(A2,'String',yscaleText);
    guidata(src, setup)
end

function ZoomInT(src, ~)            
    %set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);
    
    lData = setup.stopIdx - setup.startIdx + 1;
    newLength = round(lData * 0.9);
    lDiff = lData-newLength;
    setup.startIdx = setup.startIdx+round(lDiff/2);
    setup.stopIdx = setup.stopIdx - round(lDiff/2);
    setup.needZoomX= 1;
    guidata(src, setup);
    
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');
end

function ZoomOutT(src, ~)           

    %set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);
    
    lData = setup.stopIdx - setup.startIdx +1;
    newLength = round(lData * 1.1);
    lDiff = lData-newLength;
    setup.startIdx = setup.startIdx+round(lDiff/2);
    setup.stopIdx = setup.stopIdx - round(lDiff/2);
    setup.needZoomX= 1;
    guidata(src, setup);
    
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');
end

function Center(src, ~)             
    setup = guidata(src);

    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData') - i;
        aux = aux * setup.compression;
        aux = aux + setup.center(i);
        newMean =aux(1);
        setup.center(i) = newMean;
        set(setup.lhandles(i),'YData',(aux - newMean)./setup.compression+i);
    end

    guidata(src,setup);
    updateEvents(src);
end

function NextEvnt(src, ~, direction)

    setup = guidata(src);
    if (direction==true)
        if setup.annIdx>=setup.totalAnn
            msgbox('No annotations after this','End of Events')
        else
            if setup.noMoreAnnotations==0
                setup.annIdx=setup.annIdx+1;
            end
        end
        
    elseif (direction==false)
        if setup.annIdx<=1
            msgbox('No annotations before this','End of Events')
        else
            if setup.noMoreAnnotations==1
                setup.noMoreAnnotations=0;
            end
            setup.annIdx=setup.annIdx-1;
        end
    end
    
    guidata(src, setup)
    updateRaw(src)
    Center(src)
    
end

function PrintPDF(~,~)              
  % Generate new figure and copy the axes. The print figure to pdf and
  % delete the figure...

  curFig = gcbf;
  cenP = findobj(get(curFig,'Children'),'Tag','cenP');
  A = findobj(get(cenP,'Children'),'Tag','plotWindow');

  topP = findobj(get(curFig,'Children'),'Tag','topP');
  T = findobj(get(topP,'Children'),'Tag','title');
  ttl = get(T,'String');

  [FileName,PathName,~] = uiputfile({'*.pdf'},'Select PDF FileName','RawViewFig.pdf');

  if ~isempty(FileName)
    aux = get(A,'Position');

    NF = figure('PaperUnits','centimeters','PaperSize',[aux(3)+4 aux(4)+4],...
        'PaperPositionMode','manual',...
        'PaperPosition',[0 0  aux(3)+5 aux(4)+5],...
        'renderer','painters',...
        'Visible','off');

    h = copyobj(A, NF);
    set(h,'Box','on');
    set(h,'Position',[2,2,aux(3),aux(4)]);
    title(h,ttl,'Interpreter','none','HorizontalAlignment','center','FontSize',12);
    print(NF,'-dpdf',fullfile(PathName,FileName));
    delete(NF);
  end
end



% function PushForwards(src, ~)       
%     set(src, 'Enable','off');
%     drawnow update
%     setup = guidata(src);
%     
%     if ~isempty(setup.eventOffsetLine)
%         delete(setup.eventOffsetLine);
%         setup.eventOffsetLine = [];
%     end
%     
%     ldata = setup.stop - setup.start +1;
%     stripPoint = round(ldata*0.75);
%     newLength = ldata - stripPoint;
%     
%     setup.start = setup.start + newLength;
%     setup.startTime = double(setup.start)./setup.sf;
%     setup.stop  = setup.stop + newLength;
%     
%     guidata(src, setup);
%     updateRaw(src);
%     updateEvents(src);
%     set(src, 'Enable','on');   
% end
% 
% function PushBackwards(src, ~)      
%   try
%     set(src, 'Enable','off');
%     drawnow update
%     setup = guidata(src);
% 
%     if ~isempty(setup.eventOffsetLine)
%         delete(setup.eventOffsetLine);
%         setup.eventOffsetLine = [];
%     end
% 
%     ldata = setup.stop - setup.start +1;
%     stripPoint = round(ldata*0.25);
%     newLength = stripPoint;
% 
%     setup.start = setup.start - newLength;
%     setup.startTime = double(setup.start)./setup.sf;
%     setup.stop  = setup.stop - newLength;
%         
%     % Prevent negative start times.
%     if setup.start < 1
%       setup.stop = setup.stop - setup.start;
%       setup.start = 1;
%       setup.startTime = 0;
%     end
%     
%     guidata(src, setup);
%     updateRaw(src);
%     updateEvents(src);
%     set(src, 'Enable','on');  
% 
%   catch ME 
%     set(src, 'Enable','on');
%     rethrow(ME);
%   end
% end
% 
% function ToggleNEventButton(src,~)  
%         
%     setup = guidata(src);
%     names = get(setup.eventButtons,'String');
%     
%     props = get(setup.eventButtons,'UserData');
%     
%     if size(props,1) == 1
%       active = props{1};
%       if active
%         names  = {names};
%       else
%         names  = {};
%       end
%     else
%       active = cellfun(@(x) x{1},props) >0;
%       names = names(active);
%     end
%     
%     if isempty(names)
%         set(src,'String','-','UserData',0);
%     else
%         index = get(src, 'UserData') + 1;
%         if index > length(names); index=1;end
%         set(src, 'String', names{index}, 'UserData', index);
%     end
%         
% end
% 
% function toggleEventButton(src,~)   
% 
%   % 4 States: Off - Event Time - Event Time/value - Event Value
%   setup = guidata(src);
%   UD = get(src,'userData');
%   UD{1} = mod(UD{1}+1,2);
%   switch UD{1}
%     case 0 % off
%       Bcolor = [0 0 0 ];
%     case 1 % event times
%       Bcolor = [0 0.5 0];
%       
%       % Only two states are used, on/off... 
% %     case 2 % event times/value
% %       Bcolor = [0.5 0 0];
% %     case 3 % event values
% %       Bcolor = [0 0 0.5];
%   end
% 
%   set(src,'userData', UD,'ForegroundColor', Bcolor);
%   if UD{1}
%     updateEvents(src);
%   else
%     try
%       lineName = sprintf('%s_lines',genvarname(get(src,'Tag')));
%       aux = setup.(lineName);
%       delete(aux);
%       setup = rmfield(setup, lineName);
%     catch %#ok<CTCH>
%     end
%     try
%       textName = sprintf('%s_text',genvarname(get(src,'Tag')));
%       aux = setup.(textName);
%       delete(aux);
%       setup = rmfield(setup, textName);
%     catch %#ok<CTCH>
%     end
% 
%     guidata(src,setup);
%   end
% end

%% METHODS FOR EVENT BUTTON CALLBACKS
function DoubleEvent_update(src, varargin)             
    
  % This methods creates timer and updates 50 annotations per callback.
  % Downloaded annotations are stored in the userdata and assumed to be
  % continuous. That is: the array contains all available annotations
  % between the first and the last downloaded annotation for all channels.
  % This allows us to reuse annotations that have been previously
  % downloaded. 
  %
  % The viewer does not automatically refresh if annotations
  % have been changed on the server.


  setup = guidata(src);

  %Get eventButtonName
  eventButtonName = genvarname(get(src,'String'));

  % Create line-objects for associated events if they do not exist.
  if ~isfield(setup, [eventButtonName '_lines'])
    setup.([eventButtonName '_lines']) = zeros(length(setup.lhandles),1);
    setup.([eventButtonName '_text']) = [];
    for iEvnt=1: length(setup.lhandles)
      setup.([eventButtonName '_lines'])(2*(iEvnt-1)+1) = line('Color','g','XData',[],'YData',[],'LineWidth',2);
      setup.([eventButtonName '_lines'])(2*(iEvnt-1)+2) = line('Color','r','XData',[],'YData',[],'LineWidth',2);
    end
  else
    aux = setup.([eventButtonName '_text']);
    if ~isempty(aux)
      delete(aux);
    end
    setup.([eventButtonName '_text']) = [];
  end

  % Update the events in the current window.
  usrData = get(src, 'userData');
  startT = 1e6 * setup.start/setup.sf;
  stopT  = 1e6 * setup.stop/setup.sf;
  channels = setup.objHandles.channels(setup.cols);
  annlayer = usrData{2};
  
  
  % Request Annotations from portal.
  REQUESTSIZE = 50;
  annotations = IEEGAnnotation.empty;
  getT = startT;
  while 1
    newAnn = annlayer.getEvents(getT, channels, REQUESTSIZE);
    annotations = [annotations newAnn]; %#ok<AGROW>
    
    if isempty(annotations)
      break
    elseif length(newAnn) < REQUESTSIZE || annotations(end).start > stopT
      break
    end    
    getT = newAnn(end).start;
  end
  
  % Get annotations prior to timeslice;
  while 1
    % Get annotations prior to previously fetched annotations if available,
    % otherwise, try to get annotations before starttime.
    if ~isempty(annotations)
      newAnn = annlayer.getPreviousEvents(annotations(1), channels, REQUESTSIZE);
    else
      newAnn = annlayer.getPreviousEvents(getT, channels, REQUESTSIZE);
    end
    
    annotations = [newAnn annotations]; %#ok<AGROW>
    
    if isempty(annotations)
      break
    elseif annotations(1).start < startT
      break
    elseif length(newAnn) < REQUESTSIZE
      break
    end
  
  end
  
  % If this is a empty layer, return
  if isempty(annotations)
    return
  end
  
  % Populate vector with event-times in Button-UserData
  usrData{4} = [annotations.start];
  set(src, 'userData', usrData);

  % Create lines for each channel.
  for iChan = 1:length(channels)
    % Find which annotations are in current channel.
    inchannel = false(length(annotations),1);
    for iAnn = 1: length(annotations)
      inchannel(iAnn) = any(annotations(iAnn).channels == channels(iChan));
    end
    
    % Create annotation start/stop vector and render results.
    startvec = [annotations(inchannel).start]./1e6;
    stopvec = [annotations(inchannel).stop]./1e6;

    [xvals, yvals, ~] = getRasterXY(startvec, iChan, 0.5);
    set(setup.([eventButtonName '_lines'])(2*(iChan-1)+1),'XData',xvals,'YData',yvals);

    [xvals, yvals, ~] = getRasterXY(stopvec, iChan, 0.5);
    set(setup.([eventButtonName '_lines'])(2*(iChan-1)+2),'XData',xvals,'YData',yvals);
  end

  
  guidata(src,setup);

end

%% GENERATING RASTER OBJECT METHOD
function [xvals,yvals,yCenter] = getRasterXY(ts,Offset,Spacing,LineLength,Start)
  %getRasterXY  get x & y values for quick raster plotting
  %   [XVALS,YVALS,YCENTER] = getRasterXY(TS,OFFSET,SPACING,LINE_LENGTH,START)
  %   uses the function YCENTER = OFFSET + SPACING*(START-1) to determine the
  %   height at which the raster line will be centered.  From their YVALS extend 
  %   from YCENTER - LINE_LENGTH/2 to YCENTER + LINE_LENGTH/2.  This format allows
  %   one to specify an intended starting OFFSET, and the START input can be used
  %   in a loop to iterate through different TS values.  TS is a vector of time events.
  %
  %   [...] = getRasterXY(TS,YCENTER,LINE_LENGTH) uses the specified YCENTER
  %   instead of that calculated by SPACING & START
  %
  if nargin == 3
      yCenter = Offset;
      LineLength = Spacing;
  elseif nargin == 5
      yCenter = Offset + Spacing*(Start-1);
  else
      error('Incorrect # of inputs')
  end

  l = length(ts);
  nans = NaN*ones(l,1);

  xvals = zeros(3*l,1);
  xvals(1:3:(3*l)) = ts;
  xvals(2:3:(3*l)) = ts;
  xvals(3:3:(3*l)) = nans;

  yvals = zeros(3*l,1);
  yvals(1:3:(3*l)) = zeros(l,1) + yCenter - (LineLength/2);
  yvals(2:3:(3*l)) = zeros(l,1) + yCenter + (LineLength/2);
  yvals(3:3:(3*l)) = nans;
end
