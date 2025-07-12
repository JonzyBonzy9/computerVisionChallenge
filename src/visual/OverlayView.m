classdef OverlayView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable

        Grid            matlab.ui.container.GridLayout
        Axes            matlab.ui.control.UIAxes
        GraphAxes            matlab.ui.control.UIAxes
        HeatmapPanel
        CheckboxGrid    matlab.ui.container.GridLayout
        Checkboxes      matlab.ui.control.CheckBox
        CalculateButton matlab.ui.control.Button
        ClearButton     matlab.ui.control.Button
        AllButton       matlab.ui.control.Button
        MethodDropdown  matlab.ui.control.DropDown
        StatusTextArea
        GroupDropdown   matlab.ui.control.DropDown
        controlPanel
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
            tabGroup = uitabgroup(obj.Grid);
            tabGroup.Layout.Row = 1;
            tabGroup.Layout.Column = 2;

            % Create tabs
            consoleTab = uitab(tabGroup, 'Title', 'Console');
            matrixTab  = uitab(tabGroup, 'Title', 'Confusion Matrix');
            graphTab   = uitab(tabGroup, 'Title', 'Graph');

            % Store panels or axes for later use
            obj.StatusTextArea = uitextarea(consoleTab, ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'Value', {'Load image folder, select the desired images and press Calculate Overlay to align the images to each other.', 'Console Output will appear here...' }); 
            
            % Use a placeholder for the graph view for now
            obj.GraphAxes = uiaxes(graphTab);
            obj.GraphAxes.XTick = [];
            obj.GraphAxes.YTick = [];
             
            % Store reference to matrixTab (if needed)
            obj.HeatmapPanel = matrixTab;  % reuse the existing property

            % Create control panel
            obj.controlPanel = uipanel(obj.Grid);
            obj.controlPanel.Scrollable = 'on';
            obj.controlPanel.Layout.Row = 1;
            obj.controlPanel.Layout.Column = 3;
        
            controlLayout = uigridlayout(obj.controlPanel);
            controlLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            controlLayout.ColumnWidth = {'1x'};
            
            lbl = uilabel(controlLayout, 'Text', 'Select Group:');
            lbl.Layout.Row = 1;

            groupLayout = uigridlayout(controlLayout);
            groupLayout.ColumnWidth = {'1x', '1x'};
            groupLayout.RowHeight = {'1x'};
            groupLayout.Layout.Row = 2;
            
            obj.GroupDropdown = uidropdown(groupLayout, ...
                'Items', {'All'}, ...               % initially empty
                'Tooltip', 'Select a group');
            obj.GroupDropdown.Layout.Column = 1;
            
            lbl = uilabel(controlLayout, 'Text', 'Select Items:');
            lbl.Layout.Row = 3;
            
            obj.CheckboxGrid = uigridlayout(controlLayout);
            obj.CheckboxGrid.Layout.Row = 4;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            obj.CheckboxGrid.RowSpacing = 2;
            
            % Clear and Select All buttons with labels (row 5 and 6)
            obj.ClearButton = uibutton(controlLayout, 'push', ...
                'Text', 'Clear All', ...
                'FontColor', 'red', ...
                'Tooltip', 'Deselect all items', ...
                'ButtonPushedFcn', @(btn, evt)obj.clearCheckboxes());
            obj.ClearButton.Layout.Row = 5;
            
            obj.AllButton = uibutton(controlLayout, 'push', ...
                'Text', 'Select All', ...
                'FontColor', 'green', ...
                'Tooltip', 'Select all items', ...
                'ButtonPushedFcn', @(btn, evt)obj.allCheckboxes());
            obj.AllButton.Layout.Row = 6;
            
            % Method selection label and dropdown (row 7 and 8)
            lbl = uilabel(controlLayout, 'Text', 'Select Algorithm:');
            lbl.Layout.Row = 7;
            
            obj.MethodDropdown = uidropdown(controlLayout, ...
                'Items', {'graph', 'successive'}, ...
                'Value', 'graph', ...
                'Tooltip', 'Select algorithm');
            obj.MethodDropdown.Layout.Row = 8;
            
            % Calculate button (row 9)
            obj.CalculateButton = uibutton(controlLayout, 'push', ...
                'Text', 'Calculate Overlay', ...
                'ButtonPushedFcn', @(btn, evt)obj.calculate());
            obj.CalculateButton.Layout.Row = 10;



        end

        function onImLoad(obj)
            % Update panel
            obj.dataAvailable = true;
            obj.controlPanel.Scrollable = 'off';
            obj.controlPanel.Scrollable = 'on';  % Toggle to re-check scroll need
            imshow(obj.App.OverlayClass.imageArray{1}.data, 'Parent', obj.Axes);
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
        
            for i = 1:n
                dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                isChecked = ismember(i, calculatedIdxs);
                cb = uicheckbox(obj.CheckboxGrid, ...
                    'Text', dateStr, ...
                    'Value', true, ...
                    'ValueChangedFcn', @(src, evt) obj.onCheckboxChanged());
                % Set font color depending on previous use
                if isChecked
                    cb.FontColor = [0, 1, 0];  % green if used in last calculation
                else
                    cb.FontColor = [1, 1, 1];  % Black otherwise
                end
                obj.Checkboxes(i) = cb;
            end
            obj.onCheckboxChanged();

        end

        function reset(obj)
            % Reset the overlay view UI and state
        
            % Clear console
            obj.StatusTextArea.Value= {'Load image folder, select the desired images and press Calculate Overlay to align the images to each other.', 'Console Output will appear here...' }; 

        
            % Clear axes
            cla(obj.Axes);
            cla(obj.GraphAxes);
        
            obj.MethodDropdown.Value = 'graph';
        
            % Delete existing checkboxes
            if isvalid(obj.CheckboxGrid)
                delete(allchild(obj.CheckboxGrid));
            end
            
            % TODO: reset confusion matrix, low priority

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

        function calculate(obj)            
            selectedIndices = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            if length(selectedIndices) < 2
                uialert(obj.App.UIFigure, 'Please select at least two images.', 'Not enough images');
                return;
            end

            method = obj.MethodDropdown.Value;

            obj.CalculateButton.Text = 'Calculating...';
            obj.CalculateButton.Enable = 'off';
            obj.StatusTextArea.Value = "";

            drawnow;  % Force UI update

            obj.App.OverlayClass.calculate(selectedIndices, method, @obj.printStatus);

            obj.CalculateButton.Text = 'Calculate Overlay';
            obj.CalculateButton.Enable = 'on';

            % update checkboxes to reflect indices
            for i = 1:length(obj.Checkboxes)
                if ismember(i, selectedIndices)
                    obj.Checkboxes(i).FontColor = [0, 1, 0];  % Green
                    obj.Checkboxes(i).Value = true;
                else
                    obj.Checkboxes(i).FontColor = [1, 1, 1];  % White
                    obj.Checkboxes(i).Value = false;
                end
            end         
            obj.onCheckboxChanged();
            
            % get scorematrix
            scoreMatrix = obj.App.OverlayClass.createScoreConfusion();
            
            h = heatmap(obj.HeatmapPanel, scoreMatrix, ...
                'MissingDataLabel', '', ...
                'MissingDataColor', [0.8, 0.8, 0.8], ...
                'Colormap', copper);
            dates = arrayfun(@(i) obj.App.OverlayClass.imageArray{i}.id, obj.App.OverlayClass.lastIndices);  % Extract datetime
            dateLabels = cellstr(datestr(dates, 'yyyy-mm'));        % Format to string
            % Only show X-axis labels, hide Y-axis labels
            h.XDisplayLabels = dateLabels;
            h.YDisplayLabels = dateLabels;  % empty Y labels

            overlay = obj.App.OverlayClass.createOverlay(selectedIndices);

            imshow(overlay, 'Parent', obj.Axes);

            % --- Graph display ---
            obj.App.OverlayClass.plotReachabilityGraph(obj.GraphAxes);

            % --- update Groups ---
            obj.updateGroups(obj.App.OverlayClass.groups);
            
            % --- Update exterior button, now differences can be calculated
            obj.App.CalculateDifferencesButton.Text = "Calculate Differences";
            obj.App.CalculateDifferencesButton.Enable = 'on';   
        end
    end    

    methods (Access = private)
        function clearCheckboxes(obj)
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).Value = false;
            end
            obj.onCheckboxChanged();  % manually trigger visualization update

        end
        function allCheckboxes(obj)
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).Value = true;
            end
            obj.onCheckboxChanged();  % manually trigger visualization update

        end        

        function onCheckboxChanged(obj)

            % Get current checkbox states
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            overlay = obj.App.OverlayClass.createOverlay(selected);  
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
                    obj.Checkboxes(k).Enable = 'on';
                    lastIndices = obj.App.OverlayClass.lastIndices;
                    if ismember(k, lastIndices)
                        obj.Checkboxes(k).Value = true;
                    end
                end
            else
                selectedGroupIndex = str2double(selectedGroupName);
                
                % Get indices of items in selected group
                groupIndices = obj.App.OverlayClass.groups{selectedGroupIndex};
            
                % Loop through all checkboxes in the grid and update selection
                for k = 1:numel(obj.Checkboxes)
                    if ismember(k, groupIndices)
                        obj.Checkboxes(k).Value = true;
                        obj.Checkboxes(k).Enable = 'on';
                    else
                        obj.Checkboxes(k).Value = false;
                        obj.Checkboxes(k).Enable = 'off';
                    end
                end
            end
            obj.onCheckboxChanged();
        end
    end

    methods (Static)
        function name = getName()
            name = 'Overlay';
        end        
    end
end