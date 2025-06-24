function [H, inlierPts1, inlierPts2] = estimateHomographyMatrixFromSatelliteImages(img1, img2)
% estimateHomographyMatrixFromSatelliteImages
%   Estimates the homography matrix between two planar satellite images
%   with different rotation, translation, and lighting conditions.
%
% Inputs:
%   img1, img2 - RGB satellite images
%
% Outputs:
%   H          - 3x3 homography matrix (maps points from img2 to img1)
%   inlierPts1 - matched points in img1 (Nx2 array)
%   inlierPts2 - matched points in img2 (Nx2 array)

    % convert to grayscale
    gray1 = rgb2gray(img1);
    gray2 = rgb2gray(img2);

    % potentially use other feature point extraction method here:
    % Detect SURF features: extract feature location and size
    points1 = detectSURFFeatures(gray1, 'MetricThreshold', 500);
    points2 = detectSURFFeatures(gray2, 'MetricThreshold', 500);
    % extractFeatures: extract feature patch around the feature locations, align it to the
    % dominant gradient direction and normalize it
    [features1, validPts1] = extractFeatures(gray1, points1);
    [features2, validPts2] = extractFeatures(gray2, points2);

    % Match features with Lowe's ratio test: lower MaxRatio means more
    % picky (higher probability that matches are correct but also less
    % matches in general)
    indexPairs = matchFeatures(features1, features2, 'MaxRatio', 0.6, 'Unique', true);

    % split into two arrays
    matchedPts1 = validPts1(indexPairs(:,1));
    matchedPts2 = validPts2(indexPairs(:,2));

    % remove matched points in the bottom left corner cause of the google watermark
    x_thresh = 180; 
    y_thresh = size(img1,1) - 80; 
    mask1 = ~(matchedPts1.Location(:,1) < x_thresh & matchedPts1.Location(:,2) > y_thresh);
    mask2 = ~(matchedPts2.Location(:,1) < x_thresh & matchedPts2.Location(:,2) > y_thresh);
    validMask = mask1 & mask2;
    matchedPts1 = matchedPts1(validMask);
    matchedPts2 = matchedPts2(validMask);
    
    % estimate homography using ransac
    [tform, inlierIdx] = estimateGeometricTransform2D(matchedPts2, matchedPts1, ...
        'projective', 'MaxNumTrials', 2000, 'Confidence', 99.9, 'MaxDistance', 4);

    % extract homography matrix
    H = tform.T;
    
    % extract inlier points as Nx2 arrays
    inlierPts1 = matchedPts1(inlierIdx).Location;
    inlierPts2 = matchedPts2(inlierIdx).Location;
end