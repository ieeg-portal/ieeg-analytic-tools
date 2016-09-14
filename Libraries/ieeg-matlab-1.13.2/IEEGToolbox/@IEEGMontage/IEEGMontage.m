classdef IEEGMontage<IEEGObject
    %IEEGMONTAGE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties 
        name  = '';
        pairs = IEEGMontagePair.empty;
    end
    
    properties(SetAccess = private)
        channelMap = []; % 1x2 vector of mapped channel indices.
    end
    
    methods
    end
    
    methods(Access = protected, Sealed)
        function info = getdatainfo(obj) %#ok<MANU>
            info = struct('size',[nan nan], 'format', 'Unknown');
        end
    end
    
    methods(Static)
        function out = build(in, allChannels)
            
            % Get all Channel names
            allNames = {allChannels.label};
                        
            out = IEEGMontage();
            out.name = char(in.getName());
            
            p = in.getPairs();
            pIter = p.iterator;
            newPairArr(p.size) = IEEGMontagePair();
            mapArr = -1 * ones(p.size,2);
            
            ix = 0;
            while pIter.hasNext
                ix = ix+1;
                curPair = pIter.next;
                newPairArr(ix) = IEEGMontagePair.build(curPair);
                
                index1 = find(strcmp(allNames,char(curPair.getEl1)));
                index2 = find(strcmp(allNames,char(curPair.getEl2)));
                
                if isempty(index1); index1 = nan;end
                if isempty(index2); index2 = nan; end
                mapArr(ix,1:2) = [index1 index2];
                
            end
            
            if ix>0;
                out.pairs = newPairArr;
                out.channelMap = mapArr;
            end
            
        end
    end
    
end

