classdef OverlayView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable

        Grid            matlab.ui.container.GridLayout
        Axes            matlab.ui.control.UIAxes
        HeatmapPanel    matlab.ui.container.Panel
        CheckboxGrid    matlab.ui.container.GridLayout
        Checkboxes      matlab.ui.control.CheckBox
        CalculateButton matlab.ui.control.Button
        ClearButton     matlab.ui.control.Button
        AllButton       matlab.ui.control.Button
        MethodDropdown matlab.ui.control.DropDown
        StatusTextArea
    end

    methods
        % Constructor
        function obj = OverlayView(app)
            addpath(fullfile(pwd, '..'));
            addpath(fullfile(pwd, 'src/overlay'));
            
            obj.App = app;
            obj.dataAvailable = false;
        
            % Create main layout
            obj.Grid = uigridlayout(app.MainContentPanel, [2, 1]);
            obj.Grid.RowHeight = {'1x'};
            obj.Grid.ColumnWidth = {'1x', '1x', 'fit'};
            obj.Grid.Visible = 'off';
        
            % Create image display area
            obj.Axes = uiaxes(obj.Grid);
            obj.Axes.Layout.Row = 1;
            obj.Axes.Layout.Column = 1;
            obj.Axes.XTick = [];
            obj.Axes.YTick = [];

            % Create a panel to host the heatmap in Grid position (1,2)
            obj.HeatmapPanel = uipanel(obj.Grid);
            obj.HeatmapPanel.Layout.Row = 1;
            obj.HeatmapPanel.Layout.Column = 2;
        
            % Create control panel
            controlPanel = uipanel(obj.Grid);
            controlPanel.Layout.Row = 1;
            controlPanel.Layout.Column = 3;
        
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
            obj.MethodDropdown = uidropdown(controlLayout, ...
                'Items', {'succesive', 'graph'}, ...
                'Value', 'succesive', ...
                'Tooltip', 'Select algorithm');
            obj.MethodDropdown.Layout.Row = 4;  % Adjust rows below accordingly
        
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
        function printStatus(obj, fmt, varargin)
            % Format the string just like fprintf
            newLine = sprintf(fmt, varargin{:});
        
            % Append to current lines
            oldLines = obj.StatusTextArea.Value;
        
            % Ensure it's a cell array of strings
            if ischar(oldLines)
                oldLines = cellstr(oldLines);
            end
        
            % Append new line
            obj.StatusTextArea.Value = [oldLines; newLine];
        
            % Scroll to bottom
            drawnow;  % Ensure UI updates immediately
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
            selectedIndices = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            if length(selectedIndices) < 2
                uialert(obj.App.UIFigure, 'Please select at least two images.', 'Not enough images');
                return;
            end

            method = obj.MethodDropdown.Value;

            obj.CalculateButton.Text = 'Calculating...';
            obj.CalculateButton.Enable = 'off';            
            delete(obj.HeatmapPanel.Children);
            obj.StatusTextArea = uitextarea(obj.Grid, ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'Value', {'Status output will appear here...'});
            obj.StatusTextArea.Layout.Column = 2;
            obj.StatusTextArea.Layout.Row = 1;
            drawnow;  % Force UI update

            obj.App.OverlayClass.calculate(selectedIndices, method, @obj.printStatus);

            obj.CalculateButton.Text = 'Calculate Overlay';
            obj.CalculateButton.Enable = 'on';
            delete(obj.StatusTextArea)


            % update checkboxes to reflect indices
            for i = 1:length(obj.Checkboxes)
                if ismember(i, selectedIndices)
                    obj.Checkboxes(i).FontColor = [0, 1, 0];  % Blue
                else
                    obj.Checkboxes(i).FontColor = [1, 1, 1];  % Black (default)
                end
            end            

            scoreMatrix = obj.App.OverlayClass.createScoreConfusion();
            delete(obj.HeatmapPanel.Children);
            h = heatmap(obj.HeatmapPanel, scoreMatrix, ...
            'MissingDataLabel', '', ...
            'MissingDataColor', [0.8, 0.8, 0.8], ...  % Light gray for NaN
            'Colormap', copper, ...
            'ColorLimits', [min(scoreMatrix(:), [], 'omitnan'), ...
                            max(scoreMatrix(:), [], 'omitnan')]);
            disp(obj.App.OverlayClass.lastIndices);
            dates = arrayfun(@(i) obj.App.OverlayClass.imageArray{i}.id, obj.App.OverlayClass.lastIndices);  % Extract datetime
            dateLabels = cellstr(datestr(dates, 'yyyy-mm'));        % Format to string
            % Only show X-axis labels, hide Y-axis labels
            h.XDisplayLabels = dateLabels;
            h.YDisplayLabels = dateLabels;  % empty Y labels

            overlay = obj.App.OverlayClass.createOverlay(selectedIndices);

            imshow(overlay, 'Parent', obj.Axes);
   
        end

        function onCheckboxChanged(obj, idx)
            % Only proceed if we have valid previous data
            if isempty(obj.App.OverlayClass.lastIndices)
                return;
            end
            if ~ismember(idx, obj.App.OverlayClass.lastIndices)
                return;
            end
            
            % Get current checkbox states
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));
            
            % Keep only those that were used in last calculation
            validSelection = intersect(selected, obj.App.OverlayClass.lastIndices);
            
            overlay = obj.App.OverlayClass.createOverlay(validSelection);  
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