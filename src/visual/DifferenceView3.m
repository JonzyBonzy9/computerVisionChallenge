classdef DifferenceView3 < handle
    properties (Access = private)
        App             matlab.apps.AppBase

        % Main layout components
        Grid            matlab.ui.container.GridLayout
        TabGroup        matlab.ui.container.TabGroup
        MainTab         matlab.ui.container.Tab
        AnalysisTab     matlab.ui.container.Tab
        ConsoleTab      matlab.ui.container.Tab
        individualPanel matlab.ui.container.Panel
        combinedPanel   matlab.ui.container.Panel

        % Visualization components
        MainAxes        matlab.ui.control.UIAxes
        AnalysisAxes    matlab.ui.control.UIAxes
        StatusTextArea  matlab.ui.control.TextArea

        % control tabgroup
        controlTabGroup     matlab.ui.container.TabGroup
        visualizationTab    matlab.ui.container.Tab
        imageSelectionTab   matlab.ui.container.Tab
        parametersTab       matlab.ui.container.Tab

        % Unified algorithm/type dropdown and visualization controls
        EnvironmentPresetDropdown matlab.ui.control.DropDown
        IndividualModeButton    matlab.ui.control.StateButton
        AlgorithmTypeDropdown   matlab.ui.control.DropDown
        CombinedModeButton      matlab.ui.control.StateButton
        CombinationDropdown     matlab.ui.control.DropDown

        % Visualization display controls (like TimeSliderOverlay)
        ImagesCheckbox      matlab.ui.control.CheckBox
        MasksCheckbox       matlab.ui.control.CheckBox
        SigmaLabel          matlab.ui.control.Label
        SigmaSlider         matlab.ui.control.Slider

        % Two-dimensional preset controls
        ScaleDropdown       matlab.ui.control.DropDown

        % Temporal processing control (independent of presets)
        TemporalFilterDropdown matlab.ui.control.DropDown

        % Parameter controls
        ThresholdSlider     matlab.ui.control.Slider
        BlockSizeSlider     matlab.ui.control.Slider
        AreaMinSlider       matlab.ui.control.Slider
        AreaMaxSlider       matlab.ui.control.Slider
        ThresholdLabel      matlab.ui.control.Label
        BlockSizeLabel      matlab.ui.control.Label
        AreaMinLabel        matlab.ui.control.Label
        AreaMaxLabel        matlab.ui.control.Label

        % Action buttons
        CalculateButton     matlab.ui.control.Button
        ClearButton         matlab.ui.control.Button

        % Mask navigation
        MaskSlider          matlab.ui.control.Slider
        MaskSliderAxes      matlab.ui.control.UIAxes

        % Image selection (checkbox-based like DifferenceView)
        GroupDropdown       matlab.ui.control.DropDown
        RefreshGroupButton  matlab.ui.control.Button
        CheckboxGrid        matlab.ui.container.GridLayout
        Checkboxes          matlab.ui.control.CheckBox

        % Internal state
        currentResults
        currentMasks
        group
        isUpdatingPreset logical  % Flag to prevent recursive updates
        currentVisualizationMode string  % 'Individual' or 'Combined'

        % TimeSlider-like functionality for individual mode
        imageStack          % 4D array of images for efficient blending
        maskStack           % 4D array of masks for efficient blending
        sigma               double  % Current Gaussian sigma value

        % Image-dependent area scaling
        currentImageSize    double  % [height, width] of current images
        totalPixels         double  % Total number of pixels in image
        areaSliderLogBase   double  % Base for logarithmic area scaling

        % Presets for change types
        ChangeTypePresets   struct
        EnvironmentPresets  struct
    end

    methods
        function obj = DifferenceView3(app)
            obj.App = app;
            obj.isUpdatingPreset = false;
            obj.currentVisualizationMode = "Individual";  % Default mode

            % Initialize image-dependent area scaling
            obj.currentImageSize = [480, 640];  % Default image size
            obj.totalPixels = prod(obj.currentImageSize);
            obj.areaSliderLogBase = 10;  % Logarithmic base for area sliders

            % Initialize TimeSlider-style properties
            obj.sigma = 1.0;  % Default Gaussian sigma
            obj.imageStack = [];
            obj.maskStack = [];

            % Initialize change type presets
            obj.initializePresets();

            % Create main layout
            obj.createMainLayout();
            obj.createVisualizationTabs();
            obj.createControlPanel();
            obj.setupEventHandlers();

            % Initialize UI state and set default control visibility
            obj.onVisualizationChanged(); % Set initial control visibility
        end

        %% Interface methods for the main app
        function onImLoad(obj)
            if ~obj.App.dataLoaded
                return
            end
            obj.controlTabGroup.SelectedTab = obj.visualizationTab;
            % Called when new images are loaded - reset the view completely
            obj.currentMasks = [];
            obj.currentResults = [];

            % Clear visualizations
            obj.clearAxes(obj.MainAxes);
            obj.clearAxes(obj.AnalysisAxes);

            title(obj.MainAxes, 'Change Detection Visualization');
            title(obj.AnalysisAxes, 'Change Analysis');

            % Reset parameters to defaults (logarithmic scale for areas)
            obj.ThresholdSlider.Value = 20;    % 20% threshold (within [1, 100] range)
            obj.BlockSizeSlider.Value = 1;     % 3 pixels block size (within [1, 100] range)
            obj.AreaMinSlider.Value = 2;       % Log scale: 10^2 = 100 pixels
            obj.AreaMaxSlider.Value = 4;       % Log scale: 10^4 = 10000 pixels

            % Reset two-dimensional presets
            obj.ScaleDropdown.Value = 'Custom';
            obj.TemporalFilterDropdown.Value = 'none';
            % Update area slider limits based on available images
            % Get image dimensions from the overlay class
            try
                % Try to get image size from the first available image
                imageArray = obj.App.OverlayClass.imageArray;
                if ~isempty(imageArray)
                    firstImage = imageArray{1}.data; % Assuming image data is in .data field
                    if ~isempty(firstImage)
                        obj.currentImageSize = [size(firstImage, 1), size(firstImage, 2)];
                        obj.totalPixels = prod(obj.currentImageSize);
                        obj.updateAreaSliderLimits();
                    end
                end
            catch
                % If we can't get image size, use defaults
                obj.updateAreaSliderLimits();
            end
            obj.RefreshGroupButton.Enable = true;
            obj.update();
            obj.onCustomParameterChanged();
        end

        function show(obj)
            obj.Grid.Visible = 'on';
            obj.update();
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

        function update(obj)
            % Update view if data is available (like DifferenceView)
            if ~obj.App.dataLoaded
                return
            end
            disp("update diff view")

            % dependent on whether difference data is available
            if obj.App.DifferenceClass.resultAvailable
                obj.MasksCheckbox.Enable = 'on';
                obj.MasksCheckbox.Value = true;  % Enable and check by default
            else
                obj.MasksCheckbox.Enable = 'off';
                obj.MasksCheckbox.Value = false;  % Disable and uncheck
            end

            % updated after overlay is calculated
            if obj.App.OverlayClass.resultAvailable
                obj.controlTabGroup.SelectedTab = obj.parametersTab;
                obj.CalculateButton.Enable = 'on';
                obj.ImagesCheckbox.Enable = 'on';
                obj.ImagesCheckbox.Value = true;  % Enable and check by default
                obj.updateGroups(obj.App.OverlayClass.groups);
            else
                obj.CalculateButton.Enable = 'off';
                obj.ImagesCheckbox.Enable = 'off';
                obj.ImagesCheckbox.Value = true;  % Disable and uncheck
                obj.updateGroups({});  % Clear groups if no results available
            end

            obj.updateCheckboxes();  % Update checkboxes based on current state
            obj.updateSlider();
            obj.updateVisualization();
        end

        function updateCheckboxes(obj)
            % Clear old checkboxes from UI and memory
            delete(obj.CheckboxGrid.Children);
            obj.Checkboxes = matlab.ui.control.CheckBox.empty;

            imageArray = obj.App.OverlayClass.imageArray;
            n = length(imageArray);

            % One row per checkbox
            obj.CheckboxGrid.RowHeight = repmat({'fit'}, 1, n);

            if obj.App.DifferenceClass.resultAvailable
                for i = 1:n
                    dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                    isChecked = ismember(i, obj.App.DifferenceClass.lastIndices);
                    isAvailable = ismember(i, obj.App.OverlayClass.groups{obj.group});
                    cb = uicheckbox(obj.CheckboxGrid, ...
                        'Text', dateStr, ...
                        'Value', isChecked);
                    % Set font color depending on previous use
                    if isChecked
                        cb.FontColor = [0, 1, 0];  % green if used in last calculation
                    else
                        cb.FontColor = [1, 1, 1];  % White otherwise
                    end
                    cb.Layout.Row = i;
                    cb.Enable = isAvailable;  % Enable only if available in overlay
                    obj.Checkboxes(i) = cb;
                end
            elseif obj.App.OverlayClass.resultAvailable
                for i = 1:n
                    dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                    isAvailable = ismember(i, obj.App.OverlayClass.groups{obj.group});
                    cb = uicheckbox(obj.CheckboxGrid, ...
                        'Text', dateStr, ...
                        'Value', isAvailable);
                    cb.FontColor = [1, 1, 1];  % White
                    cb.Layout.Row = i;
                    cb.Enable = isAvailable;  % Enable only if available in overlay
                    obj.Checkboxes(i) = cb;
                end
            else
                for i=1:n
                    dateStr = datestr(imageArray{i}.id, 'yyyy_mm');
                    cb = uicheckbox(obj.CheckboxGrid, ...
                        'Text', dateStr, ...
                        'Value', false);
                    cb.FontColor = [1, 1, 1];  % White
                    cb.Layout.Row = i;
                    cb.Enable = false;  % Disable if no results available
                    obj.Checkboxes(i) = cb;
                end

            end
        end

        function updateSlider(obj)
            if ~obj.App.OverlayClass.resultAvailable
                indices = 1:numel(obj.App.OverlayClass.imageArray);
            else
                indices = obj.App.OverlayClass.groups{str2double(obj.GroupDropdown.Value)};
            end

            dates = cellfun(@(s) datestr(s.id, 'mmm yyyy'), obj.App.OverlayClass.imageArray(indices), 'UniformOutput', false);
            N = length(indices);
            obj.MaskSlider.Limits = [1, N];
            obj.MaskSlider.MajorTicks = 1:N;
            obj.MaskSlider.MajorTickLabels = {};
            obj.MaskSlider.Value = 1;

            % Update axes below slider with rotated labels
            obj.MaskSliderAxes.XLim = [1, N];
            obj.MaskSliderAxes.XTick = 1:N;
            obj.MaskSliderAxes.XTickLabel = dates;
        end

        function initializePresets(obj)
            % Define two-dimensional preset system: Scale × Algorithm/Type
            % Parameters use mix of percentage and absolute values for optimal control
            obj.ChangeTypePresets = struct();

            % SCALE dimension (affects block size in pixels and area constraints in pixels)
            obj.ChangeTypePresets.scale = struct();
            obj.ChangeTypePresets.scale.small = struct(...
                'blockSizePixels', 1, ...       % 1 pixel block size
                'areaMinPixels', 1, ...         % 1 pixel minimum
                'areaMaxPixels', 100);          % 100 pixels maximum

            obj.ChangeTypePresets.scale.medium = struct(...
                'blockSizePixels', 1, ...       % 3 pixel block size
                'areaMinPixels', 100, ...        % 10 pixels minimum
                'areaMaxPixels', 200000);         % 1000 pixels maximum

            obj.ChangeTypePresets.scale.large = struct(...
                'blockSizePixels', 10, ...      % 10 pixel block size
                'areaMinPixels', 1000, ...       % 100 pixels minimum
                'areaMaxPixels', 100000000);        % 10000 pixels maximum

            % ALGORITHM/TYPE dimension (combines detection method - temporal filter removed from algorithm control)
            obj.ChangeTypePresets.algorithmType = struct();

            % Basic algorithms (temporal filter now independent)
            obj.ChangeTypePresets.algorithmType.absdiff = struct(...
                'method', 'absdiff', ...               % Absolute difference
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.gradient = struct(...
                'method', 'gradient', ...              % Gradient-based detection
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.ssim = struct(...
                'method', 'ssim', ...                  % Structural similarity
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.dog = struct(...
                'method', 'dog', ...                   % Difference of Gaussians
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.pca = struct(...
                'method', 'pca', ...                   % Principal component analysis
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.temporal_analysis = struct(...
                'method', 'temporal_analysis', ...     % Temporal sequence analysis
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.texture_change = struct(...
                'method', 'texture_change', ...        % Texture-based detection
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            obj.ChangeTypePresets.algorithmType.edge_evolution = struct(...
                'method', 'edge_evolution', ...        % Edge evolution tracking
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            % Environment-optimized algorithms (temporal filter now independent)
            obj.ChangeTypePresets.algorithmType.urban_optimized = struct(...
                'method', 'gradient', ...               % Good for detecting geometric structures
                'thresholdModifier', 0.9, ...           % Slightly more sensitive for edges
                'areaModifier', 1.0);                   % No area modification

            obj.ChangeTypePresets.algorithmType.natural_optimized = struct(...
                'method', 'texture_change', ...         % Good for texture and organic changes
                'thresholdModifier', 1.3, ...           % Less sensitive to texture noise
                'areaModifier', 1.8);                   % Prefer larger connected areas

            obj.ChangeTypePresets.algorithmType.mixed_optimized = struct(...
                'method', 'absdiff', ...               % General purpose method
                'thresholdModifier', 1.0, ...          % No threshold modification
                'areaModifier', 1.0);                  % No area modification

            % Legacy presets for backwards compatibility (now deprecated)
            obj.ChangeTypePresets.legacy = struct();
            obj.ChangeTypePresets.legacy.fast = struct('threshold', 0.1, 'blockSize', 1, 'areaMin', 10, 'areaMax', 100);
            obj.ChangeTypePresets.legacy.slow = struct('threshold', 0.3, 'blockSize', 3, 'areaMin', 50, 'areaMax', 500);

            % Environment presets that control multiple parameters at once
            obj.EnvironmentPresets = struct();

            % Urban preset: optimized for built environments with geometric structures
            obj.EnvironmentPresets.urban = struct(...
                'algorithm', 'ssim', ...             % Simple difference detection for buildings
                'threshold', 20, ...                    % 20% threshold for clear changes
                'blockSize', 1, ...                     % 1 pixel block size for fine detail
                'areaMinPixels', 100, ...               % 105 pixels minimum area (0.0029% for large images)
                'areaMaxPercent', 200000, ...                % 4% max area for large structures
                'temporalFilter', 'fast', ...           % Fast temporal processing for urban changes
                'scale', 'medium');                     % Medium spatial scale

            % Natural preset: optimized for natural environments with organic changes
            obj.EnvironmentPresets.natural = struct(...
                'algorithm', 'ssim', ...      % Texture-based for natural features
                'threshold', 0.2, ...                    % 15% threshold (more sensitive for natural changes)
                'blockSize', 3, ...                     % 5 pixel block size for organic textures
                'areaMinPixels', 100000, ...               % 500 pixels minimum area (larger organic features)
                'areaMaxPercent', 100000000, ...                % 8% max area for natural formations
                'temporalFilter', 'medium', ...         % Medium temporal processing for gradual changes
                'scale', 'large');                      % Large spatial scale for natural features

            obj.EnvironmentPresets.mixed = struct(...
                'algorithm', 'gradient', ...             % Simple difference detection for buildings
                'threshold', 5, ...                    % 20% threshold for clear changes
                'blockSize', 2, ...                     % 1 pixel block size for fine detail
                'areaMinPixels', 100, ...               % 105 pixels minimum area (0.0029% for large images)
                'areaMaxPercent', 50000, ...                % 4% max area for large structures
                'temporalFilter', 'fast', ...           % Fast temporal processing for urban changes
                'scale', 'medium');                     % Medium spatial scale
        end

        function createMainLayout(obj)
            % Create main grid layout with visualization area and control panel
            obj.Grid = uigridlayout(obj.App.MainContentPanel, [1, 2]);
            obj.Grid.ColumnWidth = {'1x', 350}; % Main area flexible, control panel fixed width (increased)
            obj.Grid.Visible = 'off';
        end

        function createVisualizationTabs(obj)
            % Create tabbed visualization area
            obj.TabGroup = uitabgroup(obj.Grid);
            obj.TabGroup.Layout.Row = 1;
            obj.TabGroup.Layout.Column = 1;

            % Main visualization tab
            obj.MainTab = uitab(obj.TabGroup, 'Title', 'Main View');
            obj.MainAxes = uiaxes(obj.MainTab);
            obj.MainAxes.XTick = [];
            obj.MainAxes.YTick = [];
            title(obj.MainAxes, 'Change Detection Visualization');

            % Analysis tab for detailed analysis
            obj.AnalysisTab = uitab(obj.TabGroup, 'Title', 'Analysis');
            obj.AnalysisAxes = uiaxes(obj.AnalysisTab);
            obj.AnalysisAxes.XTick = [];
            obj.AnalysisAxes.YTick = [];
            title(obj.AnalysisAxes, 'Change Analysis');

            % Console tab for status and output
            obj.ConsoleTab = uitab(obj.TabGroup, 'Title', 'Console');
            obj.StatusTextArea = uitextarea(obj.ConsoleTab, ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'Value', {'Change Detection Console', 'Status messages will appear here...'});
        end

        function createControlPanel(obj)
            % Create control panel with two tabs (like DifferenceView/OverlayView structure)
            % Grid layout: [visualization area | control area]

            % Create control tab group in the right column
            obj.controlTabGroup = uitabgroup(obj.Grid);
            obj.controlTabGroup.Layout.Row = 1;
            obj.controlTabGroup.Layout.Column = 2;

            % === IMAGE SELECTION TAB (like DifferenceView) ===
            obj.imageSelectionTab = uitab(obj.controlTabGroup, 'Title', 'Image Selection');

            imageLayout = uigridlayout(obj.imageSelectionTab);
            imageLayout.RowHeight = {'fit', 'fit', '1x', 'fit'};
            imageLayout.ColumnWidth = {'1x'};
            imageLayout.RowSpacing = 5;
            imageLayout.Padding = [10, 10, 10, 10];

            lbl = uilabel(imageLayout, 'Text', 'Select images from one group for calculations:', 'FontWeight', 'bold');
            lbl.Layout.Row = 1;

            % Group Selection area with dropdown and refresh button
            groupSelectionGrid = uigridlayout(imageLayout);
            groupSelectionGrid.Layout.Row = 2;
            groupSelectionGrid.RowHeight = {'fit'};
            groupSelectionGrid.ColumnWidth = {'1x', '1x'};
            groupSelectionGrid.ColumnSpacing = 5;

            obj.GroupDropdown = uidropdown(groupSelectionGrid, ...
                'Items', {''}, ...
                'Value', '', ...
                'Tooltip', 'Select image group');
            obj.GroupDropdown.Layout.Row = 1;
            obj.GroupDropdown.Layout.Column = 1;

            % Refresh button to re-trigger group selection
            obj.RefreshGroupButton = uibutton(groupSelectionGrid, 'push', ...
                'Text', 'Apply', ...
                'Tooltip', 'Refresh/Re-apply current group selection', ...
                'FontSize', 12);
            obj.RefreshGroupButton.Layout.Row = 1;
            obj.RefreshGroupButton.Layout.Column = 2;
            obj.RefreshGroupButton.Enable = false;  % Initially disabled

            % Image Selection checkboxes
            obj.CheckboxGrid = uigridlayout(imageLayout);
            obj.CheckboxGrid.Layout.Row = 3;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            obj.CheckboxGrid.RowSpacing = 2;

            % Clear all button (like DifferenceView)
            obj.ClearButton = uibutton(imageLayout, 'push', ...
                'Text', 'Clear all', ...
                'FontColor', 'red', ...
                'ButtonPushedFcn', @(btn, evt) obj.clearCheckboxes());
            obj.ClearButton.Layout.Row = 4;

            % === PARAMETERS TAB ===
            obj.parametersTab = uitab(obj.controlTabGroup, 'Title', 'Parameters');

            paramLayout = uigridlayout(obj.parametersTab);
            paramLayout.RowHeight = {'fit', 'fit', 'fit', 10, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            paramLayout.ColumnWidth = {'1x'};
            paramLayout.RowSpacing = 5;
            paramLayout.Padding = [10, 10, 10, 10];
            paramLayout.Scrollable = 'on';

            currentRow = 1;

            % === HIGHLIGHTED PRESET SELECTION ===
            % Create highlighted panel for preset selection
            presetPanel = uipanel(paramLayout, ...
                'Title', 'Quick Start - Environment Presets', ...
                'FontWeight', 'bold');
            presetPanel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            presetGrid = uigridlayout(presetPanel);
            presetGrid.RowHeight = {'fit', 'fit'};
            presetGrid.ColumnWidth = {'1x'};
            presetGrid.RowSpacing = 8;
            presetGrid.Padding = [15, 15, 15, 15];

            obj.EnvironmentPresetDropdown = uidropdown(presetGrid, ...
                'Items', differenceEstimationFunctions.valid_change_types, ...
                'Value', 'urban', ...
                'Tooltip', 'Select environment-optimized preset configuration', ...
                'FontSize', 11);
            obj.EnvironmentPresetDropdown.Layout.Row = 1;

            % === CALCULATE BUTTON - Prominently placed ===
            obj.CalculateButton = uibutton(presetGrid, 'push', ...
                'Text', 'Calculate Changes', ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'FontSize', 12, ...
                'FontWeight', 'bold');
            obj.CalculateButton.Layout.Row = 2;

            % === SPACER ===
            spacer = uilabel(paramLayout, 'Text', '');
            spacer.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === ADVANCED SETTINGS SECTION ===
            advancedPanel = uipanel(paramLayout, ...
                'Title', 'Advanced Settings', ...
                'FontWeight', 'bold');
            advancedPanel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            advancedGrid = uigridlayout(advancedPanel);
            advancedGrid.RowHeight = repmat({'fit'}, 1, 20); % 20 rows for all advanced settings
            advancedGrid.ColumnWidth = {'1x'};
            advancedGrid.RowSpacing = 5;
            advancedGrid.Padding = [15, 15, 15, 15];
            advancedGrid.Scrollable = 'on';

            advancedRow = 1;

            % === Algorithm Selection ===
            algorithmLabel = uilabel(advancedGrid, 'Text', 'Detection Algorithm:', 'FontWeight', 'bold');
            algorithmLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.AlgorithmTypeDropdown = uidropdown(advancedGrid, ...
                'Items', differenceEstimationFunctions.valid_methods, ...
                'Value', 'absdiff', ...
                'Tooltip', 'Select detection algorithm or environment-optimized preset');
            obj.AlgorithmTypeDropdown.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % === Scale Presets ===
            scaleLabel = uilabel(advancedGrid, 'Text', 'Spatial Scale Preset:', 'FontWeight', 'bold');
            scaleLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.ScaleDropdown = uidropdown(advancedGrid, ...
                'Items', {'Custom', 'small', 'medium', 'large'}, ...
                'Value', 'Custom', ...
                'Tooltip', 'Select spatial scale of changes');
            obj.ScaleDropdown.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % === Temporal Processing ===
            tempProcessLabel = uilabel(advancedGrid, 'Text', 'Temporal Processing:', 'FontWeight', 'bold');
            tempProcessLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.TemporalFilterDropdown = uidropdown(advancedGrid, ...
                'Items', {'none', 'fast', 'medium', 'slow'}, ...
                'Value', 'none', ...
                'Tooltip', 'Apply temporal processing (independent of other parameters)');
            obj.TemporalFilterDropdown.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % === Manual Parameter Controls ===
            manualLabel = uilabel(advancedGrid, 'Text', 'Manual Parameter Control:', 'FontWeight', 'bold');
            manualLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % Threshold (percentage 0-100%)
            obj.ThresholdLabel = uilabel(advancedGrid, 'Text', 'Threshold: 20%');
            obj.ThresholdLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.ThresholdSlider = uislider(advancedGrid, 'Limits', differenceEstimationFunctions.value_range_threshold, 'Value', 20, ...
                'Tooltip', 'Detection threshold as percentage (1-100%)');
            obj.ThresholdSlider.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % Block Size (pixels 1-100)
            obj.BlockSizeLabel = uilabel(advancedGrid, 'Text', 'Block Size: 3 pixels');
            obj.BlockSizeLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.BlockSizeSlider = uislider(advancedGrid, 'Limits', differenceEstimationFunctions.value_range_blockSize, 'Value', 1, ...
                'Tooltip', 'Block size in pixels (1-100)');
            obj.BlockSizeSlider.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % Area Min (logarithmic scale - will be updated based on image size)
            obj.AreaMinLabel = uilabel(advancedGrid, 'Text', 'Min Area: 100 pixels');
            obj.AreaMinLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.AreaMinSlider = uislider(advancedGrid, 'Limits', differenceEstimationFunctions.value_range_areaMin, 'Value', 2, ...
                'Tooltip', 'Minimum change area (logarithmic scale: 1 pixel to 10% of image)');
            obj.AreaMinSlider.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            % Area Max (logarithmic scale - will be updated based on image size)
            obj.AreaMaxLabel = uilabel(advancedGrid, 'Text', 'Max Area: 10000 pixels');
            obj.AreaMaxLabel.Layout.Row = advancedRow;
            advancedRow = advancedRow + 1;

            obj.AreaMaxSlider = uislider(advancedGrid, 'Limits', differenceEstimationFunctions.value_range_areaMax, 'Value', 4, ...
                'Tooltip', 'Maximum change area (logarithmic scale: 10 pixels to 50% of image)');
            obj.AreaMaxSlider.Layout.Row = advancedRow;

            % === VISUALIZATION TAB ===
            obj.visualizationTab = uitab(obj.controlTabGroup, 'Title', 'Visualization');
            obj.controlTabGroup.SelectedTab = obj.visualizationTab;

            visualLayout = uigridlayout(obj.visualizationTab);
            visualLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            visualLayout.ColumnWidth = {'1x'};
            visualLayout.RowSpacing = 5;
            visualLayout.Padding = [10, 10, 10, 10];

            currentRow = 1;

            % === Visualization Type ===
            visualTypeLabel = uilabel(visualLayout, 'Text', 'Visualization Mode:', 'FontWeight', 'bold');
            visualTypeLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Create button grid for visualization mode selection
            buttonGrid = uigridlayout(visualLayout);
            buttonGrid.Layout.Row = currentRow;
            buttonGrid.RowHeight = {'fit'};
            buttonGrid.ColumnWidth = {'1x', '1x'};
            buttonGrid.ColumnSpacing = 5;
            buttonGrid.Padding = [0, 0, 0, 0];

            obj.IndividualModeButton = uibutton(buttonGrid, 'state', ...
                'Text', 'Individual', ...
                'Value', true, ...
                'Tooltip', 'Individual visualization with slider control');
            obj.IndividualModeButton.Layout.Row = 1;
            obj.IndividualModeButton.Layout.Column = 1;

            obj.CombinedModeButton = uibutton(buttonGrid, 'state', ...
                'Text', 'Combined', ...
                'Value', false, ...
                'Tooltip', 'Combined visualization of all changes');
            obj.CombinedModeButton.Layout.Row = 1;
            obj.CombinedModeButton.Layout.Column = 2;

            currentRow = currentRow + 1;

            % === Display Options ===
            displayLabel = uilabel(visualLayout, 'Text', 'Display Options:', 'FontWeight', 'bold');
            displayLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.ImagesCheckbox = uicheckbox(visualLayout, ...
                'Text', 'Images', ...
                'Value', true, ...
                'Tooltip', 'Show background images');
            obj.ImagesCheckbox.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.MasksCheckbox = uicheckbox(visualLayout, ...
                'Text', 'Masks', ...
                'Value', true, ...
                'Tooltip', 'Show change masks');
            obj.MasksCheckbox.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.individualPanel = obj.createSection(visualLayout, 'Individual Mode Controls', currentRow + 2);
            obj.individualPanel.Visible = 'on';  % Initially visible (default mode)
            individualGrid = uigridlayout(obj.individualPanel);
            individualGrid.RowHeight = {'fit', 'fit', 'fit', 90, 'fit'};
            individualGrid.ColumnWidth = {'1x'};
            obj.combinedPanel = obj.createSection(visualLayout, 'Combined Mode Controls', currentRow + 2);
            obj.combinedPanel.Visible = 'off';  % Initially hidden
            combinedGrid = uigridlayout(obj.combinedPanel);
            combinedGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
            combinedGrid.ColumnWidth = {'1x'};

            % === Individual Mode Controls ===
            obj.SigmaLabel = uilabel(individualGrid, 'Text', 'Blend Amount: 1.0');
            obj.SigmaLabel.Layout.Row = 1;

            obj.SigmaSlider = uislider(individualGrid, ...
                'Limits', [-1, 0.5], ...
                'Value', 0, ...
                'MajorTicks', [-1, -0.5, 0, 0.5], ...
                'MajorTickLabels', {'0.1', '0.3', '1', '3'}, ...
                'Tooltip', 'Gaussian blend amount (log scale)');
            obj.SigmaSlider.Layout.Row = 2;

            % === Mask Navigation ===
            maskNavLabel = uilabel(individualGrid, 'Text', 'TimeSlider:', 'FontWeight', 'bold');
            maskNavLabel.Layout.Row = 3;


            obj.MaskSlider = uislider(individualGrid, ...
                'Limits', [1, 2], ...
                'Value', 1, ...
                'MajorTicks', [1, 2], ...
                'MajorTickLabels', {}, ...
                'Tooltip', 'Select date to display');
            obj.MaskSlider.Layout.Row = 5;

            % Axes for rotated tick labels below the slider
            obj.MaskSliderAxes = uiaxes(individualGrid);
            obj.MaskSliderAxes.Layout.Row = 4;
            obj.MaskSliderAxes.XLim = [1, 2];
            obj.MaskSliderAxes.YLim = [0, 1];
            obj.MaskSliderAxes.XTick = [1, 2];
            obj.MaskSliderAxes.XTickLabel = {'', ''};
            obj.MaskSliderAxes.XTickLabelRotation = 80;
            obj.MaskSliderAxes.YTick = [];
            obj.MaskSliderAxes.YTickLabel = {};
            obj.MaskSliderAxes.Box = 'off';
            obj.MaskSliderAxes.Color = 'none';  % Transparent background
            obj.MaskSliderAxes.XColor = [1, 1, 1];  % Black tick labels
            obj.MaskSliderAxes.YAxis.Visible = 'off';
            obj.MaskSliderAxes.XAxis.TickLength = [0 0];  % Hide tick marks, keep labels
            obj.MaskSliderAxes.Interactions = [];  % Disable all interactions
            obj.MaskSliderAxes.Toolbar.Visible = 'off';  % Hide toolbar

            % === Combined Mode Controls ===
            obj.CombinationDropdown = uidropdown(combinedGrid, ...
                'Items', differenceEstimationFunctions.valid_visualization_types, ...
                'Value', 'heatmap', ...
                'Tooltip', 'How to combine multiple masks');
            obj.CombinationDropdown.Layout.Row = 1;
        end

        function section = createSection(~, parent, title, row)
            % Create a titled section panel
            section = uipanel(parent, 'Title', title);
            section.Layout.Row = row;
        end

        function setupEventHandlers(obj)
            % Set up all event handlers
            obj.EnvironmentPresetDropdown.ValueChangedFcn = @(src, event) obj.onEnvironmentPresetChanged();
            obj.AlgorithmTypeDropdown.ValueChangedFcn = @(src, event) obj.onAlgorithmTypeChanged();
            obj.IndividualModeButton.ValueChangedFcn = @(src, event) obj.onVisualizationModeChanged(src, 'Individual');
            obj.CombinedModeButton.ValueChangedFcn = @(src, event) obj.onVisualizationModeChanged(src, 'Combined');
            obj.CombinationDropdown.ValueChangedFcn = @(src, event) obj.onVisualizationChanged();

            % Two-dimensional preset handlers
            obj.ScaleDropdown.ValueChangedFcn = @(src, event) obj.onPresetDimensionChanged();

            % Temporal processing handler (independent)
            obj.TemporalFilterDropdown.ValueChangedFcn = @(src, event) obj.onTemporalFilterChanged();
            obj.ThresholdSlider.ValueChangedFcn = @(src, event) obj.onCustomParameterChanged();
            obj.BlockSizeSlider.ValueChangedFcn = @(src, event) obj.onCustomParameterChanged();
            obj.AreaMinSlider.ValueChangedFcn = @(src, event) obj.onCustomParameterChanged();
            obj.AreaMaxSlider.ValueChangedFcn = @(src, event) obj.onCustomParameterChanged();

            % Mask navigation
            obj.MaskSlider.ValueChangedFcn = @(src, event) obj.onMaskSelectionChanged();

            % New TimeSlider-style display controls
            obj.ImagesCheckbox.ValueChangedFcn = @(src, event) obj.onDisplayOptionsChanged();
            obj.MasksCheckbox.ValueChangedFcn = @(src, event) obj.onDisplayOptionsChanged();
            obj.SigmaSlider.ValueChangedFcn = @(src, event) obj.onSigmaSliderChanged();

            % Action buttons
            obj.CalculateButton.ButtonPushedFcn = @(src, event) obj.onCalculatePressed();

            % Group selection (like DifferenceView)
            obj.GroupDropdown.ValueChangedFcn = @(src, event) obj.onGroupChanged();
            obj.RefreshGroupButton.ButtonPushedFcn = @(src, event) obj.onGroupChanged();
        end

        function onAlgorithmTypeChanged(obj)
            % Handle algorithm/type change
            algorithmType = obj.AlgorithmTypeDropdown.Value;
            obj.updateStatus(['Algorithm changed to: ' algorithmType]);
            % Note: Temporal filter is now independent and not affected by algorithm selection
        end

        function onTemporalFilterChanged(obj)
            % Handle temporal processing change (independent of other parameters)
            filter = obj.TemporalFilterDropdown.Value;
            obj.updateStatus(['Temporal processing changed to: ' filter]);
        end

        function onEnvironmentPresetChanged(obj)
            % Handle environment preset selection
            preset = obj.EnvironmentPresetDropdown.Value;

            try
                obj.isUpdatingPreset = true;

                % Get preset configuration
                presetConfig = obj.EnvironmentPresets.(preset);

                % Apply algorithm selection
                obj.AlgorithmTypeDropdown.Value = presetConfig.algorithm;

                % Apply threshold (percentage)
                obj.ThresholdSlider.Value = presetConfig.threshold;

                % Apply block size (pixels)
                obj.BlockSizeSlider.Value = presetConfig.blockSize;

                % Apply temporal filter
                obj.TemporalFilterDropdown.Value = presetConfig.temporalFilter;

                % Apply scale selection
                obj.ScaleDropdown.Value = presetConfig.scale;
                obj.onPresetDimensionChanged();  % Update sliders based on scale

                % Update all labels to show preset values
                obj.updateParameterLabelsWithPresetInfo('Custom', presetConfig.scale, obj.AlgorithmTypeDropdown.Value);
                obj.updateAreaLabels();

                obj.isUpdatingPreset = false;

                % Provide feedback
                obj.updateStatus(sprintf('Applied %s environment preset: %s algorithm, %d%% threshold, %d pixel blocks, %s temporal processing', ...
                    preset, presetConfig.algorithm, presetConfig.threshold, presetConfig.blockSize, presetConfig.temporalFilter));

            catch ME
                obj.isUpdatingPreset = false;
                obj.updateStatus(['Error applying environment preset: ' ME.message]);
            end
        end

        function onPresetDimensionChanged(obj)
            % Handle two-dimensional preset selection (scale only)
            scale = obj.ScaleDropdown.Value;
            algorithmType = obj.AlgorithmTypeDropdown.Value;

            % Provide user feedback about current selection
            obj.getCurrentPresetDescription();

            % Update sliders based on scale selection only
            try
                obj.isUpdatingPreset = true;

                % Start with current slider values as base (block size now in pixels, areas in log scale)
                blockSizePixels = obj.BlockSizeSlider.Value;    % Now absolute pixels (1-100)
                areaMinLogValue = obj.AreaMinSlider.Value;      % Logarithmic scale
                areaMaxLogValue = obj.AreaMaxSlider.Value;      % Logarithmic scale

                % Apply SCALE dimension (affects block size in pixels and area in pixels)
                if ~strcmp(scale, 'Custom')
                    scaleParams = obj.ChangeTypePresets.scale.(scale);
                    blockSizePixels = scaleParams.blockSizePixels;  % Now using pixel values

                    % Convert pixel area values to logarithmic scale
                    areaMinLogValue = obj.pixelsToLogArea(scaleParams.areaMinPixels);
                    areaMaxLogValue = obj.pixelsToLogArea(scaleParams.areaMaxPixels);
                end

                % Update all UI elements with calculated values
                obj.BlockSizeSlider.Value = blockSizePixels;    % Now using pixel values
                obj.AreaMinSlider.Value = areaMinLogValue;      % Logarithmic scale
                obj.AreaMaxSlider.Value = areaMaxLogValue;      % Logarithmic scale

                % Update area labels to show pixel and percentage values
                obj.updateAreaLabels();

                % Update labels with preset indicators
                obj.updateParameterLabelsWithPresetInfo('Custom', scale, algorithmType);

                obj.isUpdatingPreset = false;

                % Provide feedback about what was applied
                appliedDimensions = {};
                if ~strcmp(scale, 'Custom'), appliedDimensions{end+1} = sprintf('scale:%s', scale); end
                if isfield(obj.ChangeTypePresets.algorithmType, algorithmType)
                    appliedDimensions{end+1} = sprintf('algorithm:%s', algorithmType);
                end

                if ~isempty(appliedDimensions)
                    obj.updateStatus(sprintf('Applied preset dimensions: %s', strjoin(appliedDimensions, ', ')));
                end

            catch ME
                obj.isUpdatingPreset = false;
                obj.updateStatus(['Error applying preset: ' ME.message]);
            end
        end

        function onVisualizationModeChanged(obj, src, mode)
            % Handle visualization mode button press
            if src.Value  % Button is pressed (active)
                % Set the current mode
                obj.currentVisualizationMode = mode;

                % Update button states (mutual exclusion)
                if strcmp(mode, 'Individual')
                    obj.CombinedModeButton.Value = false;
                else
                    obj.IndividualModeButton.Value = false;
                end

                % Trigger visualization update
                obj.onVisualizationChanged();
            else
                % If user tries to deactivate current mode, reactivate it
                src.Value = true;
            end
        end

        function onVisualizationChanged(obj)
            % Handle visualization type change and update control visibility
            visualizationType = obj.currentVisualizationMode;

            % Update control visibility based on mode
            switch visualizationType
                case 'Individual'
                    % Show individual mode controls, hide combined mode controls
                    obj.individualPanel.Visible = 'on';
                    obj.combinedPanel.Visible = 'off';

                case 'Combined'
                    % Show combined mode controls, hide individual mode controls
                    obj.individualPanel.Visible = 'off';
                    obj.combinedPanel.Visible = 'on';
            end

            % Update visualization if data is available
            if obj.App.dataLoaded
                obj.updateVisualization();
            end
        end

        function onCustomParameterChanged(obj)
            % Update parameter labels and reset dropdowns when manually adjusting
            if ~obj.isUpdatingPreset
                % Manual adjustment - reset preset dropdowns to custom and update labels normally
                obj.EnvironmentPresetDropdown.Value = 'urban';
                obj.ScaleDropdown.Value = 'Custom';

                % Use appropriate labels for manual control
                obj.ThresholdLabel.Text = sprintf('Threshold: %.1f%%', obj.ThresholdSlider.Value);
                obj.BlockSizeLabel.Text = sprintf('Block Size: %.0f pixels', obj.BlockSizeSlider.Value);

                % Update area labels using the logarithmic helper method
                obj.updateAreaLabels();

                % Reset label colors to dark gray (manual control)
                obj.ThresholdLabel.FontColor = [0.4, 0.4, 0.4];
                obj.BlockSizeLabel.FontColor = [0.4, 0.4, 0.4];
                obj.AreaMinLabel.FontColor = [0.4, 0.4, 0.4];
                obj.AreaMaxLabel.FontColor = [0.4, 0.4, 0.4];
            else
                % Preset update - use the specialized labeling method
                scale = obj.ScaleDropdown.Value;
                algorithmType = obj.AlgorithmTypeDropdown.Value;
                obj.updateParameterLabelsWithPresetInfo('Custom', scale, algorithmType);
            end
        end

        function onMaskSelectionChanged(obj)
            % Handle mask navigation
            if obj.App.dataLoaded
                obj.updateVisualization();
            end
        end

        function onCalculatePressed(obj)
            % Handle calculate button press
            if ~obj.App.dataLoaded
                return
            end
            try
                obj.updateStatus('Calculating changes...');
                obj.CalculateButton.Enable = 'off';
                drawnow;

                % Get selected images
                selectedIndices = obj.getSelectedImageIndices();
                if length(selectedIndices) < 2
                    obj.updateStatus('Error: Select at least 2 images for comparison');
                    obj.CalculateButton.Enable = 'on';
                    return;
                end

                % Get unified parameters
                algorithmType = obj.AlgorithmTypeDropdown.Value;
                scale = obj.ScaleDropdown.Value;
                temporalFilter = obj.TemporalFilterDropdown.Value;

                % Get custom parameter values (always collected, may be overridden by presets)
                thresholdPercent = obj.ThresholdSlider.Value;    % Percentage (1-100)
                blockSizePixels = obj.BlockSizeSlider.Value;     % Absolute pixels (1-100)
                % Area values are now handled via logarithmic conversion

                obj.updateStatus(sprintf('Processing %d images with advanced calculation system', length(selectedIndices)));
                drawnow;

                % Convert UI parameters to format expected by calculateAdvanced
                % Get reference image for dimension calculations
                isInSelection = ismember(obj.App.DifferenceClass.overlay.lastIndices, selectedIndices);
                filteredImages = obj.App.DifferenceClass.overlay.warpedImages(isInSelection);

                if ~isempty(filteredImages)
                    referenceImage = filteredImages{1};
                    [imgHeight, imgWidth] = size(referenceImage, [1, 2]);

                    % Update image dimensions for area scaling
                    obj.currentImageSize = [imgHeight, imgWidth];
                    obj.totalPixels = imgHeight * imgWidth;

                    % Update area slider limits based on actual image size
                    obj.updateAreaSliderLimits();

                    % Convert parameters to absolute values for calculateAdvanced
                    absoluteThreshold = max(0.01, min(1.0, thresholdPercent / 100));
                    absoluteBlockSize = max(1, min(100, ceil(blockSizePixels)));

                    % Convert logarithmic area values to absolute pixel counts
                    absoluteAreaMin = obj.logAreaToPixels(obj.AreaMinSlider.Value);
                    absoluteAreaMax = obj.logAreaToPixels(obj.AreaMaxSlider.Value);

                    % Map algorithmType to type for calculateAdvanced
                    if contains(algorithmType, 'urban')
                        envType = 'urban';
                    elseif contains(algorithmType, 'natural')
                        envType = 'natural';
                    else
                        envType = algorithmType;  % Default for basic algorithms
                    end

                    % Use calculateAdvanced method
                    obj.currentMasks = obj.App.DifferenceClass.calculateAdvanced(...
                        selectedIndices, temporalFilter, envType, absoluteThreshold, absoluteBlockSize, absoluteAreaMin, absoluteAreaMax);
                else
                    error('No images available for calculation');
                end

                % Store advanced calculation results
                obj.currentResults = struct();
                obj.currentResults.indices = selectedIndices;
                obj.currentResults.algorithmType = algorithmType;
                obj.currentResults.environmentType = envType;
                obj.currentResults.parameters = struct(...
                    'threshold', obj.App.DifferenceClass.threshold, ...
                    'blockSize', obj.App.DifferenceClass.blockSize, ...
                    'areaMin', obj.App.DifferenceClass.areaMin, ...
                    'areaMax', obj.App.DifferenceClass.areaMax);
                obj.currentResults.presetDimensions = struct(...
                    'scale', scale, 'temporalFilter', temporalFilter);
                obj.currentResults.customParameters = struct(...
                    'thresholdPercent', thresholdPercent, 'blockSizePixels', blockSizePixels, ...
                    'areaMinPixels', absoluteAreaMin, 'areaMaxPixels', absoluteAreaMax, ...
                    'areaMinLogValue', obj.AreaMinSlider.Value, 'areaMaxLogValue', obj.AreaMaxSlider.Value);

                % Setup mask navigation
                if ~isempty(obj.currentMasks)
                    % Update visualization
                    % Provide detailed status
                    usePresetInfo = {};
                    if ~strcmp(scale, 'Custom'), usePresetInfo{end+1} = sprintf('scale:%s', scale); end
                    if ~strcmp(temporalFilter, 'none'), usePresetInfo{end+1} = sprintf('temporal:%s', temporalFilter); end

                    if ~isempty(usePresetInfo)
                        statusMsg = sprintf('Advanced calculation completed using %s algorithm (env: %s) with presets: %s', ...
                            algorithmType, envType, strjoin(usePresetInfo, ', '));
                    else
                        statusMsg = sprintf('Advanced calculation completed using %s algorithm (env: %s) with custom parameters', ...
                            algorithmType, envType);
                    end
                    obj.updateStatus(statusMsg);
                else
                    obj.updateStatus('No changes detected with current parameters');
                end
                % update view
                obj.CalculateButton.Enable = 'on';
                obj.currentVisualizationMode = "Combined";
                obj.CombinedModeButton.Value = true;
                obj.IndividualModeButton.Value = false;
                obj.onVisualizationChanged();
                obj.update();
                obj.updateAnalysisTab();
            catch exception
                obj.updateStatus(['Calculation error: ' exception.message]);
                obj.currentMasks = {};
                obj.CalculateButton.Enable = 'on';
                drawnow;
            end
        end

        function onClearPressed(obj)
            % Handle clear button press
            obj.currentMasks = [];
            obj.currentResults = [];

            % Clear visualizations
            obj.clearAxes(obj.MainAxes);
            obj.clearAxes(obj.AnalysisAxes);

            title(obj.MainAxes, 'Change Detection Visualization');
            title(obj.AnalysisAxes, 'Change Analysis');

            obj.updateStatus('Results cleared');
        end

        % Note: onToggleImageSelection removed - using tabbed interface now

        function onGroupChanged(obj)
            if ~obj.App.dataLoaded
                return
            end
            % Handle group selection change (like DifferenceView)
            if ~obj.App.OverlayClass.resultAvailable
                return
            end
            obj.group = str2double(obj.GroupDropdown.Value);
            % Get indices of items in selected group
            groupIndices = obj.App.OverlayClass.groups{obj.group};
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
            obj.updateSlider();
            obj.updateVisualization();
        end

        function onClearAll(obj)
            % Clear all checkboxes (like DifferenceView)
            for i = 1:length(obj.Checkboxes)
                if isvalid(obj.Checkboxes(i))
                    obj.Checkboxes(i).Value = false;
                end
            end
            obj.updateStatus('All selections cleared');
        end

        function updateVisualization(obj)
            if ~obj.App.dataLoaded
                return
            end
            obj.clearAxes(obj.MainAxes);
            visualizationType = obj.currentVisualizationMode;
            switch visualizationType
                case 'Individual'
                    obj.blendImages(obj.MainAxes, obj.group);
                case 'Combined'
                    if obj.ImagesCheckbox.Value
                        overlay = obj.App.OverlayClass.getGroupOverlay(obj.group);
                        imshow(overlay, 'Parent', obj.MainAxes);
                    end
                    if obj.MasksCheckbox.Value
                        combinationType = obj.CombinationDropdown.Value;
                        hold(obj.MainAxes, 'on')
                        switch lower(combinationType)
                            case 'heatmap'
                                obj.displayCombinedHeatmap(obj.MainAxes);

                            case 'temporal overlay'
                                obj.displayTemporalOverlay(obj.MainAxes);

                            case 'sum'
                                obj.displayCombinedSum(obj.MainAxes);

                            case 'average'
                                obj.displayCombinedAverage(obj.MainAxes);

                            case 'max'
                                obj.displayCombinedMax(obj.MainAxes);
                        end
                        hold(obj.MainAxes, 'off')
                    end
            end
        end

        %% combined display functions
        function displayCombinedHeatmap(obj, axes)
            % Display combined masks as heatmap using faster maskStack interface

            % Check if maskStack is available
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get number of masks from maskStack
            numMasks = size(obj.App.DifferenceClass.maskStack, 4);

            % Create combined mask by summing all masks in the stack
            combinedMask = sum(double(obj.App.DifferenceClass.maskStack), 4);
            combinedMask = combinedMask / numMasks;  % Normalize by number of masks

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);

            % Explicitly set the color limits to match your normalized data (0 to 1)
            clim(axes, [0, 1]);

            colormap(axes, 'hot');
            cb = colorbar(axes);
            cb.Label.String = 'Normalized Differences';
            title(axes, 'Combined Change Heatmap');

            % Statistics
            totalChanges = sum(combinedMask(:));
            xlabel(axes, sprintf('Total changes: %.0f pixels across %d masks', totalChanges, numMasks));
        end

        function displayTemporalOverlay(obj, axes)
            % Efficient temporal overlay using vectorized operations with colormap

            % Check if maskStack is available
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get mask dimensions and count
            [h, w, ~, numMasks] = size(obj.App.DifferenceClass.maskStack);

            % Create indexed overlay where each mask gets a unique index
            indexedOverlay = zeros(h, w);
            combinedAlpha = zeros(h, w);

            % Process all masks and assign indices
            for i = 1:numMasks
                % Get current mask and convert to double
                currentMask = double(obj.App.DifferenceClass.maskStack(:,:,:,i));
                maskBinary = currentMask(:,:,1) > 0;

                % Assign mask index to pixels (later masks overwrite earlier ones)
                indexedOverlay(maskBinary) = i;

                % Accumulate alpha channel
                combinedAlpha = max(combinedAlpha, currentMask(:,:,1));
            end

            % Display indexed result with colormap
            if any(combinedAlpha(:) > 0)
                % Create colormap with distinct colors for each time period
                if numMasks > 1
                    cmap = lines(numMasks);
                    colormap(axes, cmap);
                    overlayHandle = imagesc(axes, indexedOverlay, [1, numMasks]);
                else
                    % Handle single mask case
                    colormap(axes, 'hot');
                    overlayHandle = imagesc(axes, indexedOverlay);
                end

                set(overlayHandle, 'AlphaData', 0.35 * combinedAlpha);

                % Create custom colorbar with date labels
                if numMasks > 1
                    obj.createTemporalColorbar(axes, numMasks);
                else
                    colorbar(axes);
                end
            end

            title(axes, 'Temporal Change Overlay');
        end

        function displayCombinedSum(obj, axes)
            % Display sum of all masks using maskStack interface

            % Check if maskStack is available
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get number of masks from maskStack
            numMasks = size(obj.App.DifferenceClass.maskStack, 4);

            % Create combined mask by summing all masks in the stack
            combinedMask = sum(double(obj.App.DifferenceClass.maskStack), 4);

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);

            % Set color limits, ensuring the second value is greater than the first
            maxVal = max(combinedMask(:));
            if maxVal > 0
                clim(axes, [0, maxVal]);
            else
                clim(axes, [0, 1]);  % Default range when no changes detected
            end

            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Sum)');
            xlabel(axes, sprintf('Total: %.0f changes across %d masks', sum(combinedMask(:)), numMasks));
        end

        function displayCombinedAverage(obj, axes)
            % Display average of all masks using maskStack interface

            % Check if maskStack is available
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get number of masks from maskStack
            numMasks = size(obj.App.DifferenceClass.maskStack, 4);

            % Create combined mask by averaging all masks in the stack
            combinedMask = sum(double(obj.App.DifferenceClass.maskStack), 4) / numMasks;

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);

            % Set color limits, ensuring the second value is greater than the first
            maxVal = max(combinedMask(:));
            if maxVal > 0
                clim(axes, [0, maxVal]);
            else
                clim(axes, [0, 1]);  % Default range when no changes detected
            end

            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Average)');
            xlabel(axes, sprintf('Average: %.2f changes/mask across %d masks', mean(combinedMask(:)), numMasks));
        end

        function displayCombinedMax(obj, axes)
            % Display maximum of all masks using maskStack interface

            % Check if maskStack is available
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get number of masks from maskStack
            numMasks = size(obj.App.DifferenceClass.maskStack, 4);

            % Create combined mask by taking maximum across all masks in the stack
            combinedMask = max(double(obj.App.DifferenceClass.maskStack), [], 4);

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);

            % Set color limits, ensuring the second value is greater than the first
            maxVal = max(combinedMask(:));
            if maxVal > 0
                clim(axes, [0, maxVal]);
            else
                clim(axes, [0, 1]);  % Default range when no changes detected
            end

            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Maximum)');
            xlabel(axes, sprintf('Max overlap: %d regions across %d masks', sum(combinedMask(:) > 0), numMasks));
        end

        function blendImages(obj, axes, group)
            value = obj.MaskSlider.Value;
            % check whether overlay data is available
            if ~obj.App.OverlayClass.resultAvailable
                % if not, show raw images
                value = round(value);
                imshow(obj.App.OverlayClass.imageArray{value}.data, 'Parent', axes);
                obj.MaskSlider.Value = value;
            else
                % show warped images
                N = size(obj.App.OverlayClass.imageStack{group}, 4);

                % Compute Gaussian weights centered at slider value
                x = 1:N;
                weights = exp(-0.5 * ((x - value) / obj.sigma).^2);
                weights = weights / sum(weights);  % Normalize

                % Blend images
                empty = zeros(size(obj.App.OverlayClass.imageStack{group},1), size(obj.App.OverlayClass.imageStack{group},2), size(obj.App.OverlayClass.imageStack{group},3), 'like', obj.App.OverlayClass.imageStack{group});

                % Always start by clearing the axes
                cla(axes);

                % Display blended images first (if checkbox is selected)
                blended = empty;
                if obj.ImagesCheckbox.Value
                    for i = 1:N
                        blended = blended + weights(i) * obj.App.OverlayClass.imageStack{group}(:,:,:,i);
                    end
                end

                % Overlay the mask on top (if checkbox is selected)
                maskBlended = empty(:,:,1);  % Initialize maskBlended as a single channel
                if obj.MasksCheckbox.Value
                    maskCount = 1;
                    lastMaskIndice = obj.App.DifferenceClass.lastIndices(end);
                    for i = 1:N
                        indice = obj.App.OverlayClass.groups{group}(i);
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
                imshow(blended, 'Parent', axes);
            end
        end

        function displayDifferenceEvolution(obj, axes)
            cla(axes);
            % Combined analysis: Display change magnitude as bar chart with trend line
            % This function combines quantitative analysis (bar chart with percentages)
            % and temporal trend analysis (trend line) in a single comprehensive visualization
            if isempty(obj.App.DifferenceClass.maskStack)
                title(axes, 'No mask data available');
                return;
            end

            % Get number of masks from maskStack
            numMasks = size(obj.App.DifferenceClass.maskStack, 4);

            changeMagnitudes = zeros(1, numMasks);
            changePercentages = zeros(1, numMasks);

            % Get mask dimensions for percentage calculation
            [h, w] = size(obj.App.DifferenceClass.maskStack, [1, 2]);
            maskTotalPixels = h * w;

            % Calculate change magnitude and percentage for each mask
            for i = 1:numMasks
                maskData = obj.App.DifferenceClass.maskStack(:,:,:,i);
                changeMagnitudes(i) = sum(maskData(:));
                changePercentages(i) = (changeMagnitudes(i) / maskTotalPixels) * 100;
            end

            % Create bar chart
            bar(axes, changePercentages);
            hold(axes, 'on');

            % Add trend line if we have enough data points
            if length(changePercentages) > 2
                x = 1:length(changePercentages);
                p = polyfit(x, changePercentages, 1);
                trendline = polyval(p, x);
                plot(axes, x, trendline, '--r', 'LineWidth', 2);
                legend(axes, 'Change Magnitude (%)', 'Trend', 'Location', 'best');
            end

            hold(axes, 'off');

            % Get date labels for x-axis (similar to temporal colorbar)
            if ~isempty(obj.App.DifferenceClass.lastIndices)
                % Get the image array and corresponding dates
                imageArray = obj.App.OverlayClass.imageArray;
                maskIndices = obj.App.DifferenceClass.lastIndices;

                % Extract dates for each mask
                dates = cell(numMasks+1, 1);
                for i = 1:numMasks+1
                    if i <= length(maskIndices) && maskIndices(i) <= length(imageArray)
                        dates{i} = datestr(imageArray{maskIndices(i)}.id, 'mmm yyyy');
                    else
                        dates{i} = sprintf('Mask %d', i);
                    end
                end

                % Set custom x-axis ticks and labels
                axes.XTick = 0.5:numMasks+0.5;
                axes.XTickLabel = dates;
            end

            title(axes, 'Change Magnitude Evolution Over Time');
            xlabel(axes, 'Time Period');
            ylabel(axes, 'Change Area (%)');
            grid(axes, 'on');

            % Add value labels on bars
            for i = 1:length(changePercentages)
                text(axes, i, changePercentages(i) + max(changePercentages)*0.01, ...
                    sprintf('%.2f%%', changePercentages(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8);
            end
        end

        function displayTemporalProfile(obj, axes)
            % Display temporal profile of changes
            if isempty(obj.currentMasks)
                title(axes, 'No masks available');
                return;
            end

            numMasks = length(obj.currentMasks);
            maskTotalPixels = numel(obj.currentMasks{1});

            % Calculate cumulative change
            cumulativeChange = zeros(1, numMasks);
            instantChange = zeros(1, numMasks);

            for i = 1:numMasks
                instantChange(i) = sum(obj.currentMasks{i}(:)) / maskTotalPixels * 100;
                if i == 1
                    cumulativeChange(i) = instantChange(i);
                else
                    cumulativeChange(i) = cumulativeChange(i-1) + instantChange(i);
                end
            end

            yyaxis(axes, 'left');
            plot(axes, 1:numMasks, instantChange, 'o-b', 'LineWidth', 2);
            ylabel(axes, 'Instant Change (%)', 'Color', 'b');

            yyaxis(axes, 'right');
            plot(axes, 1:numMasks, cumulativeChange, 's-r', 'LineWidth', 2);
            ylabel(axes, 'Cumulative Change (%)', 'Color', 'r');

            title(axes, 'Temporal Change Profile');
            xlabel(axes, 'Time Step (Mask Index)');
            grid(axes, 'on');
            legend(axes, 'Instant Change', 'Cumulative Change', 'Location', 'best');
        end

        function displayChangeTimeline(obj, axes)
            % Display change timeline with activity periods
            if isempty(obj.currentMasks)
                title(axes, 'No masks available');
                return;
            end

            numMasks = length(obj.currentMasks);
            maskTotalPixels = numel(obj.currentMasks{1});

            changeMagnitudes = zeros(1, numMasks);
            for i = 1:numMasks
                changeMagnitudes(i) = sum(obj.currentMasks{i}(:)) / maskTotalPixels * 100;
            end

            % Create color-coded timeline
            colors = changeMagnitudes;
            scatter(axes, 1:numMasks, changeMagnitudes, 100, colors, 'filled');
            colormap(axes, 'hot');
            colorbar(axes);

            title(axes, 'Change Activity Timeline');
            xlabel(axes, 'Time Step (Mask Index)');
            ylabel(axes, 'Change Intensity (%)');
            grid(axes, 'on');

            % Add threshold line for significant changes
            if max(changeMagnitudes) > 0
                threshold = mean(changeMagnitudes) + std(changeMagnitudes);
                line(axes, [1, numMasks], [threshold, threshold], ...
                    'Color', 'r', 'LineStyle', '--', 'LineWidth', 1);
                legend(axes, 'Change Points', 'Significance Threshold', 'Location', 'best');
            end
        end

        function updateAnalysisTab(obj)
            % Update the analysis tab with detailed analysis
            if ~obj.App.dataLoaded
                return;
            end

            % Use the new difference evolution display method
            obj.displayDifferenceEvolution(obj.AnalysisAxes);
        end

        function selectedIndices = getSelectedImageIndices(obj)
            % Get indices of selected images from checkboxes (like DifferenceView)
            selectedIndices = [];

            if ~isempty(obj.Checkboxes)
                for i = 1:length(obj.Checkboxes)
                    if isvalid(obj.Checkboxes(i)) && obj.Checkboxes(i).Value
                        selectedIndices(end+1) = i;
                    end
                end
            end

            % Debug output
            if isempty(selectedIndices)
                obj.updateStatus('No images selected. Please select images using checkboxes.');
            else
                obj.updateStatus(sprintf('Selected %d images for processing', length(selectedIndices)));
            end
        end

        function clearCheckboxes(obj)
            % Clear all checkboxes (like DifferenceView)
            for i = 1:length(obj.Checkboxes)
                if isvalid(obj.Checkboxes(i))
                    obj.Checkboxes(i).Value = false;
                end
            end
        end

        function updateImageCheckboxes(obj)
            % Legacy method - now handled by update()
            obj.update();
        end

        function updateStatus(obj, message)
            % Update status in console tab
            if isvalid(obj.StatusTextArea)
                timestamp = datestr(now, 'HH:MM:SS');
                newMessage = sprintf('[%s] %s', timestamp, message);

                % Get current content and add new message
                currentContent = obj.StatusTextArea.Value;
                if isempty(currentContent)
                    obj.StatusTextArea.Value = {newMessage};
                else
                    obj.StatusTextArea.Value = [currentContent; {newMessage}];
                end

                % Auto-scroll to bottom
                drawnow;
            end
        end

        function updateGroups(obj, groups)
            if ~obj.App.OverlayClass.resultAvailable
                obj.GroupDropdown.Items = {''};
                obj.GroupDropdown.Value = {''};  % Default to first group
                obj.GroupDropdown.Enable = 'off';
                return;
            end
            obj.GroupDropdown.Enable = 'on';
            numGroups = numel(groups);
            groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);
            obj.GroupDropdown.Items = groupNames;
            obj.GroupDropdown.Value = groupNames{1};  % Default to first group

            % Attach callback for dropdown selection change (like DifferenceView)
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupChanged();
            obj.onGroupChanged();  % Initialize with first group
        end


        function setVisible(obj, visible)
            obj.Grid.Visible = visible;
        end

        function updateData(obj)
            % Called when new data is loaded
            obj.update();
        end

        function getCurrentPresetDescription(obj)
            % Get a description of the current preset combination
            scale = obj.ScaleDropdown.Value;
            algorithmType = obj.AlgorithmTypeDropdown.Value;
            temporalFilter = obj.TemporalFilterDropdown.Value;

            % Count how many dimensions are set
            activeDimensions = 0;
            if ~strcmp(scale, 'Custom'), activeDimensions = activeDimensions + 1; end
            if ~strcmp(temporalFilter, 'none'), activeDimensions = activeDimensions + 1; end

            % Check if algorithm has optimization
            isOptimized = contains(algorithmType, '_optimized');
            if isOptimized, activeDimensions = activeDimensions + 1; end

            if activeDimensions == 0
                description = sprintf('Algorithm: %s with all custom parameters', algorithmType);
            else
                % Describe active preset combinations
                parts = {};
                if ~strcmp(scale, 'Custom'), parts{end+1} = sprintf('%s scale', scale); end
                if ~strcmp(temporalFilter, 'none'), parts{end+1} = sprintf('%s temporal filter', temporalFilter); end
                if isOptimized, parts{end+1} = 'optimized algorithm'; end

                if ~isempty(parts)
                    description = sprintf('Algorithm: %s with presets: %s', algorithmType, strjoin(parts, ' + '));
                else
                    description = sprintf('Algorithm: %s with custom parameters', algorithmType);
                end
            end

            obj.updateStatus(['Current configuration: ' description]);
        end

        function updateParameterLabelsWithPresetInfo(obj, ~, scale, ~)
            % Update parameter labels with indicators showing which are controlled by presets
            % All parameters now display percentage values
            % Note: Threshold is now always custom (no tempo dimension)

            % Threshold - always custom now (no tempo dimension)
            obj.ThresholdLabel.Text = sprintf('Threshold: %.1f%%', obj.ThresholdSlider.Value);
            obj.ThresholdLabel.FontColor = [0.4, 0.4, 0.4]; % Dark gray for manual control

            % Block Size - controlled by scale dimension (absolute pixels)
            if ~strcmp(scale, 'Custom')
                obj.BlockSizeLabel.Text = sprintf('Block Size: %.0f pixels [%s scale]', obj.BlockSizeSlider.Value, scale);
                obj.BlockSizeLabel.FontColor = [0.2, 0.6, 0.8];
            else
                obj.BlockSizeLabel.Text = sprintf('Block Size: %.0f pixels', obj.BlockSizeSlider.Value);
                obj.BlockSizeLabel.FontColor = [0.4, 0.4, 0.4]; % Dark gray for manual control
            end

            % Area Min - controlled by scale dimension only (now in pixels with logarithmic scale)
            if ~strcmp(scale, 'Custom')
                minPixels = obj.logAreaToPixels(obj.AreaMinSlider.Value);
                minPercent = (minPixels / obj.totalPixels) * 100;
                obj.AreaMinLabel.Text = sprintf('Min Area: %d pixels (%.4f%%) [%s scale]', minPixels, minPercent, scale);
                obj.AreaMinLabel.FontColor = [0.2, 0.6, 0.8]; % Blue for scale control
            else
                obj.updateAreaLabels(); % Use the helper method for manual control
                obj.AreaMinLabel.FontColor = [0.4, 0.4, 0.4]; % Dark gray for manual control
            end

            % Area Max - controlled by scale dimension only (now in pixels with logarithmic scale)
            if ~strcmp(scale, 'Custom')
                maxPixels = obj.logAreaToPixels(obj.AreaMaxSlider.Value);
                maxPercent = (maxPixels / obj.totalPixels) * 100;
                obj.AreaMaxLabel.Text = sprintf('Max Area: %d pixels (%.2f%%) [%s scale]', maxPixels, maxPercent, scale);
                obj.AreaMaxLabel.FontColor = [0.2, 0.6, 0.8]; % Blue for scale control
            else
                % For manual control, the area min label was already updated above
                obj.AreaMaxLabel.FontColor = [0.4, 0.4, 0.4]; % Dark gray for manual control
            end
        end

        % Logarithmic area scaling helper methods
        function pixels = logAreaToPixels(obj, logValue)
            % Convert logarithmic slider value to absolute pixel count
            % logValue range: 0-6 (representing 1 pixel to 50% of image)
            % Formula: pixels = 10^logValue, clamped to [1, totalPixels/2]
            pixels = round(obj.areaSliderLogBase ^ logValue);
            pixels = max(1, min(floor(obj.totalPixels / 2), pixels));
        end

        function logValue = pixelsToLogArea(obj, pixels)
            % Convert absolute pixel count to logarithmic slider value
            % Ensure pixels is at least 1 and at most half the image
            pixels = max(1, min(floor(obj.totalPixels / 25), pixels));
            logValue = log(pixels) / log(obj.areaSliderLogBase);
            logValue = max(0, min(6, logValue));  % Clamp to slider range
        end

        function updateAreaSliderLimits(obj)
            % Update area slider limits and tooltips based on current image size
            if obj.totalPixels > 0
                % Calculate meaningful ranges
                minPixels = 1;                              % Minimum: 1 pixel
                maxPixels = floor(obj.totalPixels / 2);     % Maximum: 50% of image

                % Convert to log scale
                minLog = max(0, obj.pixelsToLogArea(minPixels));
                maxLog = min(6, obj.pixelsToLogArea(maxPixels));

                % Ensure we have at least some range
                if maxLog <= minLog + 1
                    minLog = 0;
                    maxLog = 6;
                end

                % Update slider limits with some buffer
                obj.AreaMinSlider.Limits = [minLog, maxLog - 0.5];  % Leave room for max slider
                obj.AreaMaxSlider.Limits = [minLog + 0.5, maxLog];  % Ensure max > min

                % Clamp current values to new limits
                obj.AreaMinSlider.Value = max(obj.AreaMinSlider.Limits(1), min(obj.AreaMinSlider.Limits(2), obj.AreaMinSlider.Value));
                obj.AreaMaxSlider.Value = max(obj.AreaMaxSlider.Limits(1), min(obj.AreaMaxSlider.Limits(2), obj.AreaMaxSlider.Value));

                % Update tooltips with current image info
                imgPercent = @(pix) (pix / obj.totalPixels) * 100;
                obj.AreaMinSlider.Tooltip = sprintf('Min area: 1 pixel (%.4f%%) to %.0f pixels (%.1f%%) - Image: %dx%d', ...
                    imgPercent(1), obj.logAreaToPixels(maxLog-0.5), imgPercent(obj.logAreaToPixels(maxLog-0.5)), obj.currentImageSize(1), obj.currentImageSize(2));
                obj.AreaMaxSlider.Tooltip = sprintf('Max area: %.0f pixels (%.4f%%) to %.0f pixels (%.1f%%) - Image: %dx%d', ...
                    obj.logAreaToPixels(minLog+0.5), imgPercent(obj.logAreaToPixels(minLog+0.5)), maxPixels, 50, obj.currentImageSize(1), obj.currentImageSize(2));

                % Update labels to show current values
                obj.updateAreaLabels();
            else
                % Use default ranges if no image size available
                obj.AreaMinSlider.Limits = [0, 5];
                obj.AreaMaxSlider.Limits = [1, 6];
                obj.AreaMinSlider.Tooltip = 'Min area: Logarithmic scale (load images to see exact ranges)';
                obj.AreaMaxSlider.Tooltip = 'Max area: Logarithmic scale (load images to see exact ranges)';
            end
        end

        function updateAreaLabels(obj)
            % Update area labels to show both pixels and percentage
            if obj.totalPixels > 0
                minPixels = obj.logAreaToPixels(obj.AreaMinSlider.Value);
                maxPixels = obj.logAreaToPixels(obj.AreaMaxSlider.Value);

                minPercent = (minPixels / obj.totalPixels) * 100;
                maxPercent = (maxPixels / obj.totalPixels) * 100;

                obj.AreaMinLabel.Text = sprintf('Min Area: %d pixels (%.4f%%)', minPixels, minPercent);
                obj.AreaMaxLabel.Text = sprintf('Max Area: %d pixels (%.2f%%)', maxPixels, maxPercent);
            end
        end

        % New TimeSlider-style event handlers
        function onDisplayOptionsChanged(obj)
            % Handle changes to image/mask display checkboxes (immediate update)
            if obj.App.dataLoaded
                obj.updateVisualization();
            end
        end

        function onSigmaSliderChanged(obj)
            % Handle changes to sigma slider for Gaussian blending
            % Convert log slider value to actual sigma (like TimeSliderOverlay)
            obj.sigma = 10^(obj.SigmaSlider.Value);

            % Update label to show current sigma value
            obj.SigmaLabel.Text = sprintf('Blend Amount: %.1f', obj.sigma);

            % Update visualization immediately if in Individual mode
            if obj.App.dataLoaded && strcmp(obj.currentVisualizationMode, 'Individual')
                obj.updateVisualization();
            end
        end
        function createTemporalColorbar(obj, axes, numMasks)
            % Create a colorbar with custom date ticks for temporal overlay
            % Get date information for the masks
            if isempty(obj.App.DifferenceClass.lastIndices) || numMasks == 0
                return;
            end

            % Get the image array and corresponding dates
            imageArray = obj.App.OverlayClass.imageArray;
            maskIndices = obj.App.DifferenceClass.lastIndices;

            % Extract dates for each mask
            dates = cell(numMasks+1, 1);
            for i = 1:numMasks+1
                if i <= length(maskIndices) && maskIndices(i) <= length(imageArray)
                    dates{i} = datestr(imageArray{maskIndices(i)}.id, 'mmm yyyy');
                else
                    dates{i} = sprintf('Mask %d', i);
                end
            end

            % Create colorbar
            cb = colorbar(axes);

            % Set custom ticks and labels
            cb.Ticks = linspace(1, numMasks, numMasks+1);
            cb.TickLabels = dates;
            cb.Label.String = 'Time Periods';
            cb.Label.Color = 'white';
            cb.Label.FontWeight = 'bold';

            % Style the colorbar
            cb.Color = 'white';
            cb.FontSize = 8;
            cb.Location = 'eastoutside';
        end
        function clearAxes(~, axes)
            cb = findall(axes, 'Type', 'ColorBar');
            delete(cb);

            % Now clear the axes as usual
            cla(axes);
        end
    end

    methods (Static)
        function name = getName()
            name = 'DifferenceDetection';
        end
    end
end
