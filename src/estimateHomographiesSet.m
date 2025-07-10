% todo:
% adjust return params
% make it faster

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

        function [transforms, groups, scoreMatrix, G] = estimateHomographiesGraphBased(imageArray, dispfunc)
            % ESTIMATEHOMOGRAPHIESGRAPHBASED Estimates homographies between images in an array
            %
            % Input Arguments:
            %     imageArray - array of images with associated data and IDs
            %
            % Output Arguments:
            %     rel_info_list - list of relative homographies and their scores
            %       transforms: id: transformation matrix (id is id from
            %       imageArray)
            %       groups: [[ids group1][ids group2]...] ids -> ids from
            %       imageArray
            %       scoreMatrix: matrix of cross scores between all images
            %       g Graph
            
            % turn off all warnings for debugging purposes
            warning('off', 'all')

            if nargin < 2
                dispfunc = @fprintf;
            end
            
            % preallocate arrays for speed
            numImages = length(imageArray); % Get the number of images
            numPairs = numImages * (numImages - 1) / 2;
            scores = zeros(1, numPairs);
            id1s = cell(1, numPairs);
            id2s = cell(1, numPairs);
            Hs = cell(1, numPairs);
            scoreMatrix = inf(numImages);
            pairIdx = 1;

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

                        % ======= Attempt 2: SURF (medium leniency) =======
                        if ~success
                            dispfunc("Retrying SURF with MetricThreshold = 700, MaxRatio = 0.68...\n");
                            [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                                'FeatureExtractionMethod', "SURF", ...
                                'MetricThreshold', 700, ...
                                'MaxRatio', 0.68, ...
                                'MaxNumTrials', 35000, ...
                                'Confidence', 97.0, ...
                                'MaxDistance', 7, ...
                                'dispfunc', dispfunc);
                        end

                        % ======= Attempt 3: SURF (most tolerant) =======
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
                        
                        % get score
                        score = calcScore(inlierRatio,inlierPts1,success,dispfunc);

                    else
                        H = eye(3);
                        score = 0;
                    end

                    scores(pairIdx) = score;
                    id1s{pairIdx} = imageArray{i}.id;
                    id2s{pairIdx} = imageArray{j}.id;
                    Hs{pairIdx} = H;
                    scoreMatrix(i,j) = score;
                    scoreMatrix(j,i) = score;

                    pairIdx = pairIdx + 1;
                end
            end
            
            % create lookup map for H matrices
            edgeMap = createLookupMapForHs(id1s, id2s, Hs);

            % build the graph
            [G] = estimateHomographiesSet.buildUndirectedGraph(id1s, id2s, scores);
           
            % get a list of all subgraph groups with image ids
            components = conncomp(G);
            numComponents = max(components);
            groups = cell(1, numComponents);
            for k = 1:numComponents
                nodeIndices = find(components == k);
                groups{k} = G.Nodes.Name(nodeIndices);
            end
            
            % initialize return array
            transforms = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % loop over all subgraphs
            for subgraphId = 1:numComponents
                subgraphNodes = groups{subgraphId};  
                startId = string(subgraphNodes(1));
                
                % map start id to eye
                transforms(startId) = eye(3);

                % loop over all other elements in the subgraph
                for elementId = 2:length(subgraphNodes)
                    endId = string(subgraphNodes(elementId));

                    % find optimal path in graph
                    [~, path_Hs, status, ~] = findOptimalPathWithInfo(G, startId, endId, edgeMap, dispfunc);
                    
                    % get the H matrix for the full path
                    M = eye(3); % Initialize transformation matrix as identity
                    if status
                        for i = length(path_Hs):-1:1
                            M = M * path_Hs{i}; % Accumulate homographies
                        end
                    end
                    
                    transforms(endId) = M;
                end
            end

            % turn all warnings back on
            warning('on', 'all')
        end

        function [G] = buildUndirectedGraph(id1s, id2s, scores)
            % BUILDUNDIRECTEDGRAPH Create an undirected graph from edge data,
            % filtering out edges with infinite weights while preserving all nodes.
            %
            % Input Arguments:
            %     id1s   - Source node identifiers (cell array or string array)
            %     id2s   - Target node identifiers (cell array or string array)
            %     scores - Numeric vector of edge weights or scores
            %
            % Output Arguments:
            %     G      - Undirected graph object containing all nodes, 
            %              with edges having finite weights only
        
            % Convert node IDs to strings (in case input is cell or char)
            id1s = string(id1s);
            id2s = string(id2s);
        
            % Identify edges with finite (non-Inf) scores
            validEdges = isfinite(scores);
        
            % Filter edges to only those with finite weights
            filteredId1s = id1s(validEdges);
            filteredId2s = id2s(validEdges);
            filteredScores = scores(validEdges);
        
            % Get list of all unique nodes (including isolated ones)
            allNodes = unique([id1s; id2s]);
        
            % Create graph with filtered edges and all nodes explicitly specified
            G = graph(filteredId1s, filteredId2s, filteredScores, allNodes);
        end

    end
