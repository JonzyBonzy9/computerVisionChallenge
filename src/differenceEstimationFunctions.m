classdef differenceEstimationFunctions
    methods(Static)

        %% 1. Absolute Difference
        function changeMask = detectChange_absdiff(I1, I2, threshold)
            diffImage = imabsdiff(I1, I2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffImage);
            end
            changeMask = imbinarize(diffImage, threshold);
        end

        %% 2. Gradient Difference
        function changeMask = detectChange_gradient(I1, I2, threshold)
            [Gx1, Gy1] = imgradientxy(I1);
            [Gx2, Gy2] = imgradientxy(I2);
            gradDiff = abs(Gx1 - Gx2) + abs(Gy1 - Gy2);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(gradDiff);
            end
            changeMask = imbinarize(gradDiff, threshold);
        end

        %% 3. SSIM Difference
        function changeMask = detectChange_ssim(I1, I2, threshold)
            [~, ssimMap] = ssim(I1, I2);
            diffMap = 1 - ssimMap;  % Higher values = more change
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(diffMap);
            end
            changeMask = imbinarize(diffMap, threshold);
        end

        %% 4. Difference of Gaussians (DoG)
        function changeMask = detectChange_DoG(I1, I2, threshold)
            I1_DoG = imgaussfilt(I1, 1) - imgaussfilt(I1, 2);
            I2_DoG = imgaussfilt(I2, 1) - imgaussfilt(I2, 2);
            dogDiff = imabsdiff(I1_DoG, I2_DoG);
            if nargin < 3 || isnan(threshold)
                threshold = graythresh(dogDiff);
            end
            changeMask = imbinarize(dogDiff, threshold);
        end

        %% 5. PCA-Based Change Detection
        function changeMask = detectChange_pca(I1, I2, threshold)
            I1 = im2double(I1);
            I2 = im2double(I2);
            [rows, cols] = size(I1);
            X = [I1(:), I2(:)];

            [~, score, ~] = pca(X);
            pc1 = reshape(score(:,1), rows, cols);

            if nargin < 3 || isnan(threshold)
                threshold = graythresh(pc1);
            end
            changeMask = imbinarize(pc1, threshold);
        end

    end
end
