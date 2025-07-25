classdef DifferenceView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable

        Grid            matlab.ui.container.GridLayout
        Axes            matlab.ui.control.UIAxes
        CheckboxGrid    matlab.ui.container.GridLayout
        Checkboxes      matlab.ui.control.CheckBox
        CalculateButton matlab.ui.control.Button
        ClearButton     matlab.ui.control.Button
        SizingModeDropdown matlab.ui.control.DropDown
        MethodDropDown     matlab.ui.control.DropDown
        SliderThreshold matlab.ui.control.Slider
        SliderBlockSize matlab.ui.control.Slider
        SliderAreaMin  matlab.ui.control.Slider
        SliderAreaMax  matlab.ui.control.Slider
        ThresholdLabel matlab.ui.control.Label
        BlocksizeLabel matlab.ui.control.Label
        AreaMinLabel matlab.ui.control.Label
        AreaMaxLabel matlab.ui.control.Label
        GroupDropdown matlab.ui.control.DropDown
    end

    methods
        % Constructor
        function obj = DifferenceView(app)
            addpath(fullfile(pwd, '..'));
            addpath(fullfile(pwd, 'src/overlay'));
            
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
            controlLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            controlLayout.ColumnWidth = {'1x'};

            groupLayout = uigridlayout(controlLayout);
            groupLayout.ColumnWidth = {'1x', '1x'};
            groupLayout.RowHeight = {'1x'};
            groupLayout.Layout.Row = 1;
            
            obj.GroupDropdown = uidropdown(groupLayout, ...
                'Items', {'All'}, ...              
                'Tooltip', 'Select a group');
            obj.GroupDropdown.Layout.Column = 1;
        
            % Create checkbox grid
            obj.CheckboxGrid = uigridlayout(controlLayout);
            obj.CheckboxGrid.Layout.Row = 2;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            obj.CheckboxGrid.RowSpacing = 2;

            obj.ClearButton = uibutton(controlLayout, 'push', ...
                'Text', 'Clear all', ...
                'FontColor', 'red', ...
                'ButtonPushedFcn', @(btn, evt)obj.clearCheckboxes());
            obj.ClearButton.Layout.Row = 3;

            % Create sizing mode dropdown
            obj.SizingModeDropdown = uidropdown(controlLayout, ...
                'Items', {'Size to First Image', 'Fit All Images'}, ...
                'Value', 'Size to First Image', ...
                'Tooltip', 'Select overlay sizing mode');
            obj.SizingModeDropdown.Layout.Row = 5;  % Adjust rows below accordingly
        
            % Create Calculate button
            obj.CalculateButton = uibutton(controlLayout, 'push', ...
                'Text', 'Calculate Overlay', ...
                'ButtonPushedFcn', @(btn, evt)obj.calculate());
            obj.CalculateButton.Layout.Row = 7;

            % a lot of copy paste cause matlab is unable to have proper
            % coding conventions
            
            obj.MethodDropDown = uidropdown(controlLayout, ...
                'Items', differenceEstimationFunctions.valid_methods, ...
                'Value', {'absdiff'}, ...
                'Tooltip', 'Select method of estimation');
            obj.MethodDropDown.Layout.Row = 8;

            obj.SliderThreshold = uislider(controlLayout, ...
                'Limits', [differenceEstimationFunctions.value_range_threshold(1), differenceEstimationFunctions.value_range_threshold(end)], ...
                'Value', 0, ... %roundNiceTicks(differenceEstimationFunctions.value_range_threshold(1), differenceEstimationFunctions.value_range_threshold(end), 10), ...
                'Tooltip', 'Adjust threshold for overlay calculation');
            obj.SliderThreshold.Layout.Row = 10;

            obj.ThresholdLabel = uilabel(controlLayout, ...
                'Text', 'Threshold');
            obj.ThresholdLabel.Layout.Row = 9;

            obj.SliderBlockSize = uislider(controlLayout, ...
                'Limits', [differenceEstimationFunctions.value_range_blockSize(1), differenceEstimationFunctions.value_range_blockSize(end)], ...
                'Value', 1, ... %roundNiceTicks(differenceEstimationFunctions.value_range_blockSize(1), differenceEstimationFunctions.value_range_blockSize(end), 1000), ...
                'Tooltip', 'Adjust block size for processing');
            obj.SliderBlockSize.Layout.Row = 12;

            obj.BlocksizeLabel = uilabel(controlLayout, ...
                'Text', 'Blocksize');
            obj.BlocksizeLabel.Layout.Row = 11;

            obj.SliderAreaMin = uislider(controlLayout, ...
                'Limits', [differenceEstimationFunctions.value_range_areaMin(1), differenceEstimationFunctions.value_range_areaMin(end)], ...
                'Value', 1, ... %roundNiceTicks(differenceEstimationFunctions.value_range_areaMin(1), differenceEstimationFunctions.value_range_areaMin(end), 1000), ...
                'Tooltip', 'Minimum area for overlay');
            obj.SliderAreaMin.Layout.Row = 14;

            obj.AreaMinLabel = uilabel(controlLayout, ...
                'Text', 'Min Area');
            obj.AreaMinLabel.Layout.Row = 13;

            obj.SliderAreaMax = uislider(controlLayout, ...
                'Limits', [differenceEstimationFunctions.value_range_areaMax(1), differenceEstimationFunctions.value_range_areaMax(end)], ...
                'Value', 1, ... %roundNiceTicks(differenceEstimationFunctions.value_range_areaMax(1), differenceEstimationFunctions.value_range_areaMax(end), 1000), ...
                'Tooltip', 'Maximum area for overlay');
            obj.SliderAreaMax.Layout.Row = 16;

            obj.AreaMaxLabel = uilabel(controlLayout, ...
                'Text', 'Max Area');
            obj.AreaMaxLabel.Layout.Row = 15;
            
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
            obj.updateGroups(obj.App.OverlayClass.groups);
        
            % Clear old checkboxes from UI and memory
            delete(obj.CheckboxGrid.Children);
            obj.Checkboxes = matlab.ui.control.CheckBox.empty;
        
            imageArray = obj.App.OverlayClass.imageArray;
            n = length(imageArray);
        
            % One row per checkbox
            obj.CheckboxGrid.RowHeight = repmat({'fit'}, 1, n);

            % Default: nothing was calculated
            calculatedIdxs = [];
        
            if ~isempty(obj.App.OverlayClass.lastIndices)
                calculatedIdxs = obj.App.OverlayClass.lastIndices;
            end

            disp(n)
        
            for i = 1:n
                dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                isChecked = ismember(i, calculatedIdxs);
                cb = uicheckbox(obj.CheckboxGrid, ...
                    'Text', dateStr, ...
                    'Value', false, ...
                    'ValueChangedFcn', @(src, evt) obj.onCheckboxChanged(i));
                % Set font color depending on previous use
                if isChecked
                    cb.FontColor = [0, 1, 0];  % green if used in last calculation
                    cb.Enable = true;
                else
                    cb.FontColor = [1, 1, 1];  % White otherwise
                    cb.Enable = false;
                end
                obj.Checkboxes(i) = cb;
            end

        end
        

        function reset(obj)
       
            % Clear axes
            cla(obj.Axes);           

        end


        function calculate(obj)            
            selectedIndices = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            if length(selectedIndices) < 2
                uialert(obj.App.UIFigure, 'Please select at least two images.', 'Not enough images');
                return;
            end

            % Retrieve values from UI elements
            method = obj.MethodDropDown.Value;
            threshold = obj.SliderThreshold.Value;
            blockSize = obj.SliderBlockSize.Value;
            areaMin = obj.SliderAreaMin.Value;
            areaMax = obj.SliderAreaMax.Value;

            obj.App.DifferenceClass.calculate(selectedIndices, method, threshold, blockSize, areaMin, areaMax);

            % update checkboxes to reflect indices
            for i = 1:length(obj.Checkboxes)
                if ismember(i, selectedIndices)
                    obj.Checkboxes(i).FontColor = [0, 1, 0];  % Blue
                else
                    obj.Checkboxes(i).FontColor = [1, 1, 1];  % Black (default)
                end
            end

            mask = obj.App.DifferenceClass.getMask(1);

            overlay = obj.App.OverlayClass.createOverlay(selectedIndices(1:2));
            % obj.createBoundaryOverlay(obj.Axes, overlay, mask);
            obj.createTranspOverlay(obj.Axes, overlay, mask);   

        end
    end

    methods (Access = private)
        function clearCheckboxes(obj)
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).Value = false;
                obj.onCheckboxChanged();
            end
        end

        function createBoundaryOverlay(~, parent, overlay, mask)
            imshow(overlay, 'Parent', parent);
            hold(parent, 'on') % hold on for the correct axes
            
            boundaries = bwboundaries(mask);
            for k = 1:length(boundaries)
                b = boundaries{k};
                plot(parent, b(:,2), b(:,1), 'r', 'LineWidth', 1.5); % explicitly plot into obj.Axes
            end
            
            title(parent, 'Outlined difference regions') % assign title to the same axes
        end

        function createTranspOverlay(~, parent, overlay, mask)
            % Display the base image
            imshow(overlay, 'Parent', parent);
            hold(parent, 'on');
            
            % Create a red-colored mask image (same size as overlay)
            redMask = zeros(size(overlay), 'like', overlay); % same type and size
            redMask(:,:,1) = 255; % full red
            
            % Show the red mask with transparency defined by binary mask
            h = imshow(redMask, 'Parent', parent);
            set(h, 'AlphaData', 0.4 * double(mask)); % transparency mask
        end

        function onCheckboxChanged(obj, idx)
            % % Only proceed if we have valid previous data
            % if isempty(obj.App.DifferenceClass.lastIndices) || ~ismember(idx, obj.App.DifferenceClass.lastIndices)
            %     % Revert the current checkbox selection
            %     obj.Checkboxes(idx).Value = false;
            % 
            %     % Show warning
            %     uialert(obj.App.UIFigure, ...
            %         'No data for the selected index.', ...
            %         'No data');          
            %     return;
            % end
            
            % Get current checkbox states
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));
            
            % Enforce max 2 selections
            % if numel(selected) > 2
            %     % Revert the current checkbox selection
            %     obj.Checkboxes(idx).Value = false;
            % 
            %     % Show warning
            %     uialert(obj.App.UIFigure, ...
            %         'You can only select up to two images.', ...
            %         'Selection Limit');
            %     return;
            % end

            % Keep only those that were used in last calculation
            validSelection = intersect(selected, obj.App.OverlayClass.lastIndices);
            
            overlay = obj.App.OverlayClass.createOverlay(validSelection);  
            if ~isempty(overlay)
                imshow(overlay, 'Parent', obj.Axes);
            else
                cla(obj.Axes);  % Clear if overlay couldn't be created
            end
        end
        function updateGroups(obj, groups)
            % groups: cell array of vectors with indices of items in each group
            
            numGroups = numel(groups);
            groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);
            
            % Update dropdown items
            obj.GroupDropdown.Items = [{'All'}, groupNames];      
            
            % Attach callback for dropdown selection change
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupSelected();
        end
        function onGroupSelected(obj)
            if isempty(obj.App.OverlayClass.groups)
                return
            end
            selectedGroupName = obj.GroupDropdown.Value;
            if selectedGroupName == 'All'
                % Loop through all checkboxes in the grid and update selection
                for k = 1:numel(obj.Checkboxes)
                    lastIndices = obj.App.OverlayClass.lastIndices;
                    if ismember(k, lastIndices)
                        obj.Checkboxes(k).Value = false;
                        obj.Checkboxes(k).Enable = 'on';
                        obj.onCheckboxChanged();
                    end
                end
            else
                selectedGroupIndex = str2double(selectedGroupName);
                
                % Get indices of items in selected group
                groupIndices = obj.App.OverlayClass.groups{selectedGroupIndex};
            
                % Loop through all checkboxes in the grid and update selection
                for k = 1:numel(obj.Checkboxes)
                    if ismember(k, groupIndices)
                        obj.Checkboxes(k).Value = false;
                        obj.Checkboxes(k).Enable = 'on';
                        obj.onCheckboxChanged();
                    else
                        obj.Checkboxes(k).Value = false;
                        obj.Checkboxes(k).Enable = 'off';
                        obj.onCheckboxChanged();
                    end
                end
            end
        end
    end

    methods (Static)
        function name = getName()
            name = 'Difference';
        end
    end
end