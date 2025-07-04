function [H, inlierPts1, inlierPts2, inlierRatio] = estimateHomographyPair(img1, img2, varargin)
% estimateHomographyPair
%   Estimates the homography matrix between two planar satellite images
%   with different rotation, translation, and lighting conditions.
%
% Inputs:
%   img1, img2 - RGB satellite images
%   Optional name-value pair arguments:
%     'MetricThreshold' - SURF detector metric threshold (default: 500)
%     'MaxRatio'        - Lowe's ratio for feature matching (default: 0.6)
%     'MaxNumTrials'    - RANSAC max trials (default: 2000)
%     'Confidence'      - RANSAC confidence (default: 99.9)
%     'MaxDistance'     - RANSAC max reprojection error (default: 4)
%
% Outputs:
%   H             - 3x3 homography matrix (maps points from img2 to img1)
%   inlierPts1    - matched inlier points in img1 (Nx2 array)
%   inlierPts2    - matched inlier points in img2 (Nx2 array)
%   inlierRatio   - ratio of inlier points / matched points

    % Parse optional parameters with defaults
    p = inputParser;
    addParameter(p, 'MetricThreshold', 500, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MaxRatio', 0.6, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
    addParameter(p, 'MaxNumTrials', 2000, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Confidence', 99.9, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 100);
    addParameter(p, 'MaxDistance', 4, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, varargin{:});

    % Initialize outputs in case of failure
    H = eye(3);
    inlierPts1 = [];
    inlierPts2 = [];
    inlierRatio = 0;

    % Convert to grayscale
    gray0 = rgb2gray(img1);
    gray1 = rgb2gray(img2);

    % Detect SURF features with metric threshold
    points1 = detectSURFFeatures(gray0, 'MetricThreshold', p.Results.MetricThreshold);
    points2 = detectSURFFeatures(gray1, 'MetricThreshold', p.Results.MetricThreshold);

    % Check for enough features
    if points1.Count < 2 || points2.Count < 2
        warning('Not enough SURF features detected in one or both images.');
        return;
    end

    % Extract features around detected points
    [features1, validPts1] = extractFeatures(gray0, points1);
    [features2, validPts2] = extractFeatures(gray1, points2);

    % Match features with Lowe's ratio test
    indexPairs = matchFeatures(features1, features2, 'MaxRatio', p.Results.MaxRatio, 'Unique', true);

    % Check for matches
    if isempty(indexPairs)
        warning('No matched features found between images.');
        return;
    end

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

    % Check again if enough matches remain
    if matchedPts1.Count < 4
        warning('Not enough valid matched points after masking.');
        return;
    end

    % Estimate homography with RANSAC
    try
        [tform, inlierIdx] = estimateGeometricTransform2D(matchedPts2, matchedPts1, ...
            'projective', ...
            'MaxNumTrials', p.Results.MaxNumTrials, ...
            'Confidence', p.Results.Confidence, ...
            'MaxDistance', p.Results.MaxDistance);
    catch ME
        warning('Homography estimation failed: %s', ME.message);
        return;
    end

    % Extract homography matrix
    H = tform.T;

    % Extract inlier points as Nx2 arrays
    inlierPts1 = matchedPts1(inlierIdx).Location;
    inlierPts2 = matchedPts2(inlierIdx).Location;

    % Calculate inlierRatio
    inlierRatio = length(inlierPts1)/length(matchedPts1);
end