end

function edgeMap = createLookupMapForHs(id1s, id2s, Hs)
    % CREATELOOKUPMAPFORHS Function to create a lookup map for homographies
    %
    % Input Arguments:
    %     id1s - array of first identifiers
    %     id2s - array of second identifiers
    %     Hs   - cell array of homography matrices
    %
    % Output Arguments:
    %     edgeMap - a map containing homographies and their inverses

    % Initialize a map to store homographies with string keys
    edgeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    % Loop through each homography and create entries in the map
    for i = 1:length(Hs)
        id1 = string(id1s(i));
        id2 = string(id2s(i));
        key1 = id1 + "_" + id2; % Create key for the direct homography
        key2 = id2 + "_" + id1; % Create key for the inverse homography
        edgeMap(key1) = Hs{i};   % Store the homography in the map
        edgeMap(key2) = inv(Hs{i}); % Store the inverse homography in the map
    end
end
function [optimalPath, pathHomographies,status, totalScore] = findOptimalPathWithInfo(G, startId, endId, edgeMap, dispfunc)
    % FINDOPTIMALPATHWITHINFO Function to find the optimal path in a graph
    %
    % Input Arguments:
    %     G        - Graph object containing nodes and edges
    %     startId  - ID of the starting node
    %     endId    - ID of the ending node
    %     edgeMap  - Map containing homographies for edges
    %     dispfunc - Function handle for displaying messages
    %
    % Output Arguments:
    %     optimalPath      - List of nodes in the optimal path
    %     pathHomographies  - List of homographies corresponding to the edges in the path
    %     totalScore       - Total score of the optimal path
    
    % init status as unsuccessful
    status = 0;
    
    % Defaults
    pathHomographies = {};
    % Convert ids to string for consistency
    startId = string(startId);
    endId = string(endId);
    % Initialize optimal path and total score
    optimalPath = [];
    totalScore = inf;
    try
        nodeNames = string(G.Nodes.Name);
        % Check if both start and end nodes exist in the graph
        if ~any(nodeNames == startId) || ~any(nodeNames == endId)
            dispfunc('Graph does not contain one or both nodes: %s → %s', startId, endId);
        else
            % Compute the shortest path between startId and endId
            [optimalPath, totalScore] = shortestpath(G, startId, endId);
        end
    catch ME
        % Handle unexpected errors during shortest path computation
        dispfunc('Unexpected error during shortest path: %s', ME.message);
    end
    % Check if an optimal path has been found
    if isempty(optimalPath)
        dispfunc('No path found between %s and %s.', startId, endId);
        return;
    end
    % Get list of homographies on the optimal path
    for i = 2:length(optimalPath)
        id1 = string(optimalPath(i-1));
        id2 = string(optimalPath(i));
        key = id1 + "_" + id2;
        % Check if the edge exists in the edgeMap
        if edgeMap.isKey(key)
            pathHomographies{end+1} = edgeMap(key);
        else
            % Handle missing edges by adding an identity matrix
            pathHomographies{end+1} = eye(3);
            dispfunc('Missing edge for key %s', key);
        end    
    end   
    % set status as successful
    status = 1;
end
function score = calcScore(inlierRatio,inlierPts,success,dispfunc)
    % CALCSCORE Function to calculate a score based on inlier ratio and points
    %
    % Input Arguments:
    %     inlierRatio - ratio of inliers to total points
    %     inlierPts - array of inlier points
    %     success - boolean indicating if the calculation was successful
    %     dispfunc - function handle for displaying messages
    %
    % Output Arguments:
    %     score - calculated score (lower is better)

    if success
        % Calculate raw score based on inlier ratio and number of inliers
        rawScore = (70 * inlierRatio) + numel(inlierPts); 
        % Calculate final score as the inverse of the raw score
        score = 1/rawScore; 
        % Display success message with inlier ratio and count
        dispfunc("successful calculation with inlier ratio (%.2f) and #inliers (%d)\n", inlierRatio, length(inlierPts));
    else
        % Assign high score if ransac is unsuccessful
        score = inf; 
        % Display failure message with inlier ratio and count
        dispfunc("calculation failed with inlier ratio (%.2f) and #inliers (%d)\n", inlierRatio, length(inlierPts));
    end
end