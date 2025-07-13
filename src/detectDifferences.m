function [diffMask, boundaries] = detectDifferences(img1, img2, method, sensitivity,mask)
    % Convert to grayscale for structural comparison
    gray1 = rgb2gray(img1);
    gray2 = rgb2gray(img2);

    
    switch lower(method)
        case 'ssim'
            % Compute SSIM map
            [~, ssimMap] = ssim(gray2, gray1);
            % Invert similarity map -> difference map
            diffMask = ssimMap < sensitivity;
            
        case 'absdiff'
            % Compute absolute difference
            diffImg = imabsdiff(gray1, gray2);
            diffImg(~mask) = 0;
            % Normalize difference image to range [0,1]
            diffImg = mat2gray(diffImg);
            % Threshold based on sensitivity
            diffMask = diffImg > sensitivity;
            
        case 'combined'
            % Combine SSIM and absdiff masks
            [~, ssimMap] = ssim(gray2, gray1);
            ssimMask = ssimMap < sensitivity;
            diffImg = imabsdiff(gray1, gray2);
            diffImg = mat2gray(diffImg);
            absMask = diffImg > sensitivity;
            % Logical AND or OR depending on preference
            diffMask = ssimMask | absMask;

        otherwise
            error('Unsupported method: %s', method);
    end
    
    % Clean up mask: remove small noise areas
    diffMask = imclose(diffMask, strel('disk', 10));  % fill small gaps
    diffMask = bwareaopen(diffMask, 100);  % remove small blobs

    
    % Extract boundaries for overlay visualization
    boundaries = bwboundaries(diffMask);
end
