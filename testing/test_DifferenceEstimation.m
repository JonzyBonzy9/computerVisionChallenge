function test_DifferenceEstimation(method, threshold, blockSize, areaMin, areaMax)
    % Add source code to path
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(scriptDir, '..', 'src'));

    % Default args (can override when calling)
    if nargin < 1, method = 'absdiff'; end
    if nargin < 2, threshold = NaN; end
    if nargin < 3, blockSize = 1; end
    if nargin < 4, areaMin = 30; end
    if nargin < 5, areaMax = Inf; end

    % Load images
    folderPath = fullfile(scriptDir, '..', 'data', 'Datasets', 'Frauenkirche');
    fileList = dir(fullfile(folderPath, '*.jpg'));
    if isempty(fileList)
        error('No image files found in: %s', folderPath);
    end

    % Read images into struct array
    imageArray = cell(1, length(fileList));
    for i = 1:length(fileList)
        imageArray{i}.data = imread(fullfile(fileList(i).folder, fileList(i).name));
        imageArray{i}.id = fileList(i).name;
    end

    % Estimate homographies (your own logic)
    output = estimateHomographiesSet(imageArray);

    % Loop through all image pairs
    for i = 1:length(output)
        img1 = output{i}.image1;
        img2 = output{i}.image2;
        H = output{i}.H;
        score = output{i}.inlierRatio;
        numPoints = length(output{i}.inlierPts1);

        % Warp image 2 to image 1's space
        tform = projective2d(H);
        warpedImg2 = imwarp(img2, tform, 'OutputView', imref2d(size(img1)));

        % Run difference estimation
        fprintf('Processing image pair %d with method "%s"...\n', i, method);
        changeMask = differenceEstimationFunctions.process(img1, warpedImg2, ...
            method, threshold, blockSize, areaMin, areaMax);

        % Show results
        figure('Name', sprintf('%s <-> %s', output{i}.id1, output{i}.id2), 'NumberTitle', 'off');
        tiledlayout(2, 2);

        nexttile; imshow(img1); title('Image 1');
        nexttile; imshow(warpedImg2); title('Warped Image 2');
        nexttile; imshowpair(img1, warpedImg2, 'blend'); title('Overlay');
        nexttile; imshow(changeMask); title(sprintf('Change Mask (%s)', method));

        sgtitle(sprintf('InlierRatio: %.2f | #Inliers: %d', score, numPoints));

        disp('Press any key to continue to the next image pair...');
        pause;
        close;
    end
end
