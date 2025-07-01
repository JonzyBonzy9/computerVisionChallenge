function [rel_info_list]=processFolder(imageArray)
%   Process all images passed by giving two consecutive images to
%   'estimateHomographymatrixFromSatelite'. Stores the relative information
%   between the consecutive images.
%
% Inputs:
%   imageArray - Image Objects
%
% Outputs:
%   rel_info_list -> Contains H, the inliner Points of H, the names of the compaired
%   images and a quality score
    
    numImages = length(imageArray);
    if numImages < 2
        error('Need at least two images to estimate homographies.');
    end
    
    % TODO add some sorting method here, so that always similar images get compared
    % idea: calculate image similarity metric and use that (filenames are not
    % uniquely indexed across datasets)

    % Preallocate cell array for homography matrices
    rel_info_list = cell(numImages - 1, 1);
    
    % loop over image pairs
    for i = 1:numImages - 1
        img1 = imageArray{i}.data;
        img2 = imageArray{i + 1}.data;

        % Estimate homography
        [H, inlierPts1, inlierPts2, accuracyScore] = ...
            estimateHomographyMatrixFromSatelliteImages(img1, img2);
        
        % store results
        rel_info_list{i} = struct( ...
            'H', H, ...
            'inlierPts1', inlierPts1, ...
            'inlierPts2', inlierPts2, ...
            'id1', imageArray{i}.id, ...
            'id2', imageArray{i + 1}.id, ...
            'accuracyScore', accuracyScore);
    end
end