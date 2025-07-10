classdef calcOverlay < handle
    %CALCOVERLAY Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = public)
        % input data
        imageArray  %% array with id (date) and data field

        % calculation inputs and results
        lastIndices
        lastOutput
        resultAvailable
        scoreMatrix

        % calculated transforms for overlay
        transforms  %% transforms which align all images in particular calculation
        groups      %% one cell per group with the ids of the images
        g       %% Graph how the images are connected based on the results
        
        % precomputed warp
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
        function obj = calculate(obj, idxs, method, dispFunction)
            if nargin < 3
                method = 'succesive';  % or whatever your default is
            end
            if nargin < 4
                dispFunction = @fprintf;
            end
            obj.lastIndices = idxs;
            switch method
                case 'succesive'
                    obj.homographieSuccesive(dispFunction);
                case 'graph'
                    obj.homographieGraphBased(dispFunction);
            end
            
            obj.warp();
            obj.resultAvailable = true;
        end
        function obj = setProperties(obj)
        end
        function overlay = createOverlay(obj, idxs)
            disp("overlay")
            % Only proceed if we have valid previous data
            if isempty(obj.lastIndices)
                overlay = [];  % or some default like zeros(...)
                return;
            end
                        
            % Only keep indices that are were part of last calculation
            validSelection = intersect(idxs, obj.lastIndices);
            % transform to local indices matching filtered images array
            [~, localIdxs] = ismember(validSelection, obj.lastIndices);

            % Initialize overlay and alpha mask sum
            [H, W, ~] = size(obj.warpedImages{1});
            overlay = zeros(H, W, 3, 'double');
            alphaMaskSum = zeros(H, W);
            alpha = 0.5;

            for i = 1:length(obj.lastIndices)
                if ~ismember(i, localIdxs)
                    continue;
                end

                mask = obj.warpedMasks{i};
                overlay = overlay + obj.warpedImages{i} .* alpha .* cat(3, mask, mask, mask);
                alphaMaskSum = alphaMaskSum + alpha .* mask;
            end
        
            % Normalize and convert
            alphaMaskSum(alphaMaskSum == 0) = 1;
            overlay = overlay ./ cat(3, alphaMaskSum, alphaMaskSum, alphaMaskSum);
            overlay = im2uint8(overlay);
        end
        function scoreMatrix = createScoreConfusion(obj)
            scoreMatrix = obj.scoreMatrix;  % Return the score matrix for further analysis
            scoreMatrix(isinf(scoreMatrix)) = NaN;
        end
        function plotReachabilityGraph(obj, ax)
            filteredImages = obj.imageArray(obj.lastIndices);
            transformImageIDs = cellfun(@(im) im.id, filteredImages);

            % Determine identity transformation (tolerance for floating-point)
            isIdentity = cellfun(@(T) norm(T - eye(3), 'fro') < 1e-10, obj.transforms);
            identityIDs = transformImageIDs(isIdentity);  % datetime array
            
            % Create logical mask for graph nodes that match identity transforms
            graphNodeIDs = obj.g.Nodes.Name;  % datetime array
            isIdentityNode = ismember(graphNodeIDs, identityIDs);  % logical array
            p = plot(ax, obj.g, ...
                'Layout', 'force', ...
                'EdgeLabel', obj.g.Edges.Weight, ...
                'NodeLabel', obj.g.Nodes.Name);
            
            % Apply colors
            p.NodeCData = double(isIdentityNode) + 1;  % 1 if false (blue), 2 if true (red)


            % Title
            title(ax, 'Clustered Reachability Graph with Edge Weights');
        end
    end

    methods (Access = private)
        function homographieSuccesive(obj, dispFunction)
            filteredImages = obj.imageArray(obj.lastIndices);
            obj.lastOutput = estimateHomographiesSet.estimateHomographiesSuccessive(filteredImages, dispFunction);

            % --- Create Score Matrix ---
            % assume the output is ordered as the images are
            n = numel(obj.lastOutput);
            obj.scoreMatrix = inf(n+1);  % default to inf or NaN
            obj.scoreMatrix(1:n+2:end) = 0;  % diagonal is 0 (image vs itself)
        
            % Fill in scores from rel_info_list
            for i = 1:n
                score = obj.lastOutput{i}.score;
                obj.scoreMatrix(i, i+1) = score;
                obj.scoreMatrix(i+1, i) = score;  % assume symmetric
            end

            % --- Compute Cumulative Transforms ---
            obj.transforms = cell(1, length(filteredImages));
            obj.transforms{1} = eye(3);
            for i = 2:length(filteredImages)
                obj.transforms{i} = obj.transforms{i-1} * obj.lastOutput{i-1}.H;
            end

            ids = cellfun(@(im) im.id, filteredImages, 'UniformOutput', false);
            scores = [];
            for i = 1:n
                scores(i) = obj.lastOutput{i}.score;
            end

            obj.g = estimateHomographiesSet.buildUndirectedGraph(ids(1:end-1), ids(2:end), scores);
        
            % --- Set Groups (cell with one element: lastIndices) ---
            obj.groups = {obj.lastIndices};
        end

        function homographieGraphBased(obj, dispFunction)
            filteredImages = obj.imageArray(obj.lastIndices);
            [tr, gr, obj.scoreMatrix, obj.g] = estimateHomographiesSet.estimateHomographiesGraphBased(filteredImages, dispFunction);
            
            imageIds = cellfun(@(im) im.id, filteredImages);
            transformKeys = tr.keys;
            obj.transforms = cell(1, length(filteredImages));
            % Map each key to the index in imageIds
            [found, idxs] = ismember(string(transformKeys), string(imageIds));
            
            for k = 1:numel(transformKeys)
                if found(k)
                    obj.transforms{idxs(k)} = tr(transformKeys{k});
                end
            end

            % Convert group ID entries to indices in imageIds
            indexedGroups = cell(size(gr));
            for i = 1:numel(gr)
                [found, idxs] = ismember(gr{i}, imageIds);
                if ~all(found)
                    warning('Some group IDs were not found in imageIds.');
                end
                indexedGroups{i} = idxs(found);  % optionally keep only valid indices
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

            obj.warpedImages = cell(1, numTransforms);
            obj.warpedMasks = cell(1, numTransforms);
            
            % warp
            for i = 1:numTransforms
                img = filteredImages{i}.data;
                tform = projective2d(obj.transforms{i});
                warpedImg = imwarp(img, tform, 'OutputView', ref);
                obj.warpedMasks{i} = imwarp(true(size(img,1), size(img,2)), tform, 'OutputView', ref);                
                obj.warpedImages{i} = im2double(warpedImg);
            end
        end
    end
end