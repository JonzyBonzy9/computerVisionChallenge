classdef TimeSliderOverlayView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable
        Grid          matlab.ui.container.GridLayout
        Grid2         matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        SliderGrid    matlab.ui.container.GridLayout
        SliderLabel   matlab.ui.control.Label
        Slider        matlab.ui.control.Slider
        GaussSlider   matlab.ui.control.Slider
        imCheck matlab.ui.control.CheckBox
        diffCheck matlab.ui.control.CheckBox
        controlPanel
        GroupDropdown
        ApplyGroupButton
        imageStack
        maskStack
        sigma
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
            obj.GaussSlider.Limits = [-1, log10(3)];
            obj.GaussSlider.Value = log10(1); % Default 1
            obj.sigma = 1;
            obj.GaussSlider.MajorTicks = [-1, -0.5, 0, 1];
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
            obj.Grid.Visible = 'on';

            % update view if data is available
            if obj.dataAvailable
                obj.update()                
            end
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

        function update(obj)            
            % get data into efficient image stack for images
            if obj.App.OverlayClass.resultAvailable
                obj.updateGroups(obj.App.OverlayClass.groups);
                selectedGroupName = obj.GroupDropdown.Value;
                selectedGroupIndex = str2double(selectedGroupName);
                disp(selectedGroupIndex)
                indices = obj.App.OverlayClass.groups{selectedGroupIndex};
                filteredImages = obj.App.OverlayClass.warpedImages(indices);
                obj.imageStack = cat(4, filteredImages{:});
                obj.blendImages();
                obj.imCheck.Enable = 'on';
                obj.imCheck.Value = true;
                % get data into efficient image stack for masks
                if obj.App.DifferenceClass.resultAvailable
                    maskList = cell(1, numel(indices));
                    for k = 1:numel(indices)
                        currentIndex = indices(k);
                        match = ismember(obj.App.DifferenceClass.lastIndices, currentIndex);
                        disp(currentIndex)
                        disp(match)
                        if match(end)
                            disp("end")
                            imgSize = size(obj.App.OverlayClass.warpedImages{currentIndex});
                            maskList{k} = zeros(imgSize(1), imgSize(2));
                        elseif any(match)
                            disp("match found")
                            disp(find(match,1))
                            maskList{k} = obj.App.DifferenceClass.differenceMasks{find(match, 1)};
                        elseif k==1
                            disp("nothing added yet")
                            imgSize = size(obj.App.OverlayClass.warpedImages{currentIndex});
                            maskList{k} = zeros(imgSize(1), imgSize(2));
                        end
                    end

                    obj.maskStack = cat(3, maskList{:});
                    obj.diffCheck.Enable = 'on';
                    obj.diffCheck.Value = true;
                else
                    obj.diffCheck.Enable = 'off';
                    obj.diffCheck.Value = false;
                end
            else
                images = cellfun(@(im) im.data, obj.App.OverlayClass.imageArray, 'UniformOutput',false);
                obj.imageStack = cat(4, images{:});
                obj.imCheck.Enable = 'off';
                obj.imCheck.Value = true;
            end            
            % move data to gpu if available
            if gpuDeviceCount > 0
                obj.imageStack = gpuArray(obj.imageStack);
                obj.maskStack = gpuArray(obj.maskStack);
            end
            obj.updateSlider(1)
            obj.blendImages()
        end
    end

    methods (Access = private)
        function blendImages(obj)
            value = obj.Slider.Value;
            % check whether overlay data is available
            if ~obj.App.OverlayClass.resultAvailable
                % if not, show raw images
                value = round(value);
                imshow(obj.imageStack(:,:,:,value), 'Parent', obj.Axes);
                obj.Slider.Value = value;
            else
                % show warped images
                N = size(obj.imageStack, 4);
            
                % Compute Gaussian weights centered at slider value
                x = 1:N;
                weights = exp(-0.5 * ((x - value) / obj.sigma).^2);
                weights = weights / sum(weights);  % Normalize
    
                % Blend images
                blended = zeros(size(obj.imageStack,1), size(obj.imageStack,2), size(obj.imageStack,3), 'like', obj.imageStack);
                if obj.imCheck.Value
                    for i = 1:N
                        blended = blended + weights(i) * obj.imageStack(:,:,:,i);
                    end
                end
                if obj.diffCheck.Value
                    for i = 1:N
                        blended = blended + weights(i) * obj.maskStack(:,:,i);
                    end
                end
            
                % Display
                imshow(blended, 'Parent', obj.Axes);
            end
        end
        function updateSlider(obj, group)
            N = size(obj.imageStack, 4);
            obj.Slider.Limits = [1, N];
            obj.Slider.MajorTicks = 1:N;

            if ~obj.App.OverlayClass.resultAvailable
                indices = 1:N;
            else
                indices = obj.App.OverlayClass.groups{group};
            end

            dates = cellfun(@(s) string(s.id), obj.App.OverlayClass.imageArray(indices));
            obj.Slider.MajorTickLabels = dates;
            obj.Slider.Value = 1;
        end
        function updateGroups(obj, groups)
            % groups: cell array of vectors with indices of items in each group
            
            numGroups = numel(groups);
            groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);
            
            % Update dropdown items
            obj.GroupDropdown.Items = groupNames;
            
            % Attach callback for dropdown selection change
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupSelected();
        end
        function onGroupSelected(obj)
            if isempty(obj.App.OverlayClass.groups)
                return
            end
            
            obj.updateSlider(selectedGroupIndex);
            obj.update()
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
            name = 'TimeSlider';
        end        
    end
end