

function draw_fixation(windowPtr, center, color, isGreenCross)
% Draws fixation marker in the center of the window.
% If isGreenCross is true, draws a GREEN fixation cross (for oddball video trials).
% Otherwise, draws a standard fixation cross in the supplied color.
% Usage:
%   draw_fixation(windowPtr, center, color);          % standard cross
%   draw_fixation(windowPtr, center, color, true);   % green cross (oddball)
% Written by KGS Lab, edited by AS 8/2014, updated for oddball video logic

if nargin < 4
    isGreenCross = false;
end
center_x = center(1);
center_y = center(2);

if isGreenCross
    fixColor = [0 255 0];  % bright green
else
    fixColor = color;
end

% draw horizontal bar
Screen('FillRect', windowPtr, fixColor, [center_x - 3 center_y - 2 center_x + 3 center_y + 2]);
% draw vertical bar
Screen('FillRect', windowPtr, fixColor, [center_x - 2 center_y - 3 center_x + 2 center_y + 3]);

end














