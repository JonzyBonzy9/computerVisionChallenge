classdef Help < handle
    properties (Access = private)
        UIFigure
        HelpHTML
    end

    methods
        function obj = Help(UIFigure)
            % Konstruktor speichert die Referenz zur UIFigure der App
            obj.UIFigure = UIFigure;
        end

        function open(obj)
            if ~isempty(obj.HelpHTML) && isvalid(obj.HelpHTML)
                delete(obj.HelpHTML);
                obj.HelpHTML = [];
                return;
            end

            helpFile = fullfile(pwd, 'help.html');
            if ~isfile(helpFile)
                uialert(obj.UIFigure, 'Hilfedatei nicht gefunden.', 'Fehler');
                return;
            end

            obj.HelpHTML = uihtml(obj.UIFigure, ...
                'HTMLSource', helpFile, ...
                'Position', [100 100 600 400]);

            obj.HelpHTML.DataChangedFcn = @(src, event) obj.closeOnMessage(src, event);
        end

        function close(obj)
            if ~isempty(obj.HelpHTML) && isvalid(obj.HelpHTML)
                delete(obj.HelpHTML);
                obj.HelpHTML = [];
            end
        end
    end

    methods (Access = private)
        function closeOnMessage(obj, src, event)
            disp('Event empfangen:');
            disp(event.Data);
            if isfield(event.Data, 'type') && strcmp(event.Data.type, 'closeHelp')
                obj.close();
            end
        end
    end
end
