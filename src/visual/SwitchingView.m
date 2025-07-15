classdef SwitchingView < handle
    properties (Access = private)
        App             matlab.apps.AppBase

        Grid            matlab.ui.container.GridLayout
        Axes            matlab.ui.control.UIAxes
        CheckboxGrid    matlab.ui.container.GridLayout
        Checkboxes      matlab.ui.control.CheckBox
        StartButton     matlab.ui.control.Button
        StopButton      matlab.ui.control.Button
        
        timerObj        timer
        currentIndex    double = 1;
        selectedIndices double = [];
        
        colors          = {[1 0 0], [0 0.7 1]}; % Red and Blue for outlines
    end
    
    methods
        function obj = SwitchingView(app)
            obj.App = app;
            
            % Create grid layout 2 rows (axes + controls)
            obj.Grid = uigridlayout(app.MainContentPanel, [3,1]);
            obj.Grid.RowHeight = {'1x','fit','fit'};
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.Visible = 'off';
            
            % UIAxes for image display
            obj.Axes = uiaxes(obj.Grid);
            obj.Axes.Layout.Row = 1;
            obj.Axes.Layout.Column = 1;
            obj.Axes.XTick = [];
            obj.Axes.YTick = [];
            obj.Axes.Toolbar.Visible = 'off';
            axis(obj.Axes, 'image');
            obj.Axes.Visible = 'off';
            
            % CheckboxGrid for selecting images
            obj.CheckboxGrid = uigridlayout(obj.Grid);
            obj.CheckboxGrid.Layout.Row = 2;
            obj.CheckboxGrid.Layout.Column = 1;
            obj.CheckboxGrid.RowSpacing = 2;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            
            % Buttons panel for start/stop
            btnPanel = uipanel(obj.Grid);
            btnPanel.Layout.Row = 3;
            btnPanel.Layout.Column = 1;
            btnGrid = uigridlayout(btnPanel, [1,3]);
            btnGrid.ColumnWidth = {'1x', '1x', '1x'};
            
            % Start Button
            obj.StartButton = uibutton(btnGrid, 'push', ...
                'Text', 'Start Switching', ...
                'ButtonPushedFcn', @(~,~) obj.startSwitching());
            obj.StartButton.Layout.Column = 1;
            
            % Stop Button
            obj.StopButton = uibutton(btnGrid, 'push', ...
                'Text', 'Stop', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.stopSwitching());
            obj.StopButton.Layout.Column = 2;
            
            % Legend (static label and colored patches)
            legendPanel = uipanel(btnGrid);
            legendPanel.Title = 'Legend';
            legendPanel.Layout.Column = 3;
            legendLayout = uigridlayout(legendPanel, [2,2]);
            legendLayout.RowHeight = {'fit','fit'};
            legendLayout.ColumnWidth = {'fit','1x'};
            
            % Red patch and label
            rPatch = uilabel(legendLayout, 'BackgroundColor', obj.colors{1}, 'Text', '');
            rPatch.Layout.Row = 1; rPatch.Layout.Column = 1;
            rPatch.Tooltip = 'First selected image';
            
            rLabel = uilabel(legendLayout, 'Text', 'Image 1');
            rLabel.Layout.Row = 1; rLabel.Layout.Column = 2;
            
            % Blue patch and label
            bPatch = uilabel(legendLayout, 'BackgroundColor', obj.colors{2}, 'Text', '');
            bPatch.Layout.Row = 2; bPatch.Layout.Column = 1;
            bPatch.Tooltip = 'Second selected image';
            
            bLabel = uilabel(legendLayout, 'Text', 'Image 2');
            bLabel.Layout.Row = 2; bLabel.Layout.Column = 2;
            
            % Initialize timer for switching
            obj.timerObj = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.3, ... % 0.3 seconds
                'TimerFcn', @(~,~) obj.timerTick());
        end
        
        function show(obj)
            obj.Grid.Visible = 'on';
            obj.Axes.Visible = 'on';
        end
        
        function hide(obj)
            obj.Grid.Visible = 'off';
            obj.stopSwitching();
        end
       function onImLoad(obj)
        end
        
        function updateCheckboxes(obj)
            % Clear old checkboxes
            delete(obj.CheckboxGrid.Children);
            obj.Checkboxes = matlab.ui.control.CheckBox.empty;
            
            imageArray = obj.App.OverlayClass.imageArray;
            n = length(imageArray);
            
            obj.CheckboxGrid.RowHeight = repmat({'fit'},1,n);
            
            for i = 1:n
                dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                cb = uicheckbox(obj.CheckboxGrid, ...
                    'Text', dateStr, ...
                    'ValueChangedFcn', @(src, evt) obj.onCheckboxChanged());
                cb.Layout.Row = i;
                obj.Checkboxes(i) = cb;
                % Initially no colors
                cb.FontColor = [0 0 0];
            end
        end
        
        function onCheckboxChanged(obj)
            % Limit selection to max 2
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));
            if length(selected) > 2
                % Undo last change by setting last checkbox false
                evt = obj.App.UIFigure.CurrentObject;
                if isa(evt, 'matlab.ui.control.CheckBox')
                    evt.Value = false;
                end
                uialert(obj.App.UIFigure, 'Select at most two images.', 'Selection Limit');
                return;
            end
            
            % Update font colors to show selection order
            for i = 1:length(obj.Checkboxes)
                obj.Checkboxes(i).FontColor = [0 0 0];
            end
            for idx = 1:length(selected)
                obj.Checkboxes(selected(idx)).FontColor = obj.colors{idx};
            end
            
            obj.selectedIndices = selected;
        end
        
        function startSwitching(obj)
            if length(obj.selectedIndices) ~= 2
                uialert(obj.App.UIFigure, 'Please select exactly two images to start switching.', 'Selection Error');
                return;
            end
            
            obj.currentIndex = 1;
            obj.StartButton.Enable = 'off';
            obj.StopButton.Enable = 'on';
            obj.timerObj.StartDelay = 0;
            start(obj.timerObj);
        end
        
        function stopSwitching(obj)
            if strcmp(obj.timerObj.Running, 'on')
                stop(obj.timerObj);
            end
            obj.StartButton.Enable = 'on';
            obj.StopButton.Enable = 'off';
            cla(obj.Axes);
        end
    end
    
    methods (Access = private)
        function timerTick(obj)
            idx = obj.selectedIndices(obj.currentIndex);
            img = obj.App.OverlayClass.imageArray{idx}.data;
            
            % Convert grayscale to RGB if needed
            if size(img,3) == 1
                img = repmat(img,1,1,3);
            end
            
            imshow(img, 'Parent', obj.Axes);
            
            % Outline axes with selected color
            color = obj.colors{obj.currentIndex};
            obj.Axes.XColor = color;
            obj.Axes.YColor = color;
            obj.Axes.LineWidth = 3;
            
            % Alternate index
            obj.currentIndex = 3 - obj.currentIndex; % toggles between 1 and 2
        end
    end
    
    methods (Static)
        function name = getName()
            name = 'Switching';
        end
    end
end
