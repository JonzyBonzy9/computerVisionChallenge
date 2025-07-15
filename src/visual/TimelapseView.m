classdef TimelapseView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        Grid          matlab.ui.container.GridLayout
        Grid2         matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        SliderGrid    matlab.ui.container.GridLayout
        SliderLabel   matlab.ui.control.Label
        Slider        matlab.ui.control.Slider
        GaussSlider   matlab.ui.control.Slider
        imCheck matlab.ui.control.CheckBox
        period
        sliderIntervals
        lastBlended
        currDates
        controlPanel
        GroupDropdown
        ApplyGroupButton
        playbackTimer 
        startButton
        sigma
        group = 1;
    end

    methods
        % Constructor
        function obj = TimelapseView(app)
            obj.App = app;

            % set speed
            obj.period = 2; % this makes it slower for larger values and vice versa
            obj.sliderIntervals = 3; % this makes it smoother for larger values and vice versa

            % set currDates to []
            obj.currDates = [];

            % Create Panel 1 Grid layout
            obj.Grid = uigridlayout(app.MainContentPanel);
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.RowHeight = {'1x', 60};
            obj.Grid.Visible = 'off';

            % Create Grid for axes and control
            obj.Grid2 = uigridlayout(obj.Grid);
            obj.Grid2.ColumnWidth = {'1x', 'fit'};
            obj.Grid2.RowHeight = {'1x'};
            obj.Grid2.Layout.Row = 1;


            % Create Image
            obj.Axes = uiaxes(obj.Grid2);
            obj.Axes.Layout.Column = 1;
            obj.Axes.Layout.Row = 1;
            obj.Axes.XTick = [];
            obj.Axes.YTick = [];

            % Create Slider Grid
            obj.SliderGrid = uigridlayout(obj.Grid);
            obj.SliderGrid.ColumnWidth = {60, '1x'};
            obj.SliderGrid.RowHeight = {'1x'};
            obj.SliderGrid.Layout.Row = 2;
            obj.SliderGrid.Layout.Column = 1;

            % Create SliderLabel
            obj.SliderLabel = uilabel(obj.SliderGrid);
            obj.SliderLabel.HorizontalAlignment = 'right';
            obj.SliderLabel.Layout.Row = 1;
            obj.SliderLabel.Layout.Column = 1;
            obj.SliderLabel.Text = 'Slider';

            % Create Slider
            obj.Slider = uislider(obj.SliderGrid);
            obj.Slider.Layout.Row = 1;
            obj.Slider.Layout.Column = 2;
            obj.Slider.ValueChangedFcn = @(src,event) obj.blendImages();

            % Create control panel
            obj.controlPanel = uipanel(obj.Grid2);
            obj.controlPanel.Scrollable = 'on';
            obj.controlPanel.Layout.Row = 1;
            obj.controlPanel.Layout.Column = 2;

            controlLayout = uigridlayout(obj.controlPanel);
            controlLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit','fit'};
            controlLayout.ColumnWidth = {'1x'};

            lbl = uilabel(controlLayout, 'Text', 'Select Group:');
            lbl.Layout.Row = 1;

            obj.GroupDropdown = uidropdown(controlLayout, ...
                'Items', {'Select a group'}, ...
                'Tooltip', 'Select a group');
            obj.GroupDropdown.Layout.Row = 2;

            lbl = uilabel(controlLayout, 'Text', "Select display:");
            lbl.Layout.Row = 5;

            % Start Button
            obj.startButton = uibutton(controlLayout, 'Text', 'Start', ...
                'ButtonPushedFcn', @(btn,event) obj.startPlayback());
            obj.startButton.Layout.Row = 8;
            
            % Stop Button
            stopButton = uibutton(controlLayout, 'Text', 'Stop', ...
                'ButtonPushedFcn', @(btn,event) obj.stopPlayback());
            stopButton.Layout.Row = 9;
            
            % reset button
            ResetButton = uibutton(controlLayout, 'push', ...
                'Text', 'Reset', ...
                'ButtonPushedFcn', @(btn, evt)obj.resetView());
            ResetButton.Layout.Row = 10;  

        end

        function onImLoad(obj)
            obj.updateGroups([]);
        end

        function show(obj)
            obj.Grid.Visible = 'on';
            obj.updateGroups(obj.App.OverlayClass.groups);
            obj.updateSlider()
        end

        function hide(obj)
            obj.Grid.Visible = 'off';    
            obj.resetView();
        end

        function update(obj)
        end
    end
        
    methods (Access = private)
        function resetView(obj)
            obj.stopPlayback();
            cla(obj.Axes);        % Clear the axes content
            obj.updateSlider();   % Call the updateSlider method
        end


        function startPlayback(obj)
            
            if strcmp(obj.GroupDropdown.Value, 'Select a group')
                uialert(obj.App.UIFigure, ...
                    'Please select a valid group before starting playback.', ...
                    'No Group Selected', ...
                    'Icon', 'warning');
                return;
            end
            

            if ~obj.App.OverlayClass.resultAvailable
                % if not, give user error
                uialert(obj.App.UIFigure, ...
                    'No data available! Calculate Overlay first', 'No Data');     
                return;
            end

        
            if isempty(obj.playbackTimer) || ~isvalid(obj.playbackTimer)
                obj.playbackTimer = timer( ...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', obj.period, ...
                    'TimerFcn', @(~,~) obj.advanceSlider());
            end
            start(obj.playbackTimer);
            obj.Slider.Enable = 'off';
        end

        
        function stopPlayback(obj)
            if ~isempty(obj.playbackTimer) && isvalid(obj.playbackTimer)
                stop(obj.playbackTimer);
            end
            obj.Slider.Enable = 'on';

        end
        function delete(obj)
            obj.stopPlayback();
            if ~isempty(obj.playbackTimer) && isvalid(obj.playbackTimer)
                delete(obj.playbackTimer);
            end
        end

        function advanceSlider(obj)
            if strcmp(obj.GroupDropdown.Value, 'Select a group')
                return;
            end

            N = numel(obj.App.OverlayClass.groups{obj.group});
        
            if N <= 1
                obj.stopPlayback();
                uialert(obj.App.UIFigure, ...
                    'Only one image is available in this group. Playback requires at least two images.', ...
                    'Playback Not Possible', ...
                    'Icon', 'warning');
                return;
            end
        
            currentValue = obj.Slider.Value;
            if currentValue < obj.Slider.Limits(2)
                val = currentValue + 1/obj.sliderIntervals;
                obj.Slider.Value = val;
                obj.blendImages();
            else
                obj.stopPlayback();
            end
        end


        
        function blendImages(obj)
            val = obj.Slider.Value;
        
            lowerInt = floor(val);
            upperInt = ceil(val);
        
            % Get image stack for the current group (assume images are already in double format)
            images = obj.App.OverlayClass.imageStack{obj.group};  % 4D: H x W x C x N
            numImages = size(images, 4);
        
            % Clamp lower and upper to valid range
            lowerInt = max(1, lowerInt);
            upperInt = min(numImages, upperInt);
            
            % Calculate blending weight between 0 and 1
            alpha = abs(val - lowerInt);  % Fractional part for blending
        
            % Precompute images if possible (avoid redundant image extraction)
            if lowerInt == upperInt
                % If exactly at an integer, no blending needed
                blended = double(images(:,:,:,lowerInt));
            else
                % Extract images once and reuse them for blending
                image1 = double(images(:,:,:,lowerInt));
                image2 = double(images(:,:,:,upperInt));
        
                % Blend images: weighted sum
                blended = (1 - alpha) * image1 + alpha * image2;
            end
        
            % Show the blended image on the axes (only do this once per frame)
            obj.Axes.Visible = 'on';
            % Update the image only if it's different from the last one
            if ~isequal(obj.lastBlended, blended)
                imshow(uint8(blended * 255), 'Parent', obj.Axes);
                obj.lastBlended = blended;  % Cache the last blended image
            end
        end


        function updateSlider(obj)
            if ~obj.App.OverlayClass.resultAvailable
                return;
            else
                if strcmp(obj.GroupDropdown.Value, 'Select a group')
                    % No valid group selected, skip or show alert
                    return;
                end
                indices = obj.App.OverlayClass.groups{obj.group};
            end
        
            N = length(indices);
            % Only update slider if N>0
            if N > 1
                dates = cellfun(@(s) string(s.id), obj.App.OverlayClass.imageArray(indices));
                obj.currDates = dates;
                obj.Slider.Limits = [.5, N+.5];
                ticks = 1:N;
                obj.Slider.MajorTicks = ticks;
                obj.Slider.MajorTickLabels = dates;
                obj.Slider.Value = 0.5;
            else
                % Handle empty case: maybe disable slider or set default limits
                obj.Slider.Limits = [0, 1];
                obj.Slider.MajorTicks = [0.5];
                obj.Slider.MajorTickLabels = ["None","None"];
                obj.Slider.Value = 0;
            end
        end

        function updateGroups(obj, groups)
        
            numGroups = numel(groups);
            
            if numGroups>=1
                groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);
                
                % Update dropdown items
                obj.GroupDropdown.Items = [{'Select a group'}, groupNames];
            else
                obj.GroupDropdown.Items = [{'Select a group'}];
            end

            % Attach callback for manual selection
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupSelected();
        end

        function onGroupSelected(obj)
            obj.resetView();
            selected = obj.GroupDropdown.Value;
            if strcmp(selected, 'Select a group')
                return; % Do nothing
            end
            obj.group = str2double(selected);
            obj.updateSlider()
        end

        function updateSigma(obj)
            % Convert log slider value back to σ
            obj.sigma = 10^(obj.GaussSlider.Value);

            % Now use sigma in your blending function
            obj.blendImages()
        end
    end

    methods (Static)
        function name = getName()
            name = 'Timelapse';
        end
    end
end