classdef TimeSliderView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable
        Grid          matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        SliderGrid    matlab.ui.container.GridLayout
        SliderLabel   matlab.ui.control.Label
        Slider        matlab.ui.control.Slider
    end

    methods
        % Constructor
        function obj = TimeSliderView(app)
            obj.App = app;
            obj.dataAvailable = false;

            % Create Panel 1 Grid layout
            obj.Grid = uigridlayout(app.MainContentPanel);
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.RowHeight = {'1x', 60};
            obj.Grid.Visible = 'off';

            % Create Image
            obj.Axes = uiaxes(obj.Grid);
            obj.Axes.Layout.Row = 1;
            obj.Axes.Layout.Column = 1;
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

            obj.Slider.ValueChangedFcn = @(src,event) obj.sliderValueChanged(src, event);
        end

        function onImLoad(obj)
            % Update panel
            obj.dataAvailable = true;            
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
            imshow(obj.App.Images{1}, 'Parent', obj.Axes);

            obj.Slider.Limits = [1 length(obj.App.Images)];
            obj.Slider.MajorTicks = 1:length(obj.App.Images);
            obj.Slider.MajorTickLabels = cellstr(datestr(obj.App.ImageDates, 'yyyy_mm'));
            obj.Slider.Value = 1;
        end
    end

    methods (Access = private)
        function sliderValueChanged(obj, src, event)
            idx = round(src.Value);
            idx = max(1, min(idx, length(obj.App.Images)));
            src.Value = idx;

            % Display image
            imshow(obj.App.Images{idx}, 'Parent', obj.Axes);
        end
    end

    methods (Static)
        function name = getName()
            name = 'TimeSlider';
        end        
    end
end