function parsave(varargin)
% Allows filesave in a parfor loop
<<<<<<< HEAD
% Hoameng Ung 2015, modified from Erik (matlab central)
% First argument = save file name
% Other arguments: strings of each variable to save
% Usage: parsave('test.mat','subject','data','flag')
    savefile = varargin{1}; 
    for i=2:nargin
        tosave.(inputname(i)) = varargin{i}; %
    end
    save(savefile,'-struct','tosave')
=======
% Hoameng Ung 2015
% First argument = save file name
% Other arguments: strings of each variable to save
% Usage: parsave('test.mat','subject','data','flag')
    savefile = varargin{1}; % first input argument
    for i=2:nargin
        savevar.(inputname(i)) = varargin{i}; % other input arguments
    end
    save(savefile,'-struct','savevar')
>>>>>>> 45667d6cb1273defd11272f8308fddcc159728fe
end