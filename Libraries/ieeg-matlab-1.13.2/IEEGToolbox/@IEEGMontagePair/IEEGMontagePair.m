classdef IEEGMontagePair <IEEGObject
    %IEEGMONTAGEPAIR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        source = '';
        ref = '';
    end    
   
    
    methods
    end
    
    methods(Access = protected, Sealed)
        function info = getdatainfo(obj) %#ok<MANU>
            info = struct('size',[nan nan], 'format', 'Unknown');
        end
        
        
    
     
    end
  
    methods(Static)
        function out = build(in)
            out = IEEGMontagePair();
            out.source = char(in.getEl1);
            out.ref = char(in.getEl2);
        end
    end
end

