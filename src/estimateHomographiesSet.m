function [rel_info_list]=estimateHomographiesSet(imageArray)
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
    
    % Sort images by their datetime 'id'
    ids = cellfun(@(x) x.id, imageArray);
    [~, sortIdx] = sort(ids);
    imageArray = imageArray(sortIdx);
    imageArray = imageArray(sortIdx);


    % Preallocate cell array for homography matrices
    rel_info_list = cell(numImages - 1, 1);
    
    % loop over image pairs
    for i = 1:numImages - 1
        img1 = imageArray{i}.data;
        img2 = imageArray{i + 1}.data;

        % Estimate homography
        [H, inlierPts1, inlierPts2, inlierRatio] = ...
            estimateHomographyPair(img1, img2);
        
        % store results
        rel_info_list{i} = struct( ...
            'H', H, ...
            'inlierPts1', inlierPts1, ...
            'inlierPts2', inlierPts2, ...
            'image1', imageArray{i}.data, ...
            'image2', imageArray{i+1}.data, ...
            'id1', imageArray{i}.id, ...
            'id2', imageArray{i + 1}.id, ...
            'inlierRatio', inlierRatio);
    end
end