classdef SliderObj < handle

    properties (Access = public)
        App           matlab.apps.AppBase
        Grid          matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        SliderGrid    matlab.ui.container.GridLayout
        SliderLabel   matlab.ui.control.Label
        Slider        matlab.ui.control.Slider
    end

    methods
        function obj = SliderObj(App, minVal, maxVal)
            obj.App = app;

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
            obj.Slider.Limits = [minVal maxVal];
            obj.Slider.MajorTicks = minVal:maxVal;
            generateTicks = @(x, y)roundNiceTicks(minVal, maxVal, 5);
            obj.Slider.MajorTickLabels = generateTicks;
            obj.Slider.Value = 1;

            obj.Slider.ValueChangedFcn = @(src,event) obj.sliderValueChanged(src, event);
        end

        function show(obj)
            obj.Grid.Visible = 'on';
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end
    end

    methods (Access = private)
        function newValue = sliderValueChanged(obj, src, event)
            newValue = obj.Slider.Value;
        end
    end
end