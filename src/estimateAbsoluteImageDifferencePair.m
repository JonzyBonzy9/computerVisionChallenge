function [mask] = estimateAbsoluteImageDifferencePair(image1, image2, param)
% Estimate a difference mask between two images using block-wise comparison.
%
% Inputs:
%   image1, image2 - grayscale or RGB images
%   param - struct with fields:
%       - blockSize: size of aggregation block (e.g., 3)
%       - diffThreshold: pixel/block difference threshold
%       - areaSupport: size of local neighborhood for support filtering
%
% Output:
%   mask - binary or continuous mask depending on maskType

    arguments
        image1
        image2
        param.blockSize (1,1) double = 3
        param.diffThreshold (1,1) double = 15
        param.areaSupport (1,1) double = 2
        param.minNeighbors(1,1) double = 2

    end

    %% 1. convert to grayscale if needed
    if size(image1, 3) == 3
        image1 = rgb2gray(image1);
    end
    if size(image2, 3) == 3
        image2 = rgb2gray(image2);
    end
    
    image1 = im2double(image1);
    image2 = im2double(image2);
    
    %% 2. calculate blockwise average
    bs = param.blockSize;

    image1_blocked = blockproc(image1, [bs bs], @(block_struct) mean(block_struct.data(:)));
    image2_blocked = blockproc(image2, [bs bs], @(block_struct) mean(block_struct.data(:)));

    %% 3. compute absolute difference
    diffImg = abs(image1_blocked - image2_blocked);

    %% 4. threshold to binary mask
    initialMask = diffImg > param.diffThreshold;
    
    %% 5. area batch filtering
    if param.areaSupport > 0
        supportKernel = ones(2*param.areaSupport + 1);
        neighborCount = conv2(double(initialMask), supportKernel, 'same');
        mask = initialMask & (neighborCount > param.minNeighbors);
    else
        mask = initialMask;
    end
    
    %% 6. resize mask to match original image size with smooth edges
    mask = imresize(mask, size(image1), 'bilinear');

    %% 7. remove non-overlapping areas
    overlapMask = (image1 > 0) & (image2 > 0);
    mask = mask .* overlapMask;

end
