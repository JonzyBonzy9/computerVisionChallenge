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

        % further public properties
        % e.g. parameters for algorithm
    end
    properties (Access = private)
        % private properties
    end

    properties (Constant)
        % define value ranges etc
        valid_methods = {'absdiff','gradient','ssim','dog','pca','temporal_analysis','texture_change','edge_evolution'};
        valid_change_types = {'fast', 'slow', 'periodic', 'large_scale', 'medium_scale', 'small_scale', 'urban', 'natural', 'mixed'};
        valid_visualization_types = {'heatmap', 'overlay', 'difference_evolution', 'change_magnitude', 'temporal_profile', 'change_timeline'};
        value_range_threshold = [0, 1];
        value_range_blockSize = [1, 30];
        value_range_areaMin = [1, 150];
        value_range_areaMax = [1, 150];
    end

    methods
        function obj = differenceEstimationFunctions(overlayClass)
            obj.overlay = overlayClass;
            obj.resultAvailable = false;
        end

        function differenceMasks = calculate(obj, indices, method, threshold, blockSize, areaMin, areaMax)
            obj.lastIndices = indices;
            obj.method = method;
            obj.threshold = threshold;
            blockSize = ceil(blockSize);
            obj.blockSize = blockSize;
            obj.areaMin = areaMin;
            obj.areaMax = areaMax;


            isInSelection = ismember(obj.overlay.lastIndices, indices);
            filteredImages = obj.overlay.warpedImages(isInSelection);
            filteredMasks = obj.overlay.warpedMasks(isInSelection);

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
            obj.resultAvailable = true;
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


        %% ===== 1. Absolute Difference =====
        % Added optional skipPostprocessing to support process pipeline
        function mask = detectChange_absdiff(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            diffImage = imabsdiff(I1, I2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffImage);
            end
            mask = imbinarize(diffImage, threshold);
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end

        %% ===== 2. Gradient Difference =====
        function mask = detectChange_gradient(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            [Gx1, Gy1] = imgradientxy(I1);
            [Gx2, Gy2] = imgradientxy(I2);
            gradDiff = abs(Gx1 - Gx2) + abs(Gy1 - Gy2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(gradDiff);
            end
            mask = imbinarize(gradDiff, threshold);
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end

        %% ===== 3. SSIM Difference =====
        function mask = detectChange_ssim(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            [~, ssimMap] = ssim(I1, I2);
            diffMap = 1 - ssimMap;
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffMap);
            end
            mask = imbinarize(diffMap, threshold);
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end

        %% ===== 4. Difference of Gaussians =====
        function mask = detectChange_DoG(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            I1_DoG = imgaussfilt(I1, 1) - imgaussfilt(I1, 2);
            I2_DoG = imgaussfilt(I2, 1) - imgaussfilt(I2, 2);
            dogDiff = imabsdiff(I1_DoG, I2_DoG);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(dogDiff);
            end
            mask = imbinarize(dogDiff, threshold);
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end

        %% ===== 5. PCA-Based Change Detection =====
        function mask = detectChange_pca(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            [rows, cols] = size(I1);
            X = [I1(:), I2(:)];
            [~, score, ~] = pca(X);
            pc1 = reshape(score(:,1), rows, cols);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(pc1);
            end
            mask = imbinarize(pc1, threshold);
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end
        
        %% ===== 6. Temporal Analysis (for multi-image sequences) =====
        function mask = detectChange_temporal(imageSequence, currentIdx, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            
            % Analyze change velocity over time
            if currentIdx > 1 && currentIdx < length(imageSequence)
                I_prev = imageSequence{currentIdx-1};
                I_curr = imageSequence{currentIdx};
                I_next = imageSequence{currentIdx+1};
                
                % Convert to grayscale if needed
                if size(I_prev, 3) == 3, I_prev = rgb2gray(I_prev); end
                if size(I_curr, 3) == 3, I_curr = rgb2gray(I_curr); end
                if size(I_next, 3) == 3, I_next = rgb2gray(I_next); end
                
                I_prev = im2double(I_prev);
                I_curr = im2double(I_curr);
                I_next = im2double(I_next);
                
                % Calculate temporal gradient
                change_rate = abs(I_next - I_curr) - abs(I_curr - I_prev);
                
                if nargin < 3 || isnan(threshold)
                    threshold = graythresh(abs(change_rate));
                end
                mask = imbinarize(abs(change_rate), threshold);
            else
                % Fallback to simple difference for edge cases
                mask = differenceEstimationFunctions.detectChange_absdiff(imageSequence{currentIdx}, imageSequence{currentIdx+1}, threshold, true);
            end
            
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end
        
        %% ===== 7. Texture Change Detection =====
        function mask = detectChange_texture(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            
            % Calculate Local Binary Pattern (LBP) for texture analysis
            lbp1 = differenceEstimationFunctions.calculateLBP(I1);
            lbp2 = differenceEstimationFunctions.calculateLBP(I2);
            
            textureDiff = abs(lbp1 - lbp2);
            
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(textureDiff);
            end
            mask = imbinarize(textureDiff, threshold);
            
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end
        
        %% ===== 8. Edge Evolution Detection =====
        function mask = detectChange_edge(I1, I2, threshold, skipPostprocessing)
            if nargin < 4, skipPostprocessing = false; end
            
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
            
            if ~skipPostprocessing
                mask = differenceEstimationFunctions.postprocessMask(mask);
            end
        end
        
        %% ===== Helper function for LBP calculation =====
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
end
