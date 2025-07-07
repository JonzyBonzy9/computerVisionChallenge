function [H, inlierPts1, inlierPts2, inlierRatio, success] = estimateHomographyPair(img1, img2, varargin)
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
    % get method
    addParameter(p, 'FeatureExtractionMethod', "SURF");
    % surf
    addParameter(p, 'MetricThreshold', 1000, @(x) isnumeric(x) && isscalar(x));
    % sift
    addParameter(p, 'ContrastThreshold', 0.01, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
    addParameter(p, 'EdgeThreshold', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'NumLayersInOctave', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x,1)==0);
    addParameter(p, 'Sigma', 1.6, @(x) isnumeric(x) && isscalar(x) && x > 0);
    % ransac
    addParameter(p, 'MaxRatio', 0.7, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
    addParameter(p, 'MaxNumTrials', 5000, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Confidence', 99.0, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 100);
    addParameter(p, 'MaxDistance', 6, @(x) isnumeric(x) && isscalar(x) && x > 0);
    % parse
    parse(p, varargin{:});
    
    % set seed
    rng(42);

    % Initialize outputs in case of failure
    H = eye(3);
    inlierPts1 = [];
    inlierPts2 = [];
    inlierRatio = 0;
    success = 1;

    % Convert to grayscale
    gray0 = rgb2gray(img1);
    gray1 = rgb2gray(img2);
    
    % extract features
    fprintf("Estimating homographies using %s\n", p.Results.FeatureExtractionMethod);
    switch upper(p.Results.FeatureExtractionMethod)
        case "SURF"
            points1 = detectSURFFeatures(gray0, 'MetricThreshold', p.Results.MetricThreshold);
            points2 = detectSURFFeatures(gray1, 'MetricThreshold', p.Results.MetricThreshold);
    
        case "SIFT"
            points1 = detectSIFTFeatures(gray0, ...
                'ContrastThreshold', p.Results.ContrastThreshold, ...
                'EdgeThreshold', p.Results.EdgeThreshold, ...
                'NumLayersInOctave', p.Results.NumLayersInOctave, ...
                'Sigma', p.Results.Sigma);
            points2 = detectSIFTFeatures(gray1, ...
                'ContrastThreshold', p.Results.ContrastThreshold, ...
                'EdgeThreshold', p.Results.EdgeThreshold, ...
                'NumLayersInOctave', p.Results.NumLayersInOctave, ...
                'Sigma', p.Results.Sigma);    
        otherwise
            error("Unsupported FeatureExtractionMethod: %s", p.Results.FeatureExtractionMethod);
    end

    % Check for enough features
    if points1.Count < 4 || points2.Count < 4
        warning('Not enough features detected in one or both images.');
        success = 0;
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
        success = 0;
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
        success = 0;
        return;
    end

    % Estimate homography with RANSAC
    try
        % Clear any previous warning state
        lastwarn('');  
        
        % Run RANSAC
        [tform, inlierIdx] = estimateGeometricTransform2D(matchedPts2, matchedPts1, ...
            'projective', ...
            'MaxNumTrials', p.Results.MaxNumTrials, ...
            'Confidence', p.Results.Confidence, ...
            'MaxDistance', p.Results.MaxDistance);
        
        % Check for relevant RANSAC warning
        [warnMsg, ~] = lastwarn;
        
        if contains(warnMsg, 'Maximum number of trials reached')
            warning('RANSAC warning detected: trials limit reached');
            success = 0;
        end
    catch ME
        warning('Homography estimation failed');
        success = 0;
        return;
    end

    % Extract homography matrix
    H = tform.T;

    % Extract inlier points as Nx2 arrays
    inlierPts1 = matchedPts1(inlierIdx).Location;
    inlierPts2 = matchedPts2(inlierIdx).Location;

    % Calculate inlierRatio
    inlierRatio = length(inlierPts1)/length(matchedPts1);
    
    % ============== test for success ================
    H_norm = H / H(3,3);
    % Shape distortion test via unit square transform ---------------
    square = [0 0; 1 0; 1 1; 0 1];
    transformedSquare = transformPointsForward(projective2d(H_norm'), square);
    width1 = norm(transformedSquare(2,:) - transformedSquare(1,:));
    width2 = norm(transformedSquare(3,:) - transformedSquare(4,:));
    height1 = norm(transformedSquare(4,:) - transformedSquare(1,:));
    height2 = norm(transformedSquare(3,:) - transformedSquare(2,:));
    avgWidth = (width1 + width2) / 2;
    avgHeight = (height1 + height2) / 2;
    aspectRatio = max(avgWidth, avgHeight) / min(avgWidth, avgHeight);
    if aspectRatio > 1.3  % Reject if distorted too much
        success = 0;
        fprintf("unit square test failed with aspectRatio %.02f\n",aspectRatio)
        return;
    end
    % Test for projective distortion (Z-axis tilt) ---------------
    perspectiveDistortion = norm(H_norm(1:2,3));  % Check 3rd column, first two rows
    if perspectiveDistortion > 0.0002
        success = 0; 
        fprintf("Projective distortion too high: %.6f\n", perspectiveDistortion);
        return;
    end
    % Reject degenerate homographies --------------------- 
    if rank(H) < 3
        success = 0;
        fprintf("Homography matrix is degenerate (rank %d)\n", rank(H));
        return;
    end
    % test for ill conditioned H --------------------------------
    if cond(H) > 2e6
        success = 0;
        fprintf("Homography matrix is ill-conditioned (condition number %.2e)\n", cond(H));
        return;
    end
    % test for inlierratio and stuff ---------------------------
    if inlierRatio <= 0.1 && length(inlierPts1) <= 6
        success = 0;  % Reject
        fprintf("Poor inlier ratio (%.2f) with too few inliers (%d)\n", inlierRatio, length(inlierPts1));
        return;
    end

    fprintf("successful calculation with inlier ratio (%.2f) and #inliers (%d)\n", inlierRatio, length(inlierPts1));
end
