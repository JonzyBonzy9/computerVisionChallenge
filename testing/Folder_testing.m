% add src to path
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));

% test function for calling folder
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));
path=fullfile(scriptDir,'..','data','Datasets','Dubai');
output=processFolder(path);
