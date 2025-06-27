% test function for calling folder

scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));
path='/Users/pauljegen/Uni/TUM/Semester_2/Computer_Vision/Datasets/Frauenkirche';
output=processFolder(path);
