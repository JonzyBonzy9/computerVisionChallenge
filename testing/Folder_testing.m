% add src to path
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));

% get path to image folder
folderPath = fullfile(scriptDir, '..', 'data', 'Datasets', 'Frauenkirche');
fileList = dir(fullfile(folderPath, '*.jpg'));
if isempty(fileList)
    error('No image files found.');
end

% read images into a cell array
imageArray = cell(1, length(fileList));
for i = 1:length(fileList)
    imageArray{i}.data = imread(fullfile(fileList(i).folder, fileList(i).name));
    imageArray{i}.id = fileList(i).name;
end

output = processFolder(imageArray);