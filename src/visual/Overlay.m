classdef Overlay < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable   logical
        lastOutput
        LastCalculatedIndices

        Grid            matlab.ui.container.GridLayout
        Axes            matlab.ui.control.UIAxes
        CheckboxGrid    matlab.ui.container.GridLayout
        Checkboxes      matlab.ui.control.CheckBox
        CalculateButton matlab.ui.control.Button
        ClearButton     matlab.ui.control.Button
        AllButton       matlab.ui.control.Button
        SizingModeDropdown matlab.ui.control.DropDown

    end

    methods
        % Constructor
        function obj = Overlay(app)
            addpath(fullfile(pwd, '..'));
            obj.App = app;
            obj.dataAvailable = false;
        
            % Create main layout
            obj.Grid = uigridlayout(app.MainContentPanel, [2, 1]);
            obj.Grid.RowHeight = {'1x'};
            obj.Grid.ColumnWidth = {'1x', 'fit'};
            obj.Grid.Visible = 'off';
        
            % Create image display area
            obj.Axes = uiaxes(obj.Grid);
            obj.Axes.Layout.Row = 1;
            obj.Axes.Layout.Column = 1;
            obj.Axes.XTick = [];
            obj.Axes.YTick = [];
        
            % Create control panel
            controlPanel = uipanel(obj.Grid);
            controlPanel.Layout.Row = 1;
            controlPanel.Layout.Column = 2;
        
            controlLayout = uigridlayout(controlPanel);
            controlLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x', 'fit'};
            controlLayout.ColumnWidth = {'1x'};
        
            % Create checkbox grid
            obj.CheckboxGrid = uigridlayout(controlLayout);
            obj.CheckboxGrid.Layout.Row = 1;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            obj.CheckboxGrid.RowSpacing = 2;

            obj.ClearButton = uibutton(controlLayout, 'push', ...
                'Text', 'Clear all', ...
                'FontColor', 'red', ...
                'ButtonPushedFcn', @(btn, evt)obj.clearCheckboxes());
            obj.ClearButton.Layout.Row = 2;

            obj.AllButton = uibutton(controlLayout, 'push', ...
                'Text', 'Select all', ...
                'FontColor', 'green', ...
                'ButtonPushedFcn', @(btn, evt)obj.allCheckboxes());
            obj.AllButton.Layout.Row = 3;

            % Create sizing mode dropdown
        obj.SizingModeDropdown = uidropdown(controlLayout, ...
            'Items', {'Size to First Image', 'Fit All Images'}, ...
            'Value', 'Size to First Image', ...
            'Tooltip', 'Select overlay sizing mode');
        obj.SizingModeDropdown.Layout.Row = 4;  % Adjust rows below accordingly
        
            % Create Calculate button
            obj.CalculateButton = uibutton(controlLayout, 'push', ...
                'Text', 'Calculate Overlay', ...
                'ButtonPushedFcn', @(btn, evt)obj.calculate());
            obj.CalculateButton.Layout.Row = 6;            
        end

        function onImLoad(obj)
            % Update panel
            obj.dataAvailable = true;            
        end

        function show(obj)
            obj.Grid.Visible = 'on';
            
            obj.update()
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

        function update(obj)
            % update view if data is available
            if ~obj.dataAvailable
                return;
            end
        
            % Clear old checkboxes from UI and memory
            delete(obj.CheckboxGrid.Children);
            obj.Checkboxes = matlab.ui.control.CheckBox.empty;
        
            imageArray = obj.App.imageArray;
            n = length(imageArray);
        
            % One row per checkbox
            obj.CheckboxGrid.RowHeight = repmat({'fit'}, 1, n);

            % Default: nothing was calculated
            calculatedIdxs = [];
        
            if ~isempty(obj.LastCalculatedIndices)
                calculatedIdxs = obj.LastCalculatedIndices;
            end
        
            for i = 1:n
                dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                isChecked = ismember(i, calculatedIdxs);
                cb = uicheckbox(obj.CheckboxGrid, ...
                    'Text', dateStr, ...
                    'Value', isChecked, ...
                    'ValueChangedFcn', @(src, evt) obj.onCheckboxChanged(i));
                % Set font color depending on previous use
                if isChecked
                    cb.FontColor = [0, 1, 0];  % green if used in last calculation
                else
                    cb.FontColor = [1, 1, 1];  % Black otherwise
                end
                obj.Checkboxes(i) = cb;
            end
        end
    end

    methods (Access = private)
        function clearCheckboxes(obj)
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).Value = false;
            end
        end
        function allCheckboxes(obj)
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).Value = true;
            end
        end
        function calculate(obj)
            obj.LastCalculatedIndices = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            imageArray = obj.App.imageArray(obj.LastCalculatedIndices);
            
            if numel(imageArray) < 2
                uialert(obj.App.UIFigure, 'Please select at least two images.', 'Not enough images');
                return;
            end
        
            % Calculate
            obj.lastOutput = estimateHomographiesSet(imageArray);

            for i = 1:length(obj.Checkboxes)
                if ismember(i, obj.LastCalculatedIndices)
                    obj.Checkboxes(i).FontColor = [0, 1, 0];  % Blue
                else
                    obj.Checkboxes(i).FontColor = [1, 1, 1];  % Black (default)
                end
            end

            useFirstImageSize = strcmp(obj.SizingModeDropdown.Value, 'Size to First Image');

            overlay = obj.createOverlay(obj.LastCalculatedIndices, useFirstImageSize);

            imshow(overlay, 'Parent', obj.Axes);

        end
        function overlay = createOverlay(obj, idxs, useFirstImageSize)
            if nargin < 3
                useFirstImageSize = true; % default behavior: size to first image
            end
        
            [~, localIdxs] = ismember(idxs, obj.LastCalculatedIndices);
            numTransforms = length(obj.LastCalculatedIndices);
        
            % Initialize transforms
            transforms = cell(1, numTransforms);
            transforms{1} = eye(3);
            for i = 2:numTransforms
                transforms{i} = transforms{i-1} * obj.lastOutput{i-1}.H;
            end
        
            imageArray = obj.App.imageArray(obj.LastCalculatedIndices);
        
            if useFirstImageSize
                % Reference: first image size (original behavior)
                refImage = imageArray{1}.data;
                ref = imref2d(size(refImage));
            else
                % Calculate bounding box that fits all warped images
                allCorners = [];
                for i = 1:numTransforms
                    if ~ismember(i, localIdxs)
                        continue;
                    end
                    img = imageArray{i}.data;
                    [h, w, ~] = size(img);
                    corners = [1, 1; w, 1; w, h; 1, h];
                    tform = projective2d(transforms{i});
                    warpedCorners = transformPointsForward(tform, corners);
                    allCorners = [allCorners; warpedCorners];
                end
                xMin = floor(min(allCorners(:,1)));
                xMax = ceil(max(allCorners(:,1)));
                yMin = floor(min(allCorners(:,2)));
                yMax = ceil(max(allCorners(:,2)));
        
                width = xMax - xMin + 1;
                height = yMax - yMin + 1;
        
                ref = imref2d([height, width], [xMin, xMax], [yMin, yMax]);
            end
            
            % Initialize overlay and alpha mask sum
            overlay = zeros([ref.ImageSize, 3], 'double');
            alphaMaskSum = zeros(ref.ImageSize);
            alpha = 0.5;

            for i = 1:numTransforms
                if ~ismember(i, localIdxs)
                    continue;
                end
                img = imageArray{i}.data;
                tform = projective2d(transforms{i});
                warpedImg = imwarp(img, tform, 'OutputView', ref);
                mask = imwarp(true(size(img,1), size(img,2)), tform, 'OutputView', ref);        
                
                warpedImgD = im2double(warpedImg);
                overlay = overlay + warpedImgD .* alpha .* cat(3, mask, mask, mask);
                alphaMaskSum = alphaMaskSum + alpha .* mask;
            end
        
            % Normalize and convert
            alphaMaskSum(alphaMaskSum == 0) = 1;
            overlay = overlay ./ cat(3, alphaMaskSum, alphaMaskSum, alphaMaskSum);
            overlay = im2uint8(overlay);
        end
        function onCheckboxChanged(obj, idx)
            % Only proceed if we have valid previous data
            if isempty(obj.LastCalculatedIndices)
                return;
            end
            if ~ismember(idx, obj.LastCalculatedIndices)
                return;
            end
            
            % Get current checkbox states
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));
            
            % Keep only those that were used in last calculation
            validSelection = intersect(selected, obj.LastCalculatedIndices);            
            
            useFirstImageSize = strcmp(obj.SizingModeDropdown.Value, 'Size to First Image');
            overlay = obj.createOverlay(validSelection, useFirstImageSize);
            if ~isempty(overlay)
                imshow(overlay, 'Parent', obj.Axes);
            else
                cla(obj.Axes);  % Clear if overlay couldn't be created
            end
        end
    end

    methods (Static)
        function name = getName()
            name = 'Overlay';
        end
    end
end