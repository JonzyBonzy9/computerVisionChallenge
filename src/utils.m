classdef utils
    methods (Static)
        function date = parseDateFromFilename(filename)
            %PARSEDATEFROMFILENAME Extrahiert Jahr und Monat aus einem Dateinamen.
            %   Unterstützt Formate wie '2024_06.jpg' und '06_2024.jpg'.
            %   Gibt ein datetime-Objekt mit dem 1. des Monats zurück.
            %
            %   Beispiel:
            %       dt = parseDateFromFilename('2024_06.jpg')
            %       dt = parseDateFromFilename('6_2024.jpg')
        
            [~, name, ~] = fileparts(filename);  % Entfernt .jpg
            tokens = regexp(name, '^(\d{4})_(\d{1,2})$', 'tokens');
            if isempty(tokens)
                tokens = regexp(name, '^(\d{1,2})_(\d{4})$', 'tokens');
            end
            if isempty(tokens)
                error('Filename does not match expected format');
            end
            tokens = tokens{1};
            
            if str2double(tokens{1}) > 1900  % Fall: YYYY_MM
                year = str2double(tokens{1});
                month = str2double(tokens{2});
            else  % Fall: MM_YYYY
                month = str2double(tokens{1});
                year = str2double(tokens{2});
            end
            
            date = datetime(year, month, 1);
        end

        function loadImagesFromFolder(app)
            % Ask user to select a folder
            folderPath = uigetdir(pwd, 'Select Folder Containing Images');
            if folderPath == 0
                % User canceled
                return
            end
            
            % Get list of JPG files matching pattern YYYY_MM.jpg
            files = dir(fullfile(folderPath, '*.jpg'));
            
            validFiles = {};
            validDates = datetime.empty(1,0);
        
            for k = 1:length(files)
                fname = files(k).name;
                

                dt = utils.parseDateFromFilename(fname);
                validFiles{end+1} = fullfile(folderPath, fname);
                validDates(end+1) = dt;

            end
            
            if isempty(validFiles)
                uialert(app.UIFigure, 'No valid images found with pattern YYYY_MM.jpg', 'No Images');
                return
            end
            
            % Sort images by date
            [validDates, sortIdx] = sort(validDates);
            validFiles = validFiles(sortIdx);
            
            % Optionally, load images now (or load on demand)
            imgs = cell(1, length(validFiles));
            for k = 1:length(validFiles)
                imgs{k} = imread(validFiles{k});
            end
            
            % Store in app properties
            app.ImageFiles = validFiles;
            app.ImageDates = validDates;
            app.Images = imgs;
            
            % Inform all views
            viewNames = fieldnames(app.Views);
            for k = 1:numel(viewNames)
                app.Views.(viewNames{k}).onImLoad();
            end
            
            % Update the currently selected view
            selected = app.VisualizationStyleDropDown.Value;
            if isfield(app.Views, selected)
                app.Views.(selected).update();
            end   
        end
    end
end