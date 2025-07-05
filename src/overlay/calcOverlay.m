classdef calcOverlay
    %CALCOVERLAY Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = public)
        lastIndices
        lastOutput
        resultAvailable
        transforms  %% all referenced to first indice image
        imageArray  %% array with id (date) and data field
        warpedImages
        warpedMasks

        % further public properties
        % e.g. parameters for algorithm
    end
    properties (Access = private)
        % private properties
    end

    methods
        %% constructor
        function obj = calcOverlay(imageArray)
            obj.imageArray = imageArray;
            obj.resultAvailable = false;
        end
        function obj = calculate(obj, idxs)
            obj.lastIndices = idxs;
            obj.homographieSuccesive();
            obj.warp();
            obj.resultAvailable = true;
        end
        function obj = setProperties(obj)
        end
    end

    methods (Access = private)
        function obj = homographieSuccesive(obj)
            filteredImages = obj.imageArray(obj.lastIndices);
            obj.lastOutput = estimateHomographiesSet(filteredImages);

            obj.transforms = cell(1, length(filteredImages));
            obj.transforms{1} = eye(3);
            for i = 2:numTransforms
                obj.transforms{i} = obj.transforms{i-1} * obj.lastOutput{i-1}.H;
                % transforms{i} = obj.lastOutput{i-1}.H; % -> use if all
                % transforms reference to image one already!!
            end
        end
        function warp(obj)
            filteredImages = obj.imageArray(obj.lastIndices);
            numTransforms = length(obj.lastIndices);

            % Calculate bounding box that fits all warped images
            allCorners = [];
            for i = 1:numTransforms
                img = filteredImages{i}.data;
                [h, w, ~] = size(img);
                corners = [1, 1; w, 1; w, h; 1, h];
                tform = projective2d(obj.transforms{i});
                warpedCorners = transformPointsForward(tform, corners);
                allCorners = [allCorners; warpedCorners];
            end
            xMin = floor(min(allCorners(:,1)));
            xMax = ceil(max(allCorners(:,1)));
            yMin = floor(min(allCorners(:,2)));
            yMax = ceil(max(allCorners(:,2)));
    
            width = xMax - xMin + 1;
            height = yMax - yMin + 1;
            
            % get reference for image
            ref = imref2d([height, width], [xMin, xMax], [yMin, yMax]);
            
            % warp
            for i = 1:numTransforms
                img = filteredImages{i}.data;
                tform = projective2d(filteredImages{i});
                warpedImg = imwarp(img, tform, 'OutputView', ref);
                obj.warpedMasks{i} = imwarp(true(size(img,1), size(img,2)), tform, 'OutputView', ref);                
                obj.warpedImages{i} = im2double(warpedImg);
            end
        end
    end
end