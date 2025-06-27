function [rel_info_list]=processFolder_brute(folderPath)

%   Process all images from Folder by testing ALL images with eachother via
%   'estimateHomographymatrixFromSatelite'. Stores the relative infomration
%   every image and every other image. (Only test 3->4 and not 4->3 to save
%   compute and leverage interchangeability.
%
% Inputs:
%   Path to Folder
%
% Outputs:
%   rel_info_list-> Contains for every image pair the: H, the inliner Points of H, 
%                   the name of compaired images and the number of inlier Points as 
%                   quality measure.

    imageFiles = dir(fullfile(folderPath, '*.jpg'));  % Change extension if needed
    if isempty(imageFiles)
        error('No image files found in the folder: %s', folderPath);
    end


    numImages = length(imageFiles);

    if numImages < 2
        error('Need at least two images to estimate homographies.');
    end

    % Preallocate cell array for homography matrices
   rel_info_list = {};  % Initialize as cell array
    counter = 1;         % Track stored pairs

    for i = 1:numImages-1  % Only go up to numImages-1 (since j starts at i+1)
        img1 = imread(fullfile(folderPath, imageFiles(i).name));
        
        for j = i+1:numImages  % Compare only with j > i
            img2 = imread(fullfile(folderPath, imageFiles(j).name));
            
            % Estimate homography
            [H, inlierPts1, inlierPts2] = estimateHomographyMatrixFromSatelliteImages(img1, img2);
            
            % Store results
            rel_info_list{counter}.H = H;
            rel_info_list{counter}.inlierPts1 = inlierPts1;
            rel_info_list{counter}.inlierPts2 = inlierPts2;
            rel_info_list{counter}.comp_pair = [i, j];  % Store the compared indices
            rel_info_list{counter}.quality = size(inlierPts1, 1);  % Number of inliers
            
            counter = counter + 1;
        end
    end

end