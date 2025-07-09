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
        valid_methods = {'absdiff','gradient','ssim','dog','pca'};
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

            [~, loc] = ismember(obj.overlay.lastIndices, indices);
            % Filter: ignore zeros (means not found)
            validLoc = loc(loc > 0);
            filteredImages = obj.overlay.warpedImages(validLoc);
            filteredMasks = obj.overlay.warpedMasks(validLoc);

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
                    otherwise
                        error('Unknown method "%s". Supported methods: absdiff, gradient, ssim, dog, pca.', method);
                end
                mask = imresize(mask, size(filteredMasks{i}), 'nearest');

                mask = mask & filteredMasks{i} & filteredMasks{i+1};

                obj.differenceMasks{i} = mask;
            
                % Postprocess mask with area filtering
                mask = differenceEstimationFunctions.postprocessMask(mask, areaMin, areaMax);
                                
            end
            differenceMasks = obj.differenceMasks;
        end

        function mask = getMask(obj, id)
            mask = obj.differenceMasks{id};
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
        
    end
end
