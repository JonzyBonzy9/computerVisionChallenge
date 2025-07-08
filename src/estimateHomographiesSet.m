classdef estimateHomographiesSet
    methods (Static)
        function [rel_info_list] = estimateHomographiesSuccessive(imageArray, dispfunc)
        %   Process all images passed by giving two consecutive images to
        %   'estimateHomographymatrixFromSatelite'. Stores the relative information
        %   between the consecutive images.
        %
        % Inputs:
        %   imageArray - Image Objects
        %
        % Outputs:
        %   rel_info_list -> Contains H, the inliner Points of H, the names of the compaired
        %   images and a quality score

            if nargin < 2
                dispfunc = @fprintf;
            end
            
            numImages = length(imageArray);
        
            % Sort images by ID
            % ids = cellfun(@(x) x.id, imageArray, 'UniformOutput', false);  % cell array of datetime
            % ids_dt = [ids{:}];  % concatenate into datetime array
            % [~, sortIdx] = sort(ids_dt);
            % imageArray = imageArray(sortIdx);

            % loop over image pairs
            for i = 1:numImages - 1
                img1 = imageArray{i}.data;
                img2 = imageArray{i + 1}.data;
        
                % Estimate homography
                [H, inlierPts1, inlierPts2, inlierRatio, success] = ...
                    estimateHomographyPair(img1, img2,'dispfunc',dispfunc);
                
                % get score
                score = calcScore(inlierRatio,inlierPts1,success,dispfunc);
        
                % store results
                rel_info_list{i} = struct( ...
                    'H', H, ...
                    'inlierPts1', inlierPts1, ...
                    'inlierPts2', inlierPts2, ...
                    'id1', imageArray{i}.id, ...
                    'id2', imageArray{i + 1}.id, ...
                    'inlierRatio', inlierRatio,...
                    'score', score);
            end
        end

        function [rel_info_list, scoreMatrix] = estimateHomographiesGraphBased(imageArray, dispfunc)
        % ESTIMATEHOMOGRAPHIESGRAPHBASED Estimates homographies between images in an array
        %
        % Input Arguments:
        %     imageArray - array of images with associated data and IDs
        %
        % Output Arguments:
        %     rel_info_list - list of relative homographies and their scores
            
            % turn off all warnings for debugging purposes
            warning('off', 'all')

            if nargin < 2
                dispfunc = @fprintf;
            end
        
            numImages = length(imageArray); % Get the number of images
            all_ids = unique(cellfun(@(x) x.id, imageArray)); % Extract unique image IDs
            
            scores = []; % Initialize scores array
            id1s = {}; % Initialize first image IDs array
            id2s = {}; % Initialize second image IDs array
            Hs = {}; % Initialize homographies array 
            scoreMatrix = inf(numImages);    % or NaN to indicate no data

            % Estimate all homographies and assign scores
            for i = 1:numImages
                for j = i+1:numImages
                    img1 = imageArray{i}.data; % Get data for the first image
                    img2 = imageArray{j}.data; % Get data for the second image
                    if i ~= j
                        dispfunc("------- comparing %s to %s -------\n",string(imageArray{i}.id),string(imageArray{j}.id))
                        % ======= Attempt 1: SURF (strictest) =======
                        dispfunc("Trying SURF with MetricThreshold = 1000, MaxRatio = 0.65...\n");
                        [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                            'FeatureExtractionMethod', "SURF", ...
                            'MetricThreshold', 1000, ...
                            'MaxRatio', 0.65, ...
                            'MaxNumTrials', 30000, ...
                            'Confidence', 98.0, ...
                            'MaxDistance', 6, ...
                            'dispfunc', dispfunc);
                        % 
                        % % ======= Attempt 2: SIFT fallback (strict) =======
                        % if ~success
                        %     dispfunc("SURF failed. Trying SIFT (ContrastThreshold = 0.01)...\n");
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod', "SIFT", ...
                        %         'ContrastThreshold', 0.01, ...
                        %         'EdgeThreshold', 10, ...
                        %         'NumLayersInOctave', 3, ...
                        %         'Sigma', 1.6, ...
                        %         'MaxRatio', 0.65, ...
                        %         'MaxNumTrials', 30000, ...
                        %         'Confidence', 98.0, ...
                        %         'MaxDistance', 6,...
                        %         'dispfunc', dispfunc);
                        % end
                        % 
                        % % ======= Attempt 3: SURF (medium leniency) =======
                        % if ~success
                        %     dispfunc("SIFT failed. Retrying SURF (MetricThreshold = 700, MaxRatio = 0.68)...\n");
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod', "SURF", ...
                        %         'MetricThreshold', 700, ...
                        %         'MaxRatio', 0.68, ...
                        %         'MaxNumTrials', 35000, ...
                        %         'Confidence', 97.0, ...
                        %         'MaxDistance', 7, ...
                        %         'dispfunc', dispfunc);
                        % end
                        % 
                        % % ======= Attempt 4: SIFT (more lenient) =======
                        % if ~success
                        %     dispfunc("Still failed. Retrying SIFT (ContrastThreshold = 0.005)...\n");
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod', "SIFT", ...
                        %         'ContrastThreshold', 0.005, ...
                        %         'EdgeThreshold', 15, ...
                        %         'NumLayersInOctave', 4, ...
                        %         'Sigma', 1.4, ...
                        %         'MaxRatio', 0.68, ...
                        %         'MaxNumTrials', 35000, ...
                        %         'Confidence', 97.0, ...
                        %         'MaxDistance', 7,
                        %         'dispfunc', dispfunc);
                        % end
                        % 
                        % ======= Attempt 5: SURF (most tolerant) =======
                        if ~success
                            dispfunc("Retrying SURF with MetricThreshold = 500, MaxRatio = 0.71...\n");
                            [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                                'FeatureExtractionMethod', "SURF", ...
                                'MetricThreshold', 500, ...
                                'MaxRatio', 0.71, ...
                                'MaxNumTrials', 40000, ...
                                'Confidence', 96.0, ...
                                'MaxDistance', 7, ...
                                'dispfunc', dispfunc);
                        end

                        % % ======= Attempt 6: SIFT (most lenient) =======
                        % if ~success
                        %     dispfunc("Still failed. Retrying SIFT (most lenient settings)...\n");
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod', "SIFT", ...
                        %         'ContrastThreshold', 0.002, ...      % Very low to allow weak features
                        %         'EdgeThreshold', 20, ...             % Higher to tolerate more edge-like features
                        %         'NumLayersInOctave', 5, ...            % More layers to catch features across scales
                        %         'Sigma', 1.2, ...                    % Slightly reduced smoothing
                        %         'MaxRatio', 0.7, ...                 % Slightly more lenient match filtering
                        %         'MaxNumTrials', 40000, ...
                        %         'Confidence', 96.0, ...
                        %         'MaxDistance', 8, ...
                        %         'dispfunc', dispfunc);
                        % end
                        
                        % get score
                        score = calcScore(inlierRatio,inlierPts1,success,dispfunc);

                    else
                        H = eye(3);
                        score = 0;
                    end

                    scores(end+1) = score; % Store score
                    id1s{end+1} = imageArray{i}.id; % Store first image ID
                    id2s{end+1} = imageArray{j}.id; % Store second image ID
                    Hs{end+1} = H; % Store homography
                    scoreMatrix(i,j) = score;
                    scoreMatrix(j,i) = score;
                end
            end
            
            % build the graph
            [Hs,G] = buildUndirectedGraph(id1s, id2s, scores, Hs);

            % Loop through all unique IDs to find optimal paths
            startId = all_ids(1); % Set starting ID
            rel_info_list = {}; % Initialize relative information list
            for x = 2:length(all_ids)
                endId = all_ids(x); % Set ending ID

                [optimalPath, path_Hs, status,totalScore] = findOptimalPathWithInfo(G, Hs, startId, endId, dispfunc);

                displayDebugGraph = true;
                if displayDebugGraph
                    % Debug: Display graph details
                    % Plot the graph
                    figure;
                    p = plot(G, ...
                        'Layout', 'force', ...
                        'EdgeLabel', G.Edges.Weight, ...
                        'NodeLabel', G.Nodes.Name);
                    title('Filtered Graph with Edge Weights');
                    
                    % Highlight start and end nodes
                    highlight(p, string(startId), 'NodeColor', 'green', 'MarkerSize', 8);
                    highlight(p, string(endId),   'NodeColor', 'red',   'MarkerSize', 8);
                    
                    % If optimal path is found, highlight it
                    if exist('optimalPath', 'var') && ~isempty(optimalPath)
                        highlight(p, optimalPath, 'EdgeColor', 'r', 'LineWidth', 2);
                    end
                end

                M = eye(3); % Initialize transformation matrix as identity
                if status
                    for i = length(path_Hs):-1:1
                        M = M * path_Hs{i}; % Accumulate homographies
                    end
                end
                % Store the relative homography information
                rel_info_list{end+1} = struct( ...
                    'H', M, ...
                    'id1', startId, ...
                    'id2', endId, ...
                    'score',totalScore);
            end

            % turn all warnings back on
            warning('on', 'all')
        end
    end
