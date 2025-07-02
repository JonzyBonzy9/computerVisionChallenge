% TODO add some error handling

function [H, inlierPts1, inlierPts2, inlierRatio] = estimateHomographyPair(img1, img2)
% estimateHomographyPair
%   Estimates the homography matrix between two planar satellite images
%   with different rotation, translation, and lighting conditions.
%
% Inputs:
%   img1, img2 - RGB satellite images
%
% Outputs:
%   H             - 3x3 homography matrix (maps points from img2 to img1)
%   inlierPts1    - matched inlier points in img1 (Nx2 array)
%   inlierPts2    - matched inlier points in img2 (Nx2 array)
%   inlierRatio   - return ratio of length inlier points / length matched
%   points (double)

    % Convert to grayscale
    gray0 = rgb2gray(img1);
    gray1 = rgb2gray(img2);

    % Detect SURF features with metric threshold
    points1 = detectSURFFeatures(gray0, 'MetricThreshold', 500);
    points2 = detectSURFFeatures(gray1, 'MetricThreshold', 500);

    % Extract features around detected points
    [features1, validPts1] = extractFeatures(gray0, points1);
    [features2, validPts2] = extractFeatures(gray1, points2);

    % Match features with Lowe's ratio test
    indexPairs = matchFeatures(features1, features2, 'MaxRatio', 0.6, 'Unique', true);

    % Get matched points
    matchedPts1 = validPts1(indexPairs(:,1));
    matchedPts2 = validPts2(indexPairs(:,2));

    % Remove points in bottom-left corner due to watermark
    x_thresh = 180; 
    y_thresh = size(img1,1) - 80; 
    mask1 = ~(matchedPts1.Location(:,1) < x_thresh & matchedPts1.Location(:,2) > y_thresh);
    mask2 = ~(matchedPts2.Location(:,1) < x_thresh & matchedPts2.Location(:,2) > y_thresh);
    validMask = mask1 & mask2;
    matchedPts1 = matchedPts1(validMask);
    matchedPts2 = matchedPts2(validMask);

    % Estimate homography with RANSAC
    [tform, inlierIdx] = estimateGeometricTransform2D(matchedPts2, matchedPts1, ...
        'projective', 'MaxNumTrials', 2000, 'Confidence', 99.9, 'MaxDistance', 4);

    % Extract homography matrix
    H = tform.T;

    % Extract inlier points as Nx2 arrays
    inlierPts1 = matchedPts1(inlierIdx).Location;
    inlierPts2 = matchedPts2(inlierIdx).Location;

    % Calculate inlierRatio
    inlierRatio = length(inlierPts1)/length(matchedPts1);
end

