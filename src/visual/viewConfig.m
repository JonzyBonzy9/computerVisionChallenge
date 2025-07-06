classdef viewConfig < handle

    properties (Access = public)
        App           matlab.apps.AppBase
        Grid          matlab.ui.container.GridLayout
        Axes          matlab.ui.control.UIAxes
        DropDownLabel matlab.ui.control.Label
        DropDown      matlab.ui.control.Dropdown
        slider_threshold
        slider_blockSize
        slider_areaMin
        slider_areaMax
    end

    methods
        % Constructor
        function obj = untitled(App, dropdownitems)
            obj.App = App;

            % Create DropDownLabel
            obj.DropDownLabel = uilabel(obj.DropDownGrid);
            obj.DropDownLabel.HorizontalAlignment = 'right';
            obj.DropDownLabel.Layout.Row = 1;
            obj.DropDownLabel.Layout.Column = 1;
            obj.DropDownLabel.Text = 'Method:';

            % Create DropDown
            obj.DropDown = uidropdown(obj.DropDownGrid); 
            obj.DropDown.Layout.Row = 1;
            obj.DropDown.Layout.Column = 2;

            % Fülle DropDown mit Methoden
            obj.DropDown.Items = dropdownitems;
            
            obj.slider_threshold = SliderObj(App, differenceEstimationFunctions.value_range_threshold(1), differenceEstimationFunctions.value_range_threshold(end));
            obj.slider_blockSize = SliderObj(App, differenceEstimationFunctions.value_range_blockSize(1), differenceEstimationFunctions.value_range_blockSize(end));
            obj.slider_areaMin = SliderObj(App, differenceEstimationFunctions.value_range_areaMin(1), differenceEstimationFunctions.value_range_areaMin(end));
            obj.slider_areaMax = SliderObj(App, differenceEstimationFunctions.value_range_areaMax(1), differenceEstimationFunctions.value_range_areaMax(end));
        end

        function show(obj)
            obj.Grid.Visible = 'on';
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

    end
end