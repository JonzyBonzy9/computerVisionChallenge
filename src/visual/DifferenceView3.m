classdef DifferenceView3 < handle
    properties (Access = private)
        App             matlab.apps.AppBase
        dataAvailable

        % Main layout components
        Grid            matlab.ui.container.GridLayout
        TabGroup        matlab.ui.container.TabGroup
        MainTab         matlab.ui.container.Tab
        AnalysisTab     matlab.ui.container.Tab
        StatsTab        matlab.ui.container.Tab
        ConsoleTab      matlab.ui.container.Tab
        individualPanel matlab.ui.container.Panel
        combinedPanel   matlab.ui.container.Panel

        % Visualization components
        MainAxes        matlab.ui.control.UIAxes
        AnalysisAxes    matlab.ui.control.UIAxes
        StatsAxes       matlab.ui.control.UIAxes
        StatusTextArea  matlab.ui.control.TextArea

        % Unified algorithm/type dropdown and visualization controls
        EnvironmentPresetDropdown matlab.ui.control.DropDown
        AlgorithmTypeDropdown   matlab.ui.control.DropDown
        VisualizationDropdown   matlab.ui.control.DropDown
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
        MaskLabel           matlab.ui.control.Label

        % Image selection (checkbox-based like DifferenceView)
        GroupDropdown       matlab.ui.control.DropDown
        RefreshGroupButton  matlab.ui.control.Button
        CheckboxGrid        matlab.ui.container.GridLayout
        Checkboxes          matlab.ui.control.CheckBox

        % Internal state
        currentResults
        currentMasks
        isUpdatingPreset logical  % Flag to prevent recursive updates

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
            obj.dataAvailable = false;
            obj.isUpdatingPreset = false;

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
            obj.updateUI();
            obj.onVisualizationChanged(); % Set initial control visibility
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
                'blockSizePixels', 3, ...       % 3 pixel block size
                'areaMinPixels', 105, ...        % 10 pixels minimum
                'areaMaxPixels', 66000);         % 1000 pixels maximum

            obj.ChangeTypePresets.scale.large = struct(...
                'blockSizePixels', 10, ...      % 10 pixel block size
                'areaMinPixels', 1000, ...       % 100 pixels minimum
                'areaMaxPixels', 100000);        % 10000 pixels maximum

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
            obj.EnvironmentPresets.Urban = struct(...
                'algorithm', 'absdiff', ...             % Simple difference detection for buildings
                'threshold', 20, ...                    % 20% threshold for clear changes
                'blockSize', 1, ...                     % 1 pixel block size for fine detail
                'areaMinPixels', 105, ...               % 105 pixels minimum area (0.0029% for large images)
                'areaMaxPercent', 4, ...                % 4% max area for large structures
                'temporalFilter', 'fast', ...           % Fast temporal processing for urban changes
                'scale', 'medium');                     % Medium spatial scale

            % Natural preset: optimized for natural environments with organic changes
            obj.EnvironmentPresets.Natural = struct(...
                'algorithm', 'texture_change', ...      % Texture-based for natural features
                'threshold', 15, ...                    % 15% threshold (more sensitive for natural changes)
                'blockSize', 5, ...                     % 5 pixel block size for organic textures
                'areaMinPixels', 500, ...               % 500 pixels minimum area (larger organic features)
                'areaMaxPercent', 8, ...                % 8% max area for natural formations
                'temporalFilter', 'medium', ...         % Medium temporal processing for gradual changes
                'scale', 'large');                      % Large spatial scale for natural features
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

            % Statistics tab for quantitative analysis
            obj.StatsTab = uitab(obj.TabGroup, 'Title', 'Statistics');
            obj.StatsAxes = uiaxes(obj.StatsTab);
            title(obj.StatsAxes, 'Change Statistics');

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
            controlTabGroup = uitabgroup(obj.Grid);
            controlTabGroup.Layout.Row = 1;
            controlTabGroup.Layout.Column = 2;            % === IMAGE SELECTION TAB (like DifferenceView) ===
            imageSelectionTab = uitab(controlTabGroup, 'Title', 'Image Selection');

            imageLayout = uigridlayout(imageSelectionTab);
            imageLayout.RowHeight = {'fit', '1x', 'fit'};
            imageLayout.ColumnWidth = {'1x'};
            imageLayout.RowSpacing = 5;
            imageLayout.Padding = [10, 10, 10, 10];

            % Group Selection area with dropdown and refresh button
            groupSelectionGrid = uigridlayout(imageLayout);
            groupSelectionGrid.Layout.Row = 1;
            groupSelectionGrid.RowHeight = {'fit'};
            groupSelectionGrid.ColumnWidth = {'1x', 'fit'};
            groupSelectionGrid.ColumnSpacing = 5;

            obj.GroupDropdown = uidropdown(groupSelectionGrid, ...
                'Items', {'All'}, ...
                'Value', 'All', ...
                'Tooltip', 'Select image group');
            obj.GroupDropdown.Layout.Row = 1;
            obj.GroupDropdown.Layout.Column = 1;

            % Refresh button to re-trigger group selection
            obj.RefreshGroupButton = uibutton(groupSelectionGrid, 'push', ...
                'Text', '↻', ...
                'Tooltip', 'Refresh/Re-apply current group selection', ...
                'FontSize', 12);
            obj.RefreshGroupButton.Layout.Row = 1;
            obj.RefreshGroupButton.Layout.Column = 2;

            % Image Selection checkboxes
            obj.CheckboxGrid = uigridlayout(imageLayout);
            obj.CheckboxGrid.Layout.Row = 2;
            obj.CheckboxGrid.ColumnWidth = {'1x'};
            obj.CheckboxGrid.RowSpacing = 2;

            % Clear all button (like DifferenceView)
            obj.ClearButton = uibutton(imageLayout, 'push', ...
                'Text', 'Clear all', ...
                'FontColor', 'red', ...
                'ButtonPushedFcn', @(btn, evt) obj.clearCheckboxes());
            obj.ClearButton.Layout.Row = 3;

            % === PARAMETERS TAB ===
            parametersTab = uitab(controlTabGroup, 'Title', 'Parameters');

            paramLayout = uigridlayout(parametersTab);
            paramLayout.RowHeight = repmat({'fit'}, 1, 27); % Increased from 25 to 27 rows for environment preset controls
            paramLayout.ColumnWidth = {'1x'};
            paramLayout.RowSpacing = 5;
            paramLayout.Padding = [10, 10, 10, 10];
            paramLayout.Scrollable = 'on';

            currentRow = 1;

            % === Environment Preset Selection ===
            presetLabel = uilabel(paramLayout, 'Text', 'Environment Preset:', 'FontWeight', 'bold');
            presetLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.EnvironmentPresetDropdown = uidropdown(paramLayout, ...
                'Items', {'Custom', 'Urban', 'Natural'}, ...
                'Value', 'Custom', ...
                'Tooltip', 'Select environment-optimized preset configuration');
            obj.EnvironmentPresetDropdown.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === Unified Algorithm/Type Selection ===
            algorithmLabel = uilabel(paramLayout, 'Text', 'Detection Algorithm:', 'FontWeight', 'bold');
            algorithmLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.AlgorithmTypeDropdown = uidropdown(paramLayout, ...
                'Items', {'absdiff', 'gradient', 'ssim', 'dog', 'pca', 'temporal_analysis', 'texture_change', 'edge_evolution', ...
                '--- Environment Optimized ---', 'urban_optimized', 'natural_optimized', 'mixed_optimized'}, ...
                'Value', 'absdiff', ...
                'Tooltip', 'Select detection algorithm or environment-optimized preset');
            obj.AlgorithmTypeDropdown.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === Two-Dimensional Preset System ===
            presetLabel = uilabel(paramLayout, 'Text', 'Change Detection Presets:', 'FontWeight', 'bold');
            presetLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Scale dimension
            scaleLabel = uilabel(paramLayout, 'Text', 'Spatial Scale:');
            scaleLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.ScaleDropdown = uidropdown(paramLayout, ...
                'Items', {'Custom', 'small', 'medium', 'large'}, ...
                'Value', 'Custom', ...
                'Tooltip', 'Select spatial scale of changes');
            obj.ScaleDropdown.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === Custom Parameter Controls ===
            customLabel = uilabel(paramLayout, 'Text', 'Custom Parameters:', 'FontWeight', 'bold');
            customLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Temporal processing (independent control)
            tempProcessLabel = uilabel(paramLayout, 'Text', 'Temporal Processing:');
            tempProcessLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.TemporalFilterDropdown = uidropdown(paramLayout, ...
                'Items', {'none', 'fast', 'medium', 'slow'}, ...
                'Value', 'none', ...
                'Tooltip', 'Apply temporal processing (independent of other parameters)');
            obj.TemporalFilterDropdown.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === Parameter Sliders ===
            slidersLabel = uilabel(paramLayout, 'Text', 'Detection Parameters:', 'FontWeight', 'bold');
            slidersLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Threshold (percentage 0-100%)
            obj.ThresholdLabel = uilabel(paramLayout, 'Text', 'Threshold: 20%');
            obj.ThresholdLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.ThresholdSlider = uislider(paramLayout, 'Limits', [1, 100], 'Value', 20, ...
                'Tooltip', 'Detection threshold as percentage (1-100%)');
            obj.ThresholdSlider.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Block Size (pixels 1-100)
            obj.BlockSizeLabel = uilabel(paramLayout, 'Text', 'Block Size: 3 pixels');
            obj.BlockSizeLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.BlockSizeSlider = uislider(paramLayout, 'Limits', [1, 100], 'Value', 3, ...
                'Tooltip', 'Block size in pixels (1-100)');
            obj.BlockSizeSlider.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Area Min (logarithmic scale - will be updated based on image size)
            obj.AreaMinLabel = uilabel(paramLayout, 'Text', 'Min Area: 100 pixels');
            obj.AreaMinLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.AreaMinSlider = uislider(paramLayout, 'Limits', [0, 4], 'Value', 2, ...
                'Tooltip', 'Minimum change area (logarithmic scale: 1 pixel to 10% of image)');
            obj.AreaMinSlider.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % Area Max (logarithmic scale - will be updated based on image size)
            obj.AreaMaxLabel = uilabel(paramLayout, 'Text', 'Max Area: 10000 pixels');
            obj.AreaMaxLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.AreaMaxSlider = uislider(paramLayout, 'Limits', [1, 6], 'Value', 4, ...
                'Tooltip', 'Maximum change area (logarithmic scale: 10 pixels to 50% of image)');
            obj.AreaMaxSlider.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            % === Action Buttons ===
            buttonsLabel = uilabel(paramLayout, 'Text', 'Actions:', 'FontWeight', 'bold');
            buttonsLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.CalculateButton = uibutton(paramLayout, 'push', ...
                'Text', 'Calculate Changes', ...
                'BackgroundColor', [0.2, 0.6, 0.2]);
            obj.CalculateButton.Layout.Row = currentRow;

            % === VISUALIZATION TAB ===
            visualizationTab = uitab(controlTabGroup, 'Title', 'Visualization');

            visualLayout = uigridlayout(visualizationTab);
            visualLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            visualLayout.ColumnWidth = {'1x'};
            visualLayout.RowSpacing = 5;
            visualLayout.Padding = [10, 10, 10, 10];

            currentRow = 1;

            % === Visualization Type ===
            visualTypeLabel = uilabel(visualLayout, 'Text', 'Visualization Mode:', 'FontWeight', 'bold');
            visualTypeLabel.Layout.Row = currentRow;
            currentRow = currentRow + 1;

            obj.VisualizationDropdown = uidropdown(visualLayout, ...
                'Items', {'Individual', 'Combined'}, ...
                'Value', 'Combined', ...
                'Tooltip', 'Select Individual (slider-based) or Combined visualization');
            obj.VisualizationDropdown.Layout.Row = currentRow;
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
            obj.individualPanel.Visible = 'off';  % Initially hidden
            individualGrid = uigridlayout(obj.individualPanel);
            individualGrid.RowHeight = {'fit', 'fit'};
            individualGrid.ColumnWidth = {'1x'};
            obj.combinedPanel = obj.createSection(visualLayout, 'Combined Mode Controls', currentRow + 2);
            obj.combinedPanel.Visible = 'on';
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
            maskNavLabel = uilabel(individualGrid, 'Text', 'Mask Navigation:', 'FontWeight', 'bold');
            maskNavLabel.Layout.Row = 3;

            obj.MaskLabel = uilabel(individualGrid, 'Text', 'Mask: 1 of 1');
            obj.MaskLabel.Layout.Row = 4;

            obj.MaskSlider = uislider(individualGrid, ...
                'Limits', [1, 2], ...
                'Value', 1, ...
                'MinorTicks', []);
            obj.MaskSlider.Layout.Row = 5;
            obj.MaskSlider.Enable = 'off';

            % === Combined Mode Controls ===
            obj.CombinationDropdown = uidropdown(combinedGrid, ...
                'Items', {'Heatmap', 'Temporal Overlay', 'Sum', 'Average', 'Max'}, ...
                'Value', 'Heatmap', ...
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
            obj.VisualizationDropdown.ValueChangedFcn = @(src, event) obj.onVisualizationChanged();
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

            if strcmp(preset, 'Custom')
                obj.updateStatus('Environment preset set to Custom - manual parameter control');
                return;
            end

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

        function onVisualizationChanged(obj)
            % Handle visualization type change and update control visibility
            visualizationType = obj.VisualizationDropdown.Value;

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
            if obj.dataAvailable
                obj.updateVisualization();
            end
        end

        function onCustomParameterChanged(obj)
            % Update parameter labels and reset dropdowns when manually adjusting
            if ~obj.isUpdatingPreset
                % Manual adjustment - reset preset dropdowns to custom and update labels normally
                obj.EnvironmentPresetDropdown.Value = 'Custom';
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
            if obj.dataAvailable
                obj.updateVisualization();
            end
        end

        function onCalculatePressed(obj)
            % Handle calculate button press
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
                    disp(absoluteAreaMin);
                    disp(absoluteAreaMax);

                    % Map algorithmType to type for calculateAdvanced
                    disp(algorithmType);
                    if contains(algorithmType, 'urban')
                        envType = 'urban';
                    elseif contains(algorithmType, 'natural')
                        envType = 'natural';
                    else
                        envType = algorithmType;  % Default for basic algorithms
                    end
                    disp(envType);

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
                    % Create image and mask stacks for TimeSlider-style blending
                    obj.dataAvailable = true;

                    % Update visualization
                    obj.updateVisualization();

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
                obj.CalculateButton.Enable = 'on';
            catch exception
                obj.updateStatus(['Calculation error: ' exception.message]);
                obj.currentMasks = {};
                obj.dataAvailable = false;
                obj.CalculateButton.Enable = 'on';
                drawnow;
            end
        end

        function onClearPressed(obj)
            % Handle clear button press
            obj.dataAvailable = false;
            obj.currentMasks = [];
            obj.currentResults = [];

            % Clear visualizations
            cla(obj.MainAxes);
            cla(obj.AnalysisAxes);
            cla(obj.StatsAxes);

            title(obj.MainAxes, 'Change Detection Visualization');
            title(obj.AnalysisAxes, 'Change Analysis');
            title(obj.StatsAxes, 'Change Statistics');

            % Reset mask navigation
            obj.MaskSlider.Enable = 'off';
            obj.MaskSlider.Limits = [1, 2];
            obj.MaskSlider.Value = 1;
            obj.MaskLabel.Text = 'Mask: 1 of 1';

            obj.updateStatus('Results cleared');
        end

        % Note: onToggleImageSelection removed - using tabbed interface now

        function onCheckboxChanged(obj, ~)
            % Handle checkbox selection changes (like DifferenceView)
            % Get current checkbox states
            selected = find(arrayfun(@(cb) cb.Value, obj.Checkboxes));

            % Keep only those that were used in last calculation
            validSelection = intersect(selected, obj.App.OverlayClass.lastIndices);

            overlay = obj.App.OverlayClass.createOverlay(validSelection);
            if ~isempty(overlay)
                imshow(overlay, 'Parent', obj.MainAxes);
            else
                cla(obj.MainAxes);  % Clear if overlay couldn't be created
            end
        end

        function onGroupChanged(obj)
            % Handle group selection change (like DifferenceView)
            if isempty(obj.App.OverlayClass.groups)
                return
            end
            group = str2double(obj.GroupDropdown.Value);
            % Get indices of items in selected group
            groupIndices = obj.App.OverlayClass.groups{group};

            % Loop through all checkboxes in the grid and update selection
            for k = 1:numel(obj.Checkboxes)
                if ismember(k, groupIndices)
                    obj.Checkboxes(k).Value = true;
                    obj.Checkboxes(k).Enable = 'on';
                    obj.onCheckboxChanged();
                else
                    obj.Checkboxes(k).Value = false;
                    obj.Checkboxes(k).Enable = 'off';
                    obj.onCheckboxChanged();
                end
            end
            obj.updateSlider();
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
            cla(obj.MainAxes)
            visualizationType = obj.VisualizationDropdown.Value;
            switch visualizationType
                case 'Individual'
                    blendImages(obj.MainAxes, str2double(obj.GroupDropdown.Value));
                case 'Combined'
                    if obj.ImagesCheckbox.Value
                        overlay = obj.App.OverlayClass.createOverlay(obj.App.OverlayClass.lastIndices);
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
            % Display combined masks as heatmap
            combinedMask = zeros(size(obj.currentMasks{1}));
            for i = 1:length(obj.currentMasks)
                combinedMask = combinedMask + double(obj.currentMasks{i});
            end

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);
            colormap(axes, 'hot');
            colorbar(axes);
            title(axes, 'Combined Change Heatmap');

            % Statistics
            totalChanges = sum(combinedMask(:));
            xlabel(axes, sprintf('Total changes: %.0f', totalChanges));
        end

        function displayTemporalOverlay(obj, axes)
            % Overlay all masks with different colors
            colors = lines(length(obj.currentMasks));
            for i = 1:length(obj.currentMasks)
                mask = obj.currentMasks{i};
                if sum(mask(:)) > 0
                    % Create colored overlay
                    [h, w] = size(mask);
                    overlay = zeros(h, w, 3);
                    for c = 1:3
                        overlay(:,:,c) = colors(i,c) * double(mask);
                    end
                    overlayHandle = imagesc(axes, overlay);
                    set(overlayHandle, 'AlphaData', 0.2 * double(mask));
                end
            end
            title(axes, 'Temporal Change Overlay');
        end

        function displayCombinedSum(obj, axes)
            % Display sum of all masks
            combinedMask = zeros(size(obj.currentMasks{1}));
            for i = 1:length(obj.currentMasks)
                combinedMask = combinedMask + double(obj.currentMasks{i});
            end

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);
            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Sum)');
            xlabel(axes, sprintf('Total: %.0f changes', sum(combinedMask(:))));
        end

        function displayCombinedAverage(obj, axes)
            % Display average of all masks
            combinedMask = zeros(size(obj.currentMasks{1}));
            for i = 1:length(obj.currentMasks)
                combinedMask = combinedMask + double(obj.currentMasks{i});
            end
            combinedMask = combinedMask / length(obj.currentMasks);

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);
            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Average)');
            xlabel(axes, sprintf('Average: %.2f changes/frame', mean(combinedMask(:))));
        end

        function displayCombinedMax(obj, axes)
            % Display maximum of all masks
            combinedMask = zeros(size(obj.currentMasks{1}));
            for i = 1:length(obj.currentMasks)
                combinedMask = max(combinedMask, double(obj.currentMasks{i}));
            end

            h = imagesc(axes, combinedMask);
            set(h, 'AlphaData', combinedMask > 0);
            colormap(axes, 'gray');
            colorbar(axes);
            title(axes, 'Combined Changes (Maximum)');
            xlabel(axes, sprintf('Max overlap: %d regions', sum(combinedMask(:) > 0)));
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
            % Display how changes evolve over time
            if isempty(obj.currentMasks)
                title(axes, 'No masks available');
                return;
            end

            % Calculate change magnitude for each mask
            changeMagnitudes = zeros(1, length(obj.currentMasks));
            for i = 1:length(obj.currentMasks)
                changeMagnitudes(i) = sum(obj.currentMasks{i}(:));
            end

            plot(axes, 1:length(changeMagnitudes), changeMagnitudes, 'o-', 'LineWidth', 2, 'MarkerSize', 6);
            title(axes, 'Change Evolution Over Time');
            xlabel(axes, 'Time Step (Mask Index)');
            ylabel(axes, 'Change Magnitude (Pixels)');
            grid(axes, 'on');

            % Add trend line
            if length(changeMagnitudes) > 2
                x = 1:length(changeMagnitudes);
                p = polyfit(x, changeMagnitudes, 1);
                trendline = polyval(p, x);
                hold(axes, 'on');
                plot(axes, x, trendline, '--r', 'LineWidth', 1);
                hold(axes, 'off');
                legend(axes, 'Change Magnitude', 'Trend', 'Location', 'best');
            end
        end

        function displayChangeMagnitude(obj, axes)
            % Display change magnitude as bar chart
            if isempty(obj.currentMasks)
                title(axes, 'No masks available');
                return;
            end

            changeMagnitudes = zeros(1, length(obj.currentMasks));
            changePercentages = zeros(1, length(obj.currentMasks));
            maskTotalPixels = numel(obj.currentMasks{1});

            for i = 1:length(obj.currentMasks)
                changeMagnitudes(i) = sum(obj.currentMasks{i}(:));
                changePercentages(i) = (changeMagnitudes(i) / maskTotalPixels) * 100;
            end

            bar(axes, changePercentages);
            title(axes, 'Change Magnitude by Time Step');
            xlabel(axes, 'Time Step (Mask Index)');
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
            if ~obj.dataAvailable
                return;
            end

            % Use the new difference evolution display method
            obj.displayDifferenceEvolution(obj.AnalysisAxes);
        end

        function updateStatsTab(obj)
            % Update the statistics tab with quantitative analysis
            if ~obj.dataAvailable || isempty(obj.currentMasks)
                return;
            end

            % Use the new change magnitude display method
            obj.displayChangeMagnitude(obj.StatsAxes);
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
            obj.onCheckboxChanged();
        end

        function update(obj)
            % Update view if data is available (like DifferenceView)
            if ~obj.dataAvailable
                return;
            end

            % updated after overlay is calculated
            if obj.App.OverlayClass.resultAvailable
                obj.updateGroups(obj.App.OverlayClass.groups);
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
                    'Value', false, ...
                    'ValueChangedFcn', @(src, evt) obj.onCheckboxChanged(i));
                % Set font color depending on previous use
                if isChecked
                    cb.FontColor = [0, 1, 0];  % green if used in last calculation
                    cb.Enable = true;
                else
                    cb.FontColor = [1, 1, 1];  % White otherwise
                    cb.Enable = false;
                end
                cb.Layout.Row = i;
                obj.Checkboxes(i) = cb;
            end
            obj.updateSlider()
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

        function updateUI(obj)
            % Update UI based on current state
            if isfield(obj.App, 'OverlayClass') && ~isempty(obj.App.OverlayClass.imageArray)
                obj.updateImageCheckboxes();

                % Update group dropdown (like DifferenceView)
                if isfield(obj.App, 'OverlayClass') && ~isempty(obj.App.OverlayClass.groups)
                    obj.updateGroups(obj.App.OverlayClass.groups);
                end

                obj.updateStatus('Ready - Select images and method, then click Calculate Changes');
            else
                obj.updateStatus('Load images first');
            end
        end

        function updateGroups(obj, groups)
            % Update groups dropdown (like DifferenceView)
            numGroups = numel(groups);
            groupNames = arrayfun(@num2str, 1:numGroups, 'UniformOutput', false);
            obj.GroupDropdown.Items = groupNames;

            % Attach callback for dropdown selection change (like DifferenceView)
            obj.GroupDropdown.ValueChangedFcn = @(dd, evt) obj.onGroupChanged();
        end

        % Interface methods for the main app
        function onImLoad(obj)
            % Called when new images are loaded - reset the view completely
            obj.dataAvailable = true; % Set to true like DifferenceView
            obj.currentMasks = [];
            obj.currentResults = [];

            % Clear visualizations
            cla(obj.MainAxes);
            cla(obj.AnalysisAxes);
            cla(obj.StatsAxes);

            title(obj.MainAxes, 'Change Detection Visualization');
            title(obj.AnalysisAxes, 'Change Analysis');
            title(obj.StatsAxes, 'Change Statistics');

            % Reset mask navigation
            obj.MaskSlider.Enable = 'off';
            obj.MaskSlider.Limits = [1, 2];
            obj.MaskSlider.Value = 1;
            obj.MaskLabel.Text = 'Mask: 1 of 1';

            % Reset parameters to defaults (logarithmic scale for areas)
            obj.ThresholdSlider.Value = 20;    % 20% threshold (within [1, 100] range)
            obj.BlockSizeSlider.Value = 3;     % 3 pixels block size (within [1, 100] range)
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

            obj.onCustomParameterChanged();

            % Update UI with new data
            obj.updateUI();
        end

        function show(obj)
            obj.Grid.Visible = 'on';
            obj.CalculateButton.Enable = 'on';
            obj.update();
        end

        function hide(obj)
            obj.Grid.Visible = 'off';
        end

        function setVisible(obj, visible)
            obj.Grid.Visible = visible;
        end

        function updateData(obj)
            % Called when new data is loaded
            obj.updateUI();
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
            if obj.dataAvailable
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
            if obj.dataAvailable && strcmp(obj.VisualizationDropdown.Value, 'Individual')
                obj.updateVisualization();
            end
        end
        function updateSlider(obj)
            if ~obj.App.OverlayClass.resultAvailable
                indices = 1:size(obj.imageStack, 4);
            else
                indices = obj.App.OverlayClass.groups{str2double(obj.GroupDropdown.Value)};
            end

            dates = cellfun(@(s) string(s.id), obj.App.OverlayClass.imageArray(indices));
            N = length(indices);
            obj.MaskSlider.Limits = [1, N];
            obj.MaskSlider.MajorTicks = 1:N;
            obj.MaskSlider.MajorTickLabels = dates;
            obj.MaskSlider.Value = 1;
        end
    end

    methods (Static)
        function name = getName()
            name = 'DifferenceDetection';
        end
    end
end
