function parsave(varargin)
% Allows filesave in a parfor loop
% Hoameng Ung 2015, modified from Erik (matlab central)
% First argument = save file name
% Other arguments: strings of each variable to save
% Usage: parsave('test.mat','subject','data','flag')
    savefile = varargin{1}; 
    for i=2:nargin
        tosave.(inputname(i)) = varargin{i}; %
    end
    save(savefile,'-struct','tosave')
end