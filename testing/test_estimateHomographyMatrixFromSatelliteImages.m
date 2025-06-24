% import function
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));

% load example images
img1 = imread(fullfile(scriptDir, '..', 'data','Datasets','Columbia Glacier','12_2000.jpg'));
img2 = imread(fullfile(scriptDir, '..', 'data','Datasets','Columbia Glacier','12_2020.jpg'));

% estimate homography & get inlier matches
[H, inlierPts1, inlierPts2] = estimateHomographyMatrixFromSatelliteImages(img1, img2);

% warp img2 into img1 coordinate system
outputView = imref2d(size(img1));
tform = projective2d(H);
img2_warped = imwarp(img2, tform, 'OutputView', outputView);


%%%% overlay plot
% convert to double for blending 
img1_double = im2double(img1);
img2_double = im2double(img2_warped);
% Make sure both images are 3-channel for blending
if size(img1_double,3) == 1
    img1_double = repmat(img1_double, [1 1 3]);
end
if size(img2_double,3) == 1
    img2_double = repmat(img2_double, [1 1 3]);
end
% alpha blend overlay
alpha = 0.5;
overlay = img1_double * alpha + img2_double * (1 - alpha);
% show overlay
figure; imshow(overlay); hold on;
title('Overlay of Image 1 and Warped Image 2 with Alpha = 0.5');
% Plot inlier points from img1
plot(inlierPts1(:,1), inlierPts1(:,2), 'go', 'MarkerSize', 8, 'LineWidth', 2);
% Warp inlier points from img2 using homography H
numPts = size(inlierPts2,1);
pts2_hom = [inlierPts2, ones(numPts,1)]';  % 3 x N homogeneous coords
warpedPts2_hom = H' * pts2_hom;
warpedPts2 = bsxfun(@rdivide, warpedPts2_hom(1:2,:), warpedPts2_hom(3,:))';
% Plot warped points from img2
plot(warpedPts2(:,1), warpedPts2(:,2), 'bx', 'MarkerSize', 8, 'LineWidth', 2);
% Connect matching points with yellow lines
for i = 1:numPts
    plot([inlierPts1(i,1), warpedPts2(i,1)], [inlierPts1(i,2), warpedPts2(i,2)], 'y-');
end


%%%% plot matched correspondence points as montage
% show matched inlier points (only if enough points)
if size(inlierPts1,1) > 1
    figure;
    % showMatchedFeatures(img1, img2, inlierPts1, inlierPts2, 'blend');
    showMatchedFeatures(img1, img2, inlierPts1, inlierPts2, 'montage');
    title('Inlier Matched Points After RANSAC');
else
    disp('Not enough inlier points to display matches.');
end
