classdef estimateHomographiesSet
    methods (Static)
        function [rel_info_list] = estimateHomographiesSuccessive(imageArray)
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
            
            numImages = length(imageArray);
        
            % Sort images by ID
            ids = cellfun(@(x) x.id, imageArray, 'UniformOutput', false);  % cell array of datetime
            ids_dt = [ids{:}];  % concatenate into datetime array
            [~, sortIdx] = sort(ids_dt);
            imageArray = imageArray(sortIdx);

            % loop over image pairs
            for i = 1:numImages - 1
                img1 = imageArray{i}.data;
                img2 = imageArray{i + 1}.data;
        
                % Estimate homography
                [H, inlierPts1, inlierPts2, inlierRatio, ~] = ...
                    estimateHomographyPair(img1, img2);
        
                % store results
                rel_info_list{i} = struct( ...
                    'H', H, ...
                    'inlierPts1', inlierPts1, ...
                    'inlierPts2', inlierPts2, ...
                    'id1', imageArray{i}.id, ...
                    'id2', imageArray{i + 1}.id, ...
                    'inlierRatio', inlierRatio);
            end
        end

        function [rel_info_list] = estimateHomographiesGraphBased(imageArray)
        % ESTIMATEHOMOGRAPHIESGRAPHBASED Estimates homographies between images in an array
        %
        % Input Arguments:
        %     imageArray - array of images with associated data and IDs
        %
        % Output Arguments:
        %     rel_info_list - list of relative homographies and their scores
            
            % turn off all warnings for debugging purposes
            warning('off', 'all')
        
            numImages = length(imageArray); % Get the number of images
            all_ids = unique(cellfun(@(x) x.id, imageArray)); % Extract unique image IDs
            
            scores = []; % Initialize scores array
            id1s = {}; % Initialize first image IDs array
            id2s = {}; % Initialize second image IDs array
            Hs = {}; % Initialize homographies array 
        
            % Estimate all homographies and assign scores
            for i = 1:numImages
                for j = i+1:numImages
                    img1 = imageArray{i}.data; % Get data for the first image
                    img2 = imageArray{j}.data; % Get data for the second image
                    if i ~= j
                        fprintf("------- comparing %s to %s -------\n",string(imageArray{i}.id),string(imageArray{j}.id))
                        % Attempt to estimate homography with the first set of parameters (strictest)
                        [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                            'FeatureExtractionMethod',"SURF",'MetricThreshold', 1000, 'MaxRatio', 0.65, 'MaxNumTrials', 30000, 'Confidence', 98.0, 'MaxDistance', 6);
                        
                        if ~success
                            disp('SURF failed. Trying SIFT fallback...\n');
                            
                            % Attempt with SIFT fallback
                            [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                                'FeatureExtractionMethod', "SIFT", ...
                                'ContrastThreshold', 0.01, ... 
                                'EdgeThreshold', 10, ...
                                'NumLayersInOctave', 3, ...
                                'Sigma', 1.6, ...
                                'MaxRatio', 0.65, ...
                                'MaxNumTrials', 30000, ...
                                'Confidence', 98.0, ...
                                'MaxDistance', 6);
                        end

                        % % If unsuccessful, try the second set (moderate looseness)
                        % if ~success
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod',"SURF",'MetricThreshold', 700, 'MaxRatio', 0.68, 'MaxNumTrials', 35000, 'Confidence', 97.0, 'MaxDistance', 7);
                        % end
                        % 
                        % % If still unsuccessful, try the third set (more tolerant)
                        % if ~success
                        %     [H, inlierPts1, ~, inlierRatio, success] = estimateHomographyPair(img1, img2, ...
                        %         'FeatureExtractionMethod',"SURF",'MetricThreshold', 500, 'MaxRatio', 0.71, 'MaxNumTrials', 40000, 'Confidence', 96.0, 'MaxDistance', 8);
                        % end

                        % Calculate score based on inlier ratio if successful
                        if success
                            rawScore = (70 * inlierRatio) + numel(inlierPts1); % Calculate raw score
                            score = 1/rawScore; % Calculate final score
                        else
                            score = inf; % Assign high score if ransac is unsuccessful
                        end
                    else
                        H = eye(3);
                        score = 0;
                    end

                    scores(end+1) = score; % Store score
                    id1s{end+1} = imageArray{i}.id; % Store first image ID
                    id2s{end+1} = imageArray{j}.id; % Store second image ID
                    Hs{end+1} = H; % Store homography

                    % store inverse
                    id1s{end+1} = imageArray{j}.id;
                    id2s{end+1} = imageArray{i}.id;
                    scores(end+1) = score;
                    Hs{end+1} = inv(H); 
                end
            end
            
            startId = all_ids(1); % Set starting ID
            rel_info_list = {}; % Initialize relative information list
            
            % Loop through all unique IDs to find optimal paths
            for x = 2:length(all_ids)
                endId = all_ids(x); % Set ending ID
                [~, path_Hs, status,totalScore] = findOptimalPathWithInfo(id1s, id2s, scores, Hs, startId, endId, true);
                if status
                    M = eye(3); % Initialize transformation matrix as identity
                    for i = length(path_Hs):-1:1
                        M = M * path_Hs{i}; % Accumulate homographies
                    end
                else
                    M = eye(3); % Reset to identity if no successful path
                end
                % Store the relative homography information
                rel_info_list{end+1} = struct( ...
                    'H', M, ...
                    'id1', startId, ...
                    'id2', endId, ...
                    'score',totalScore);
            end
        end
    end
