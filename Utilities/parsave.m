function parsave(varargin)
% Allows filesave in a parfor loop
% Hoameng Ung 2015
% First argument = save file name
% Other arguments: strings of each variable to save
% Usage: parsave('test.mat','subject','data','flag')
    savefile = varargin{1}; % first input argument
    for i=2:nargin
        savevar.(inputname(i)) = varargin{i}; % other input arguments
    end
    save(savefile,'-struct','savevar')
end