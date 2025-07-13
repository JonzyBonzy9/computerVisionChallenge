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

        % Cell array of 4D image stacks for efficient blending, one stack per group
        % imageStack{groupIdx} = (H x W x C x N) array for group groupIdx
        imageStack

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
                method = 'successive';  % or whatever your default is
            end
            if nargin < 4
                dispFunction = @fprintf;
            end
            obj.lastIndices = idxs;
            switch method
                case 'successive'
                    obj.homographiesuccessive(dispFunction);
                case 'graph'
                    obj.homographieGraphBased(dispFunction);
            end

            obj.warp();
            obj.resultAvailable = true;
        end
        function overlay = createOverlay(obj, indices)
            disp("overlay")
            group = 1;
            % check whether overlay was already calculated
            if ~obj.resultAvailable
                % Initialize overlay with first image
                overlay = im2double(obj.imageArray{indices(1)}.data);
                % Add remaining images
                for i = 2:length(indices)
                    idx = indices(i);
                    overlay = overlay + im2double(obj.imageArray{idx}.data);
                end
                % Average all accumulated images
                overlay = overlay ./ length(indices);
                overlay = im2uint8(overlay);
                return
            end
            validSelection = intersect(indices, obj.lastIndices);
            [~, localIdxs] = ismember(validSelection, obj.lastIndices);
            overlay = sum(obj.imageStack{group}(:,:,:,localIdxs), 4);  % Sum across the 4th dimension (N images in group)
            overlay = overlay ./ length(validSelection);  % Average the sum
        end

        function scoreMatrix = createScoreConfusion(obj)
            scoreMatrix = obj.scoreMatrix;  % Return the score matrix for further analysis
            scoreMatrix(~isfinite(scoreMatrix)) = NaN;  % Replace Inf/-Inf with NaN
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

            % Plot graph
            if numedges(obj.g) > 0
                % Plot with edge labels if edges exist
                p = plot(ax, obj.g, ...
                    'Layout', 'force', ...
                    'EdgeLabel', obj.g.Edges.Weight, ...
                    'NodeLabel', obj.g.Nodes.Name);
            else
                % Plot without edge labels if no edges
                p = plot(ax, obj.g, ...
                    'Layout', 'force', ...
                    'NodeLabel', obj.g.Nodes.Name);
            end

            % Apply colors: 1 for false (blue), 2 for true (red)
            p.NodeCData = double(isIdentityNode) + 1;

            % Title
            title(ax, 'Clustered Reachability Graph with Edge Weights');
        end
    end

    methods (Access = private)
        function homographiesuccessive(obj, dispFunction)
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
            allImageIds = cellfun(@(im) im.id, obj.imageArray());
            indexedGroups = cell(size(gr));
            for i = 1:numel(gr)
                [found, idxs] = ismember(gr{i}, allImageIds);
                if ~all(found)
                    warning('Some group IDs were not found in imageIds.');
                end
                indexedGroups{i} = idxs(found);  % optionally keep only valid indices
            end

            obj.groups = indexedGroups;

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

            % Create 4D image stack for efficient blending
            obj.createImageStack();
        end

        function createImageStack(obj)
            % Create 4D image stack from warpedImages for efficient blending
            if isempty(obj.warpedImages)
                obj.imageStack = [];
                return;
            end

            % Get dimensions from first image
            [H, W, C] = size(obj.warpedImages{1});

            numGroups = numel(obj.groups);
            obj.imageStack = cell(1, numGroups);
            for k = 1: numGroups
                groupSize = length(obj.groups{k});
                obj.imageStack{k} = zeros(H, W, C, groupSize, 'like', obj.warpedImages{1});
                for i = 1:groupSize
                    obj.imageStack{k}(:,:,:,i) = obj.warpedImages{obj.groups{k}(i)};
                end
            end
        end
    end
end