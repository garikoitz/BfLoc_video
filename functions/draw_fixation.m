

function draw_fixation(windowPtr, center, color)
% Draws fixation cross in the center of the window in the supplied color.
% Normal trials: pass green [0 255 0]; oddball trials: pass red [255 0 0].
% Written by KGS Lab, edited by AS 8/2014

center_x = center(1);
center_y = center(2);

r = 10;
Screen('FillOval', windowPtr, color, [center_x-r center_y-r center_x+r center_y+r]);

end














