classdef calcOverlay
    %CALCOVERLAY Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = public)
        lastIndices
        resultAvailable
        transforms  %% all referenced to first indice image
        imageArray  %% array with id (date) and data field
        warpedImages

        % further public properties
        % e.g. parameters for algorithm
    end
    properties (Access = private)
        % private properties
    end

    methods
        %% constructor
        function obj = calcOverlay(imageArray)
            obj.imageArray = imageArray;
            obj.resultAvailable = false;
        end
        function obj = calculate(obj)
            obj.homographie();
            obj.warp();
            obj.resultAvailable = true;
        end
        function obj = setProperties(obj)
        end
    end

    methods (Access = private)
        function homographie(obj)
        end
        function warp(obj)
        end
    end
end