end



function [optimalPath, pathInfoMatrices, status, totalScore] = findOptimalPathWithInfo(id1s, id2s, scores, Hs, startId, endId,displayDebugGraph)
    % Default no path found status
    status = 0;
    totalScore = inf;
    optimalpath = [];
    pathInfoMatrices = [];

    % Filter edges based on threshold
    scoreThreshold = 1000;
    validEdges = scores <= scoreThreshold;
    filteredId1s = string(id1s(validEdges));
    filteredId2s = string(id2s(validEdges));
    filteredScores = scores(validEdges);
    filteredInfo = Hs(validEdges);
    startId = string(startId);
    endId = string(endId);

    % Check if startId and endId appear in edge lists at all
    allNodes = unique([filteredId1s; filteredId2s]);
    if ~ismember(startId, allNodes)
        warning('Start node %s not found in edge list.', startId);
        optimalPath = [];
        pathInfoMatrices = {};
        return;
    end
    if ~ismember(endId, allNodes)
        warning('End node %s not found in edge list.', endId);
        optimalPath = [];
        pathInfoMatrices = {};
        return;
    end

    % Build the graph
    G = digraph(filteredId1s, filteredId2s, filteredScores);

    % Check if startId and endId exist in graph nodes
    if ~ismember(startId, G.Nodes.Name)
        warning('Start node %s not found in graph nodes.', startId);
        optimalPath = [];
        pathInfoMatrices = {};
        return;
    end
    if ~ismember(endId, G.Nodes.Name)
        warning('End node %s not found in graph nodes.', endId);
        optimalPath = [];
        pathInfoMatrices = {};
        return;
    end

    % Compute shortest path
    [optimalPath, totalScore] = shortestpath(G, startId, endId);

    if isempty(optimalPath)
        warning('No path found between %s and %s.', startId, endId);
        pathInfoMatrices = {};
        return;
    end

    % Build lookup map from edges to info matrices
    edgeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:length(filteredId1s)
        key = sprintf('%s_%s', filteredId1s(i), filteredId2s(i));
        edgeMap(key) = filteredInfo{i};
    end

    % Collect info matrices for edges along the path
    pathInfoMatrices = cell(length(optimalPath)-1, 1);
    for i = 1:length(optimalPath)-1
        key = sprintf('%s_%s', optimalPath(i), optimalPath(i+1));
        if edgeMap.isKey(key)
            pathInfoMatrices{i} = edgeMap(key);
        else
            warning('Missing info matrix for edge %s', key);
            pathInfoMatrices{i} = [];  % or zeros(...) depending on your needs
        end
    end

    status = 1;  % success
    
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
        highlight(p, startId, 'NodeColor', 'green', 'MarkerSize', 8);
        highlight(p, endId, 'NodeColor', 'red', 'MarkerSize', 8);
        
        % If optimal path is found, highlight it
        if exist('optimalPath', 'var') && ~isempty(optimalPath)
            highlight(p, optimalPath, 'EdgeColor', 'r', 'LineWidth', 2);
        end
    end
end
