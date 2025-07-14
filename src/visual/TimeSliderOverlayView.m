classdef TimeSliderOverlayView < handle
    properties (Access = private)
        App           matlab.apps.AppBase
        dataAvailable
        Grid          matlab.ui.container.GridLayout
        Grid2         matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        SliderGrid    matlab.ui.container.GridLayout
        SliderLabel   matlab.ui.control.Label
        Slider        matlab.ui.control.Slider
        GaussSlider   matlab.ui.control.Slider
        imCheck       matlab.ui.control.CheckBox
        diffCheck     matlab.ui.control.CheckBox
        controlPanel
        GroupDropdown
        ApplyGroupButton
        imageStack
        maskStack
        sigma
        group = 1;
    end

    methods
        % Constructor
        function obj = TimeSliderOverlayView(app)
            obj.App = app;
            obj.dataAvailable = false;

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
            controlLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            controlLayout.ColumnWidth = {'1x'};

            lbl = uilabel(controlLayout, 'Text', 'Select Group:');
            lbl.Layout.Row = 1;

            obj.GroupDropdown = uidropdown(controlLayout, ...
                'Items', {}, ...               % initially empty
                'Tooltip', 'Select a group');
            obj.GroupDropdown.Layout.Row = 2;

            lbl = uilabel(controlLayout, 'Text', "Blend Amount:");
            lbl.Layout.Row = 3;

            obj.GaussSlider = uislider(controlLayout);
            obj.GaussSlider.Layout.Row = 4;
            obj.GaussSlider.Limits = [-1, 0.5];
            obj.GaussSlider.Value = log10(1); % Default 1
            obj.sigma = 1;
            obj.GaussSlider.MajorTicks = [-1, -0.5, 0, 0.5];
            obj.GaussSlider.MajorTickLabels = {'0.1', '0.3', '1', '3'};
            obj.GaussSlider.ValueChangedFcn = @(src,event) obj.updateSigma();

            lbl = uilabel(controlLayout, 'Text', "Select display:");
            lbl.Layout.Row = 5;

            obj.imCheck = uicheckbox(controlLayout);
            obj.imCheck.Text = "Images";
            obj.imCheck.Enable = 'off';
            obj.imCheck.ValueChangedFcn = @(src, event) obj.blendImages();
            obj.imCheck.Layout.Row = 6;

            obj.diffCheck = uicheckbox(controlLayout);
            obj.diffCheck.Text = "Difference";
            obj.diffCheck.Enable = 'off';
            obj.diffCheck.ValueChangedFcn = @(src, event) obj.blendImages();
            obj.diffCheck.Layout.Row = 7;
        end

        function onImLoad(obj)
            % Update panel
            obj.dataAvailable = true;
            obj.imageStack = [];
            obj.maskStack = [];
        end

        function show(obj)
            % Show the main grid
            obj.Grid.Visible = 'on';

            % update view if data is available
            if obj.dataAvailable
                obj.update()
            end
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

        % Update the view
        % This method is called to refresh the view when data changes
        % or when the user interacts with the UI elements.
        function update(obj)

            if obj.App.OverlayClass.resultAvailable
                obj.imCheck.Enable = 'on';
                obj.imCheck.Value = true;  % Enable and check by default
            else
                obj.imCheck.Enable = 'off';
            end
            if obj.App.DifferenceClass.resultAvailable
                obj.diffCheck.Enable = 'on';
                obj.diffCheck.Value = true;  % Enable and check by default
            else
                obj.diffCheck.Enable = 'off';
                obj.diffCheck.Value = false;  % Disable and uncheck
            end
            obj.updateGroups(obj.App.OverlayClass.groups);
            obj.updateSlider()
            obj.blendImages()
        end
    end

    methods (Access = private)
        % Blend images based on the slider value and sigma
        % This method computes a weighted average of the images in the stack
        % based on the slider value and applies a Gaussian weighting.
        function blendImages(obj)
            value = obj.Slider.Value;
            % check whether overlay data is available
            if ~obj.App.OverlayClass.resultAvailable
                % if not, show raw images
                value = round(value);

                imshow(obj.App.OverlayClass.imageArray{value}.data, 'Parent', obj.Axes);
                obj.Slider.Value = value;
            else
                % show warped images
                N = size(obj.App.OverlayClass.imageStack{obj.group}, 4);

                % Compute Gaussian weights centered at slider value
                x = 1:N;
                weights = exp(-0.5 * ((x - value) / obj.sigma).^2);
                weights = weights / sum(weights);  % Normalize

                % Blend images
                empty = zeros(size(obj.App.OverlayClass.imageStack{obj.group},1), size(obj.App.OverlayClass.imageStack{obj.group},2), size(obj.App.OverlayClass.imageStack{obj.group},3), 'like', obj.App.OverlayClass.imageStack{obj.group});

                % Always start by clearing the axes
                cla(obj.Axes);

                % Display blended images first (if checkbox is selected)
                blended = empty;
                if obj.imCheck.Value
                    for i = 1:N
                        blended = blended + weights(i) * obj.App.OverlayClass.imageStack{obj.group}(:,:,:,i);
                    end
                end

                % Overlay the mask on top (if checkbox is selected)
                maskBlended = empty(:,:,1);  % Initialize maskBlended as a single channel
                if obj.diffCheck.Value
                    maskCount = 1;
                    lastMaskIndice = obj.App.DifferenceClass.lastIndices(end);
                    for i = 1:N
                        indice = obj.App.OverlayClass.groups{obj.group}(i);
                        maskIndice = obj.App.DifferenceClass.lastIndices(maskCount);
                        if  maskIndice == indice && ~(maskIndice == lastMaskIndice)
                            maskBlended = maskBlended + weights(i) * obj.App.DifferenceClass.maskStack(:,:,maskCount);
                            maskCount = maskCount + 1;
                        elseif indice < lastMaskIndice && maskCount ~= 1
                            maskBlended = maskBlended + weights(i) * obj.App.DifferenceClass.maskStack(:,:,maskCount-1);
                        else
                            % No mask to add for this image (stays zero)
                        end
                    end
                    [H, W] = size(maskBlended);
                    redOverlay = zeros(H, W, 3);
                    redOverlay(:,:,1) = maskBlended;
                    maskBlended = redOverlay;
                end
                blended = blended + maskBlended;
                imshow(blended, 'Parent', obj.Axes);

                % Display

            end
        end

        % Update the slider based on the current image stack
        % This method sets the slider limits and ticks based on the number of images
        % in the current image stack. It also updates the slider value to the first image.
        function updateSlider(obj)
            if ~obj.App.OverlayClass.resultAvailable
                indices = 1:size(obj.imageStack, 4);
            else
                indices = obj.App.OverlayClass.groups{obj.group};
            end

            dates = cellfun(@(s) string(s.id), obj.App.OverlayClass.imageArray(indices));
            N = length(indices);
            obj.Slider.Limits = [1, N];
            obj.Slider.MajorTicks = 1:N;
            obj.Slider.MajorTickLabels = dates;
            obj.Slider.Value = 1;
        end

        % Update the group dropdown based on the available groups
        function updateGroups(obj, groups)
            % groups: cell array of vectors with indices of items in each group

            numGroups = numel(groups);
            groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);

            % Update dropdown items
            obj.GroupDropdown.Items = groupNames;

            % Attach callback for dropdown selection change
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupSelected();
        end

        % Callback for when a group is selected from the dropdown
        function onGroupSelected(obj)
            if isempty(obj.App.OverlayClass.groups)
                return
            end
            obj.group = str2double(obj.GroupDropdown.Value);
            obj.update()
        end

        % Update the sigma value based on the Gaussian slider
        function updateSigma(obj)
            % Convert log slider value back to σ
            obj.sigma = 10^(obj.GaussSlider.Value);

            % Now use sigma in your blending function
            obj.blendImages()
        end
    end

    methods (Static)
        function name = getName()
            name = 'TimeSlider';
        end
    end
end