end

function [filteredHs,G] = buildUndirectedGraph(id1s, id2s, scores, Hs)
    % Filter edges based on threshold
    scoreThreshold = 1000;
    validEdges = scores <= scoreThreshold;

    % Filter and convert arguments
    filteredId1s = string(id1s(validEdges));
    filteredId2s = string(id2s(validEdges));
    filteredScores = scores(validEdges);
    filteredHs = Hs(validEdges);

    % Build undirected graph
    G = graph(filteredId1s, filteredId2s, filteredScores);
end

function [optimalPath, pathInfoMatrices, status, totalScore] = findOptimalPathWithInfo(G, Hs, startId, endId, dispfunc)
    % Default no path found status
    status = 0;
    
    % convert ids to string
    startId = string(startId);
    endId = string(endId);

    % Compute shortest path
    [optimalPath, totalScore] = shortestpath(G, startId, endId);

    if isempty(optimalPath)
        dispfunc('No path found between %s and %s.', startId, endId);
        pathInfoMatrices = {};
        return;
    end

    % Build map from sorted node pairs to H (only forward direction)
    edgeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    edgeEnds = G.Edges.EndNodes;
    makeEdgeKey = @(a,b) sprintf('%s_%s', sort([string(a), string(b)]));
    
    for i = 1:height(G.Edges)
        id1 = string(edgeEnds(i,1));
        id2 = string(edgeEnds(i,2));
        key = makeEdgeKey(id1, id2);
        edgeMap(key) = Hs{i};  % H for (min, max) direction
    end
    
    % Now, when collecting info matrices for the path:
    pathInfoMatrices = cell(length(optimalPath)-1, 1);
    for i = 1:length(optimalPath)-1
        id1 = optimalPath(i);
        id2 = optimalPath(i+1);
        key = makeEdgeKey(id1, id2);
        if edgeMap.isKey(key)
            H = edgeMap(key);
            % Check direction: if (id1, id2) is NOT sorted order, invert H
            if id1 > id2  % assuming string comparison works here
                pathInfoMatrices{i} = inv(H);
            else
                pathInfoMatrices{i} = H;
            end
        else
            dispfunc('Missing info matrix for edge %s', key);
            pathInfoMatrices{i} = eye(3); 
        end
    end

    status = 1;  % success
    
end

function score = calcScore(inlierRatio,inlierPts,success,dispfunc)
    if success
        rawScore = (70 * inlierRatio) + numel(inlierPts); % Calculate raw score
        score = 1/rawScore; % Calculate final score
        dispfunc("successful calculation with inlier ratio (%.2f) and #inliers (%d)\n", inlierRatio, length(inlierPts));
    else
        score = inf; % Assign high score if ransac is unsuccessful
        dispfunc("calculation failed with inlier ratio (%.2f) and #inliers (%d)\n", inlierRatio, length(inlierPts));
    end
end