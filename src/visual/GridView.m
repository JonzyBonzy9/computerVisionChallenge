classdef GridView < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable
        Grid            matlab.ui.container.GridLayout
        UIAxes          matlab.ui.control.UIAxes
    end

    methods
        % Constructor
        function obj = GridView(app)
            obj.App = app;
            obj.dataAvailable = false;

            obj.Grid = uigridlayout(app.MainContentPanel);
            obj.Grid.ColumnWidth = {'1x'};
            obj.Grid.RowHeight = {'1x'};
            obj.Grid.Visible = 'off';
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
            % Clear existing content
            delete(obj.Grid.Children);
        
            numImages = numel(obj.App.OverlayClass.imageArray);
        
            % Determine grid size
            numCols = ceil(sqrt(numImages));
            numRows = ceil(numImages / numCols);
        
            % Adjust the grid layout size
            obj.Grid.RowHeight = repmat({'1x'}, 1, numRows);
            obj.Grid.ColumnWidth = repmat({'1x'}, 1, numCols);
            obj.Grid.RowSpacing = 5;
            obj.Grid.ColumnSpacing = 5;
            obj.Grid.Padding = [10 10 10 10];

        
            % Create axes and display images
            for i = 1:numImages
                ax = uiaxes(obj.Grid);
                imshow(obj.App.OverlayClass.imageArray{i}.data, 'Parent', ax);
                ax.XTick = [];
                ax.YTick = [];
                title(ax, sprintf(datestr(obj.App.OverlayClass.imageArray{i}.id, 'mm-yyyy'), i));
            end
        end
    end

    methods (Access = private)

    end

    methods (Static)
        function name = getName()
            name = 'Grid';
        end        
    end
end