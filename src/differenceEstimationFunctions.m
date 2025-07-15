classdef differenceEstimationFunctions < handle

    properties (Access = public)
        % overlayed images for calculation
        overlay
        % input data for calculation
        method
        threshold
        blockSize
        areaMin
        areaMax
        imageArray  %% array with id (date) and data field

        % calculation inputs and results
        lastIndices
        differenceMasks
        resultAvailable

        % 4D mask stack for efficient blending (H x W x C x N)
        % Stores masks in RGB format for direct blending
        maskStack

        % further public properties
        % e.g. parameters for algorithm
    end
    properties (Access = private)
        % private properties
    end

    properties (Constant)
        % define value ranges etc
        valid_methods = {'absdiff','gradient','ssim','dog','pca','texture_change','edge_evolution'};
        valid_change_types = {'urban', 'natural', 'mixed'};
        valid_visualization_types = {'heatmap', 'temporal overlay', 'max', 'sum', 'average'};
        value_range_threshold = [0, 1];
        value_range_blockSize = [0, 100];
        value_range_areaMin = [0, 6];
        value_range_areaMax = [1, 9];
    end

    methods
        function obj = differenceEstimationFunctions(overlayClass)
            obj.overlay = overlayClass;
            obj.resultAvailable = false;
        end

        function reset(obj)
            % Reset all properties to initial state
            obj.lastIndices = [];
            obj.method = '';
            obj.threshold = NaN;
            obj.blockSize = 1;
            obj.areaMin = 1;
            obj.areaMax = Inf;
            obj.differenceMasks = {};
            obj.resultAvailable = false;
            obj.maskStack = [];
        end

        function differenceMasks = calculate(obj, indices, method, threshold, blockSize, areaMin, areaMax)
            obj.lastIndices = indices;
            obj.method = method;
            obj.threshold = threshold;
            blockSize = ceil(blockSize);
            obj.blockSize = blockSize;
            obj.areaMin = areaMin;
            obj.areaMax = areaMax;

            % Get filtered images and masks - FIXED: directly map selected indices
            % Find positions of selected indices in overlay.lastIndices
            [~, selectedPositions] = ismember(indices, obj.overlay.lastIndices);

            % Remove any zero positions (indices not found in overlay)
            validPositions = selectedPositions(selectedPositions > 0);
            if length(validPositions) ~= length(indices)
                warning('Some selected indices were not found in overlay data');
            end

            % Extract only the specifically selected images and masks
            filteredImages = obj.overlay.warpedImages(validPositions);
            filteredMasks = obj.overlay.warpedMasks(validPositions);

            obj.differenceMasks = cell(1, length(filteredImages)-1);

            % Preprocess images first
            for i=1:length(filteredImages)-1
                I1 = filteredImages{i};
                I2 = filteredImages{i+1};


                [I1, I2] = differenceEstimationFunctions.preprocessImages(I1, I2, blockSize);
                % Dispatch to the specified method
                switch lower(method)
                    case 'absdiff'
                        mask = differenceEstimationFunctions.detectChange_absdiff(I1, I2, threshold, true);
                    case 'gradient'
                        mask = differenceEstimationFunctions.detectChange_gradient(I1, I2, threshold, true);
                    case 'ssim'
                        mask = differenceEstimationFunctions.detectChange_ssim(I1, I2, threshold, true);
                    case 'dog'
                        mask = differenceEstimationFunctions.detectChange_DoG(I1, I2, threshold, true);
                    case 'pca'
                        mask = differenceEstimationFunctions.detectChange_pca(I1, I2, threshold, true);
                    case 'temporal_analysis'
                        mask = differenceEstimationFunctions.detectChange_temporal(filteredImages, i, threshold, true);
                    case 'texture_change'
                        mask = differenceEstimationFunctions.detectChange_texture(I1, I2, threshold, true);
                    case 'edge_evolution'
                        mask = differenceEstimationFunctions.detectChange_edge(I1, I2, threshold, true);
                    otherwise
                        error('Unknown method "%s". Supported methods: %s.', method, strjoin(obj.valid_methods, ', '));
                end
                mask = imresize(mask, size(filteredMasks{i}), 'nearest');

                mask = mask & filteredMasks{i} & filteredMasks{i+1};

                obj.differenceMasks{i} = mask;

                % Postprocess mask with area filtering
                % mask = differenceEstimationFunctions.postprocessMask(mask, areaMin, areaMax);

            end
            differenceMasks = obj.differenceMasks;
            obj.createImageStack();
            obj.resultAvailable = true;
        end

        function createImageStack(obj)
            % Create 4D image stack from warpedImages for efficient blending
            if isempty(obj.differenceMasks)
                obj.maskStack = [];
                return;
            end

            % Get dimensions from first image
            [H, W, C] = size(obj.differenceMasks{1});
            N = length(obj.differenceMasks);

            % Pre-allocate 4D array
            obj.maskStack = zeros(H, W, C, N, 'like', obj.differenceMasks{1});

            % Copy images into stack
            for i = 1:N
                obj.maskStack(:,:,:,i) = obj.differenceMasks{i};
            end
        end

        function mask = getMask(obj, id)
            mask = obj.differenceMasks{id};
        end

        %% ===== Change Categorization Methods =====
        function changeType = categorizeChanges(obj, changeData, indices)
            % Analyze change characteristics to categorize them
            changeType = struct();

            % Temporal analysis
            timeSpan = max(indices) - min(indices);
            avgChange = mean(cellfun(@(x) sum(x(:)), obj.differenceMasks));

            if timeSpan <= 2
                changeType.temporal = 'fast';
            elseif timeSpan <= 5
                changeType.temporal = 'medium';
            else
                changeType.temporal = 'slow';
            end

            % Spatial scale analysis
            totalChangeArea = sum(cellfun(@(x) sum(x(:)), obj.differenceMasks));
            if totalChangeArea > 0.3 * numel(obj.differenceMasks{1})
                changeType.spatial = 'large_scale';
            elseif totalChangeArea > 0.1 * numel(obj.differenceMasks{1})
                changeType.spatial = 'medium_scale';
            else
                changeType.spatial = 'small_scale';
            end

            % Environmental type (simplified heuristic)
            edgeIntensity = obj.analyzeEdgeContent();
            if edgeIntensity > 0.3
                changeType.environmental = 'urban';
            else
                changeType.environmental = 'natural';
            end
        end

        function edgeIntensity = analyzeEdgeContent(obj)
            % Analyze edge content to distinguish urban vs natural changes
            edgeIntensity = 0;
            if ~isempty(obj.differenceMasks)
                for i = 1:length(obj.differenceMasks)
                    mask = obj.differenceMasks{i};
                    edges = edge(double(mask), 'Canny');
                    edgeIntensity = edgeIntensity + sum(edges(:)) / numel(edges);
                end
                edgeIntensity = edgeIntensity / length(obj.differenceMasks);
            end
        end

        %% ===== Visualization Methods =====
        function visualizationData = generateVisualization(obj, visualizationType, indices)
            % Generate different types of visualizations
            switch lower(visualizationType)
                case 'heatmap'
                    visualizationData = obj.createChangeHeatmap();
                case 'overlay'
                    visualizationData = obj.createOverlayVisualization(indices);
                case 'difference_evolution'
                    visualizationData = obj.createEvolutionVisualization();
                case 'change_magnitude'
                    visualizationData = obj.createMagnitudeVisualization();
                case 'temporal_profile'
                    visualizationData = obj.createTemporalProfile();
                case 'change_timeline'
                    visualizationData = obj.createTimelineVisualization(indices);
                otherwise
                    error('Unknown visualization type: %s', visualizationType);
            end
        end

        function heatmapData = createChangeHeatmap(obj)
            % Create intensity heatmap of changes
            if isempty(obj.differenceMasks)
                heatmapData = [];
                return;
            end

            % Accumulate all changes
            heatmapData = zeros(size(obj.differenceMasks{1}));
            for i = 1:length(obj.differenceMasks)
                heatmapData = heatmapData + double(obj.differenceMasks{i});
            end

            % Normalize to [0,1] range
            if max(heatmapData(:)) > 0
                heatmapData = heatmapData / max(heatmapData(:));
            end
        end

        function overlayData = createOverlayVisualization(obj, indices)
            % Create color-coded overlay of changes over time
            if isempty(obj.differenceMasks)
                overlayData = [];
                return;
            end

            [h, w] = size(obj.differenceMasks{1});
            overlayData = zeros(h, w, 3); % RGB overlay

            colors = hot(length(obj.differenceMasks)); % Color map for time

            for i = 1:length(obj.differenceMasks)
                mask = obj.differenceMasks{i};
                for c = 1:3
                    overlayData(:,:,c) = overlayData(:,:,c) + mask * colors(i,c);
                end
            end

            % Normalize
            overlayData = overlayData / max(overlayData(:));
        end

        function evolutionData = createEvolutionVisualization(obj)
            % Create visualization showing how changes evolve over time
            evolutionData = struct();
            evolutionData.changeMagnitude = zeros(1, length(obj.differenceMasks));
            evolutionData.changeArea = zeros(1, length(obj.differenceMasks));

            for i = 1:length(obj.differenceMasks)
                mask = obj.differenceMasks{i};
                evolutionData.changeMagnitude(i) = sum(mask(:));
                evolutionData.changeArea(i) = sum(mask(:)) / numel(mask);
            end
        end

        function magnitudeData = createMagnitudeVisualization(obj)
            % Create visualization emphasizing change magnitude
            if isempty(obj.differenceMasks)
                magnitudeData = [];
                return;
            end

            magnitudeData = zeros(size(obj.differenceMasks{1}));

            for i = 1:length(obj.differenceMasks)
                % Weight by position in sequence (later changes weighted more)
                weight = i / length(obj.differenceMasks);
                magnitudeData = magnitudeData + weight * double(obj.differenceMasks{i});
            end
        end

        function profileData = createTemporalProfile(obj)
            % Create temporal profile of changes
            profileData = struct();
            if isempty(obj.differenceMasks)
                return;
            end

            profileData.timePoints = 1:length(obj.differenceMasks);
            profileData.totalChange = zeros(1, length(obj.differenceMasks));
            profileData.maxChange = zeros(1, length(obj.differenceMasks));
            profileData.changeDistribution = cell(1, length(obj.differenceMasks));

            for i = 1:length(obj.differenceMasks)
                mask = obj.differenceMasks{i};
                profileData.totalChange(i) = sum(mask(:));
                profileData.maxChange(i) = max(mask(:));
                profileData.changeDistribution{i} = mask;
            end
        end

        function timelineData = createTimelineVisualization(obj, indices)
            % Create timeline visualization with actual time indices
            timelineData = struct();
            timelineData.indices = indices(1:end-1); % Remove last index
            timelineData.changeIntensity = zeros(1, length(obj.differenceMasks));
            timelineData.changeMasks = obj.differenceMasks;

            for i = 1:length(obj.differenceMasks)
                timelineData.changeIntensity(i) = sum(obj.differenceMasks{i}(:));
            end
        end
    end

    methods (Static)
        %% ===== process function =====
        function changeMask = process(I1, I2, method, threshold, blockSize, areaMin, areaMax)

            arguments
                I1
                I2
                method (1,:) char {mustBeMember(method, {'absdiff','gradient','ssim','dog','pca'})}
                threshold (1,1) double = NaN
                blockSize (1,1) double = 1
                areaMin (1,1) double = 1
                areaMax (1,1) double = Inf
            end

            % Preprocess images first
            [I1, I2] = differenceEstimationFunctions.preprocessImages(I1, I2, blockSize);

            % Dispatch to the specified method
            switch lower(method)
                case 'absdiff'
                    mask = differenceEstimationFunctions.detectChange_absdiff(I1, I2, threshold, true);
                case 'gradient'
                    mask = differenceEstimationFunctions.detectChange_gradient(I1, I2, threshold, true);
                case 'ssim'
                    mask = differenceEstimationFunctions.detectChange_ssim(I1, I2, threshold, true);
                case 'dog'
                    mask = differenceEstimationFunctions.detectChange_DoG(I1, I2, threshold, true);
                case 'pca'
                    mask = differenceEstimationFunctions.detectChange_pca(I1, I2, threshold, true);
                otherwise
                    error('Unknown method "%s". Supported methods: absdiff, gradient, ssim, dog, pca.', method);
            end

            % Postprocess mask with area filtering
            changeMask = differenceEstimationFunctions.postprocessMask(mask, areaMin, areaMax);
        end

        %% ===== pre/postprocessing =====
        function [I1, I2] = preprocessImages(I1, I2, blockSize)
            if size(I1, 3) == 3
                I1 = rgb2gray(I1);
            end
            if size(I2, 3) == 3
                I2 = rgb2gray(I2);
            end

            if ~isequal(size(I1), size(I2))
                warning('Input images have different sizes. Resizing I2 to match I1.');
                I2 = imresize(I2, size(I1));
            end

            I1 = im2double(I1);
            I2 = im2double(I2);

            if blockSize > 1
                bs = blockSize;
                I1 = blockproc(I1, [bs bs], @(block_struct) mean(block_struct.data(:)));
                I2 = blockproc(I2, [bs bs], @(block_struct) mean(block_struct.data(:)));
            end
        end

        function maskOut = postprocessMask(maskIn, areaMin, areaMax)
            if nargin < 2, areaMin = 30; end
            if nargin < 3, areaMax = Inf; end

            % Filter connected components by area range
            maskOut = bwpropfilt(maskIn, 'Area', [areaMin, areaMax]);

            % Smooth mask boundaries
            maskOut = imclose(maskOut, strel('disk', 3));
        end


        % ===== Absolute Difference =====
        function mask = detectChange_absdiff(I1, I2, threshold)
            diffImage = imabsdiff(I1, I2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffImage);
            end
            mask = imbinarize(diffImage, threshold);
        end

        % ===== Gradient Difference =====
        function mask = detectChange_gradient(I1, I2, threshold)
            [Gx1, Gy1] = imgradientxy(I1);
            [Gx2, Gy2] = imgradientxy(I2);
            gradDiff = abs(Gx1 - Gx2) + abs(Gy1 - Gy2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(gradDiff);
            end
            mask = imbinarize(gradDiff, threshold);
        end

        % ===== SSIM Difference =====
        function mask = detectChange_ssim(I1, I2, threshold)
            [~, ssimMap] = ssim(I1, I2);
            diffMap = 1 - ssimMap;
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffMap);
            end
            mask = imbinarize(diffMap, threshold);
        end

        % ===== Difference of Gaussians =====
        function mask = detectChange_DoG(I1, I2, threshold)
            I1_DoG = imgaussfilt(I1, 1) - imgaussfilt(I1, 2);
            I2_DoG = imgaussfilt(I2, 1) - imgaussfilt(I2, 2);
            dogDiff = imabsdiff(I1_DoG, I2_DoG);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(dogDiff);
            end
            mask = imbinarize(dogDiff, threshold);
        end

        % ===== PCA-Based Change Detection =====
        function mask = detectChange_pca(I1, I2, threshold)
            [rows, cols] = size(I1);
            X = [I1(:), I2(:)];
            [~, score, ~] = pca(X);
            pc1 = reshape(score(:,1), rows, cols);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(pc1);
            end
            mask = imbinarize(pc1, threshold);
        end

        % ===== Texture Change Detection =====
        function mask = detectChange_texture(I1, I2, threshold)
            % Calculate Local Binary Pattern (LBP) for texture analysis
            lbp1 = differenceEstimationFunctions.calculateLBP(I1);
            lbp2 = differenceEstimationFunctions.calculateLBP(I2);

            textureDiff = abs(lbp1 - lbp2);

            if nargin < 3 || isnan(threshold)
                threshold = graythresh(textureDiff);
            end
            mask = imbinarize(textureDiff, threshold);
        end

        % ===== Edge Evolution Detection =====
        function mask = detectChange_edge(I1, I2, threshold)
            % Detect edges and analyze their evolution
            edges1 = edge(I1, 'Canny');
            edges2 = edge(I2, 'Canny');

            % Calculate edge change: new edges + disappeared edges
            edgeChange = (edges2 & ~edges1) | (edges1 & ~edges2);

            % Apply morphological operations to connect nearby edge changes
            se = strel('disk', 2);
            edgeChange = imclose(edgeChange, se);

            if nargin < 3 || isnan(threshold)
                % For edge detection, threshold represents minimum change area
                if isnan(threshold), threshold = 0.01; end
            end

            % Convert to double for thresholding
            edgeChangeDouble = im2double(edgeChange);
            mask = edgeChangeDouble > threshold;
        end

        % ===== Helper function for LBP calculation =====
        function lbp = calculateLBP(img)
            % Simple Local Binary Pattern implementation
            if size(img, 3) == 3
                img = rgb2gray(img);
            end
            img = im2double(img);

            [rows, cols] = size(img);
            lbp = zeros(rows-2, cols-2);

            for i = 2:rows-1
                for j = 2:cols-1
                    center = img(i, j);
                    code = 0;

                    % 8-neighbor LBP
                    neighbors = [img(i-1,j-1), img(i-1,j), img(i-1,j+1), ...
                        img(i,j+1), img(i+1,j+1), img(i+1,j), ...
                        img(i+1,j-1), img(i,j-1)];

                    for k = 1:8
                        if neighbors(k) >= center
                            code = code + 2^(k-1);
                        end
                    end

                    lbp(i-1, j-1) = code;
                end
            end

            % Normalize to [0,1] range
            lbp = lbp / 255;
        end
    end

    %% ===== Extended Methods for Three-Dimensional Preset Calculation =====
    methods (Access = public)
        function differenceMasks = calculateAdvanced(obj, indices, tempo, algorithm, threshold, blockSize, areaMin, areaMax)
            % Calculate difference masks using three-dimensional preset system
            % Arguments:
            %   indices - image indices to process
            %   tempo - temporal dimension: 'fast', 'medium', 'slow'
            %   algorithm - change detection algorithm type: 'urban', 'natural', 'mixed', or specific method
            %   threshold - threshold for change detection
            %   blockSize - spatial scale dimension (block size for preprocessing)
            %   areaMin - minimum area for change detection
            %   areaMax - maximum area for change detection

            obj.lastIndices = indices;

            % Get filtered images and masks - FIXED: directly map selected indices
            % Find positions of selected indices in overlay.lastIndices
            [~, selectedPositions] = ismember(indices, obj.overlay.lastIndices);

            % Remove any zero positions (indices not found in overlay)
            validPositions = selectedPositions(selectedPositions > 0);

            % Extract only the specifically selected images and masks
            filteredImages = obj.overlay.warpedImages(validPositions);
            filteredMasks = obj.overlay.warpedMasks(validPositions);

            % === STEP 1: Apply Spatial Scale Dimension ===
            obj.blockSize = blockSize;
            obj.areaMin = areaMin;
            obj.areaMax = areaMax;
            obj.threshold = threshold;

            % === STEP 2: Determine Detection Method(s) based on Type ===
            [detectionMethods, methodWeights] = obj.determineTypeParameters(algorithm);

            % === STEP 3: Calculate initial masks for all image pairs ===
            rawMasks = cell(1, length(filteredImages)-1);
            combinedMasks = cell(1, length(filteredImages)-1);

            for i = 1:length(filteredImages)-1
                I1 = filteredImages{i};
                I2 = filteredImages{i+1};

                % Preprocess images with determined block size
                [I1_proc, I2_proc] = differenceEstimationFunctions.preprocessImages(I1, I2, obj.blockSize);

                % Apply multiple detection methods if specified
                pairMasks = cell(1, length(detectionMethods));
                for methodIdx = 1:length(detectionMethods)
                    currentMethod = detectionMethods{methodIdx};
                    weight = methodWeights(methodIdx);

                    % Calculate mask for this method
                    switch lower(currentMethod)
                        case 'absdiff'
                            mask = differenceEstimationFunctions.detectChange_absdiff(I1_proc, I2_proc, obj.threshold);
                        case 'gradient'
                            mask = differenceEstimationFunctions.detectChange_gradient(I1_proc, I2_proc, obj.threshold);
                        case 'ssim'
                            mask = differenceEstimationFunctions.detectChange_ssim(I1_proc, I2_proc, obj.threshold);
                        case 'dog'
                            mask = differenceEstimationFunctions.detectChange_DoG(I1_proc, I2_proc, obj.threshold);
                        case 'pca'
                            mask = differenceEstimationFunctions.detectChange_pca(I1_proc, I2_proc, obj.threshold);
                        case 'temporal_analysis'
                            mask = differenceEstimationFunctions.detectChange_temporal(filteredImages, i, obj.threshold);
                        case 'texture_change'
                            mask = differenceEstimationFunctions.detectChange_texture(I1_proc, I2_proc, obj.threshold);
                        case 'edge_evolution'
                            mask = differenceEstimationFunctions.detectChange_edge(I1_proc, I2_proc, obj.threshold);
                        otherwise
                            error('Unknown method "%s"', currentMethod);
                    end
                    % Resize mask to match original image size
                    mask = imresize(mask, size(filteredMasks{i}), 'nearest');
                    pairMasks{methodIdx} = double(mask) * weight;
                end

                % Combine multiple methods if used
                if length(pairMasks) == 1
                    combinedMask = pairMasks{1};
                else
                    % Weighted combination of methods
                    weightedSum = zeros(size(pairMasks{1}));
                    for methodIdx = 1:length(pairMasks)
                        weightedSum = weightedSum + pairMasks{methodIdx};
                    end
                    % reapply boolean threshold
                    combinedMask = weightedSum > (sum(methodWeights) * 0.5);
                end

                % Apply intersection with valid regions
                combinedMask = combinedMask & filteredMasks{i} & filteredMasks{i+1};

                rawMasks{i} = combinedMask;
            end

            % === STEP 4: Apply Area Filtering based on Scale ===
            for i = 1:length(rawMasks)
                combinedMasks{i} = differenceEstimationFunctions.postprocessMask(rawMasks{i}, obj.areaMin, obj.areaMax);
            end

            % === STEP 5: Apply Temporal Dimension Filtering ===
            obj.differenceMasks = obj.applyTemporalFiltering(combinedMasks, tempo, indices);

            differenceMasks = obj.differenceMasks;
            obj.createImageStack();
            obj.resultAvailable = true;
        end

        function [methods, methodWeights] = determineTypeParameters(obj, type)
            % Determine detection methods and parameters based on environment type

            switch lower(type)
                case 'comb. urban'
                    % Urban environments: emphasize geometric structures and edges
                    methods = {'gradient', 'edge_evolution'};
                    methodWeights = [0.7, 0.3]; % Primary: gradient, Secondary: edge evolution

                case 'comb. natural'
                    % Natural environments: emphasize texture and smooth changes
                    methods = {'ssim', 'gradient'};
                    methodWeights = [0.5, 0.5]; % Primary: texture, Secondary: basic difference

                case 'mixed'
                    % Mixed environments: balanced approach with multiple methods
                    methods = {'absdiff', 'gradient', 'ssim'};
                    methodWeights = [0.4, 0.3, 0.3]; % Balanced combination

                otherwise
                    if ismember(type, obj.valid_methods)
                        methods = {type};
                        methodWeights = [1.0]; % Single method with full weight
                    else
                        error('Unknown type dimension: %s. Must be urban, natural, or mixed.', type);
                    end
            end
        end

        function threshold = calculateAdaptiveThreshold(obj, I1, I2, baseThreshold, tempo)
            % Calculate adaptive threshold based on image characteristics and tempo

            % Calculate basic image statistics
            diffImage = imabsdiff(I1, I2);
            imageMean = mean(diffImage(:));
            imageStd = std(diffImage(:));
            autoThreshold = graythresh(diffImage);

            % Apply tempo-based sensitivity adjustment
            switch lower(tempo)
                case 'fast'
                    % High sensitivity for rapid changes
                    sensitivityFactor = 0.7; % More sensitive (lower threshold)

                case 'medium'
                    % Balanced sensitivity
                    sensitivityFactor = 1.0; % Use base threshold

                case 'slow'
                    % Lower sensitivity for gradual changes
                    sensitivityFactor = 1.4; % Less sensitive (higher threshold)

                otherwise
                    error('Unknown tempo dimension: %s. Must be fast, medium, or slow.', tempo);
            end

            % Combine adaptive and base thresholds
            adaptiveComponent = (autoThreshold * 0.3 + imageMean * 0.2 + imageStd * 0.5);
            threshold = (baseThreshold * 0.6 + adaptiveComponent * 0.4) * sensitivityFactor;

            % Ensure threshold is within reasonable bounds
            threshold = max(0.01, min(0.5, threshold));
        end

        function filteredMasks = applyTemporalFiltering(obj, masks, tempo, indices)
            % Apply temporal filtering based on tempo dimension

            if length(masks) < 2
                filteredMasks = masks;
                return;
            end

            switch lower(tempo)
                case 'fast'
                    % Emphasize immediate temporal differences and enhance rapid changes
                    filteredMasks = obj.enhanceFastChanges(masks);

                case 'slow'
                    % Smooth and accumulate gradual changes over time
                    filteredMasks = obj.enhanceSlowChanges(masks);

                case 'medium'
                    % Balanced temporal processing with slight smoothing
                    filteredMasks = obj.enhanceMediumChanges(masks);
                case 'none'
                    % No temporal filtering, return raw masks
                    filteredMasks = masks;

                otherwise
                    error('Unknown tempo dimension: %s. Must be fast, medium slow or none.', tempo);
            end
        end

        function enhancedMasks = enhanceFastChanges(obj, masks)
            % Enhance detection of rapid changes
            enhancedMasks = cell(size(masks));

            for i = 1:length(masks)
                currentMask = masks{i};

                if i > 1
                    % Emphasize differences from previous frame
                    prevMask = masks{i-1};
                    temporalDiff = abs(double(currentMask) - double(prevMask));

                    % Enhance regions with high temporal change
                    enhancementFactor = 1 + temporalDiff * 0.5;
                    enhancedMask = double(currentMask) .* enhancementFactor;
                    enhancedMasks{i} = enhancedMask > 0.6;
                else
                    enhancedMasks{i} = currentMask;
                end
            end
        end

        function enhancedMasks = enhanceSlowChanges(obj, masks)
            % Enhance detection of gradual changes by temporal accumulation
            enhancedMasks = cell(size(masks));

            % Create temporal accumulation window
            windowSize = min(3, length(masks));

            for i = 1:length(masks)
                % Define temporal window around current frame
                startIdx = max(1, i - floor(windowSize/2));
                endIdx = min(length(masks), i + floor(windowSize/2));

                % Accumulate changes in temporal window
                accumulated = zeros(size(masks{1}));
                for j = startIdx:endIdx
                    accumulated = accumulated + double(masks{j});
                end

                % Apply temporal smoothing
                accumulated = accumulated / (endIdx - startIdx + 1);
                enhancedMasks{i} = accumulated > 0.4;

                % Fill holes to capture gradual area changes
                enhancedMasks{i} = imfill(enhancedMasks{i}, 'holes');
            end
        end

        function enhancedMasks = enhanceMediumChanges(obj, masks)
            % Apply balanced temporal processing
            enhancedMasks = cell(size(masks));

            for i = 1:length(masks)
                currentMask = masks{i};

                % Apply light temporal smoothing
                if i > 1 && i < length(masks)
                    prevMask = masks{i-1};
                    nextMask = masks{i+1};

                    % Weighted temporal average
                    temporalAvg = (double(prevMask) * 0.25 + double(currentMask) * 0.5 + double(nextMask) * 0.25);
                    enhancedMasks{i} = temporalAvg > 0.5;
                else
                    enhancedMasks{i} = currentMask;
                end

                % Apply moderate morphological operations
                se = strel('disk', 2);
                enhancedMasks{i} = imopen(imclose(enhancedMasks{i}, se), se);
            end
        end
    end
end
