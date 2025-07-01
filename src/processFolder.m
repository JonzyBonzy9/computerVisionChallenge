% TODO optimize the sorting method (sorting by file names may fail in some
% cases)

function [rel_info_list]=processFolder(folderPath)
%   Process all images from Folder by giving two consecutive images to
%   'estimateHomographymatrixFromSatelite'. Stores the relative infomration between the
%    consecutive images.
%
% Inputs:
%   Path to Folder
%
% Outputs:
%   rel_info_list -> Contains H, the inliner Points of H, the compaired
%   images and the number of inlier Points as quality measure

    imageFiles = dir(fullfile(folderPath, '*.jpg')); % TODO make this more robust
    if isempty(imageFiles)
        error('No image files found in the folder: %s', folderPath);
    end

    % Sort files by name (Give chronological order, starting with oldest)
    [~, idx] = sort({imageFiles.name});
    imageFiles = imageFiles(idx);

    numImages = length(imageFiles);

    if numImages < 2
        error('Need at least two images to estimate homographies.');
    end

    % Preallocate cell array for homography matrices
    rel_info_list = cell(numImages - 1, 1);

    % Loop over consecutive image pairs
    for i = 1:numImages-1
        % Read image i and image i+1
        img1 = imread(fullfile(folderPath, imageFiles(i).name));
        img2 = imread(fullfile(folderPath, imageFiles(i+1).name));

        % Estimate homography
        [H, inlierPts1, inlierPts2, accuracyScore] = estimateHomographyMatrixFromSatelliteImages(img1, img2);

        % Store result (Maybe we need more/less lets see)
        rel_info_list{i}.H = H;
        rel_info_list{i}.inlierPts1 = inlierPts1; 
        rel_info_list{i}.inlierPts2 = inlierPts2;
        rel_info_list{i}.comp_pair=[imageFiles(i).name,'_',imageFiles(i+1).name];
        rel_info_list{i}.accuracyScore=accuracyScore;  % Possible quality measure for H
    end

end