classdef differenceEstimationFunctions
    properties (Constant)
        % define value ranges etc
        valid_methods = {'absdiff','gradient','ssim','dog','pca'};
        value_range_threshold = [0, 1];
        value_range_blockSize = [1, Inf];
        value_range_areaMin = [1, Inf];
        value_range_areaMax = [1, Inf];
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
