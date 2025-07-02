function test_estimateAbsoluteImageDifferencePairFunction()
    % Add src to path
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(scriptDir, '..', 'src'));

    % Load example images
    img1 = imread(fullfile(scriptDir, '..', 'data', 'Datasets', 'Columbia Glacier', '12_2000.jpg'));
    img2 = imread(fullfile(scriptDir, '..', 'data', 'Datasets', 'Columbia Glacier', '12_2020.jpg'));

    % Estimate homography & warp image 2 into image 1’s coordinate system
    [H, ~, ~, inlierRatio] = estimateHomographyPair(img1, img2);
    disp(['Inlier Ratio: ', num2str(inlierRatio)]);

    % Warp image2 using the homography
    outputView = imref2d(size(img1));
    tform = projective2d(H);
    img2_warped = imwarp(img2, tform, 'OutputView', outputView);

    % Convert images to double for blending
    img1_double = im2double(img1);
    img2_double = im2double(img2_warped);

    if size(img1_double, 3) == 1
        img1_double = repmat(img1_double, [1 1 3]);
    end
    if size(img2_double, 3) == 1
        img2_double = repmat(img2_double, [1 1 3]);
    end

    % Create UI
    f = uifigure('Name', 'Interactive Image Difference Tuning', 'Position', [100 100 1000 600]);
    ax = uiaxes(f, 'Position', [25 100 700 475]);
    ax.XTick = [];
    ax.YTick = [];

    % Sliders
    uilabel(f, 'Position', [760 520 100 22], 'Text', 'Block Size');
    blockSlider = uislider(f, ...
        'Position', [760 500 200 3], ...
        'Limits', [1 15], ...
        'MajorTicks', 1:2:15, ...
        'Value', 5);

    uilabel(f, 'Position', [760 450 100 22], 'Text', 'Diff Threshold');
    diffSlider = uislider(f, ...
        'Position', [760 430 200 3], ...
        'Limits', [0 1], ...
        'Value', 0.5);

    uilabel(f, 'Position', [760 380 100 22], 'Text', 'Area Support');
    supportSlider = uislider(f, ...
        'Position', [760 360 200 3], ...
        'Limits', [0 10], ...
        'Value', 2);

    % New slider: Min Neighbors
    uilabel(f, 'Position', [760 320 100 22], 'Text', 'Min Neighbors');
    minNeighborsSlider = uislider(f, ...
        'Position', [760 300 200 3], ...
        'Limits', [1 20], ...
        'MajorTicks', 1:2:20, ...
        'Value', 2);

    % Update Button
    updateBtn = uibutton(f, 'push', ...
        'Text', 'Update', ...
        'Position', [800 250 100 30], ...
        'ButtonPushedFcn', @(btn,event) updateOverlay());

    % Initial blank plot / instruction text
    title(ax, 'Adjust sliders and click Update to see results');

    % === Nested update function ===
    function updateOverlay()
        % Get parameter values
        bSize = round(blockSlider.Value);
        dThresh = diffSlider.Value;
        aSupport = round(supportSlider.Value);
        minNeighbors = round(minNeighborsSlider.Value);

        % Compute mask (assumes your function supports minNeighbors param)
        mask = estimateAbsoluteImageDifferencePair(img1, img2_warped, ...
            'blockSize', bSize, ...
            'diffThreshold', dThresh, ...
            'areaSupport', aSupport, ...
            'minNeighbors', minNeighbors);

        % Overlay mask (continuous with bilinear resize in your function)
        alpha = 0.5;
        overlay = img1_double * alpha + img2_double * (1 - alpha);

        % Show blended image
        imshow(overlay, 'Parent', ax);
        hold(ax, 'on');

        % Green mask with transparency
        mask_rgb = cat(3, zeros(size(mask)), ones(size(mask)), zeros(size(mask)));
        h = imshow(mask_rgb, 'Parent', ax);
        set(h, 'AlphaData', 0.3 * mask);
        hold(ax, 'off');

        % Update title
        title(ax, sprintf('BlockSize = %d | Diff = %.2f | Area = %d | Min Neighbors = %d', ...
            bSize, dThresh, aSupport, minNeighbors));
    end
end

test_estimateAbsoluteImageDifferencePairFunction