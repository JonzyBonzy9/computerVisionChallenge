% Unterstützungsfunktion
function ticks = roundNiceTicks(minVal, maxVal, maxTicks)
    range = maxVal - minVal;
    rawStep = range / (maxTicks - 1);

    % Runde Schrittweite auf eine "schöne" Zahl
    magnitude = 10^floor(log10(rawStep));
    residual = rawStep / magnitude;

    if residual < 1.5
        niceStep = 1 * magnitude;
    elseif residual < 3
        niceStep = 2 * magnitude;
    elseif residual < 7
        niceStep = 5 * magnitude;
    else
        niceStep = 10 * magnitude;
    end

    % Erzeuge die Ticks
    startTick = ceil(minVal / niceStep) * niceStep;
    endTick = floor(maxVal / niceStep) * niceStep;
    ticks = startTick:niceStep:endTick;

    % Sicherheits-Check: falls zu wenig Ticks, dann linspace
    if numel(ticks) < 2
        ticks = linspace(minVal, maxVal, maxTicks);
    end
end