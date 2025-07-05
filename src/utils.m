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

        function imageArray = loadImagesFromFolder()
            % Ask user to select a folder
            folderPath = uigetdir(pwd, 'Select Folder Containing Images');
            if folderPath == 0
                imageArray = [];
                return;
            end
        
            % Get list of JPG files matching pattern YYYY_MM.jpg
            files = dir(fullfile(folderPath, '*.jpg'));
            
            validFiles = {};
            validDates = datetime.empty(1, 0);
        
            for k = 1:length(files)
                fname = files(k).name;
                dt = utils.parseDateFromFilename(fname);
                if isempty(dt)
                    continue;
                end
                validFiles{end+1} = fullfile(folderPath, fname);
                validDates(end+1) = dt;
            end
        
            if isempty(validFiles)
                imageArray = [];
                imageFiles = [];
                return;
            end
        
            % Sort by date
            [validDates, sortIdx] = sort(validDates);
            validFiles = validFiles(sortIdx);
        
            % Load images
            imgs = cell(1, length(validFiles));
            for k = 1:length(validFiles)
                imgs{k} = imread(validFiles{k});
            end
        
            % Create output image array
            imageArray = cell(1, length(validDates));
            for k = 1:length(validDates)
                imageStruct.data = imgs{k};
                imageStruct.id = validDates(k);
                imageArray{k} = imageStruct;
            end
        end
    end
end