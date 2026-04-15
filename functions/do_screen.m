
% use this function for the stimuli display on VGA screen at the MRI
% room

function [w, center] = doScreen
    % Avoid sync test failure during development
    Screen('Preference', 'SkipSyncTests', 1);
    Screen('Preference', 'VisualDebugLevel', 0);

    %Choose the correct screen index: VGA-1 = screen 1
    screen_num = 0;  % Use 0 instead of max(Screen('Screens'))

    % Get full screen dimensions
    %screen_rect = Screen('Rect', screen_num);

    % Define rect for VGA-1 (which starts at x = 1920)
    % second_screen_rect = [1920, 0, 2944, 768];  % 1080 VGA screen size is 1024x768
    % second_screen_rect = [1920, 0, 2944, 600];
    % dev_display_x = 2560;
    % dev_display_y = 1440;
    % stim_display_x = 1024;
    % stim_display_y = 768;
    % second_screen_rect = [dev_display_x - stim_display_x, ...
    %                       0, ...
    %                       dev_display_x, ...
    %                       stim_display_y]; % current resolution is 2560 x 1440
    
    
    % Open the window on the selected screen using its full rect
    [w, rect] = Screen('OpenWindow', screen_num, 128, second_screen_rect);

    % Get center coordinates of the screen
    center = rect(3:4) / 2;

    % Set text properties and blending
    Screen('TextFont', w, 'Times');
    Screen('TextSize', w, 24);
    Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % Hide the mouse cursor
    HideCursor;
end





%{
function [w, center] = doScreen
% Opens a full-screen window, sets text properties, and hides the cursor.
% Written by KGS Lab
% Edited by AS 8/2014




params.BackgroundFullscreenColor = 128; % 0=Black, 255=White
params.calibration      = []; % Was calibrated with Photometer
params.stimSize         = 'max';
params.skipCycleFrames  = 0;
params.display.frameRate         = 60;





params.display.gammaTable = [linspace(0,1,256);linspace(0,1,256);linspace(0,1,256)]';
params.runPriority      =  7;





KbCheck;GetSecs;WaitSecs(0.001);

%try
% check for OpenGL
AssertOpenGL;

% to skip annoying warning message on display (but not terminal)
Screen('Preference', 'Verbosity', 2);
Screen('Preference', 'VisualDebugLevel', 0);
Screen('Preference','SkipSyncTests', 1);

% Open the screen
params.display                = openScreen(params.display);
params.display.devices        = params.devices;

% to allow blending
Screen('BlendFunction', params.display.windowPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);






% open window and find center
%Screen('Preference', 'SkipSyncTests', 1)
%Screen('Preference','VisualDebugLevel', 0)
S = Screen('Screens');
screen_num = max(S);
[w, rect] = Screen('OpenWindow', screen_num);
center = rect(3:4) / 2;

% set text properties
Screen('TextFont', w, 'Times');
Screen('TextSize', w, 24);
Screen('FillRect', w, 128);

% hide cursor
HideCursor;

end
%}






%Use the function below to display the stimuli upstairs

%{
function [w, center] = doScreen
    % Avoid sync test failure during development
    Screen('Preference', 'SkipSyncTests', 1);
    Screen('Preference', 'VisualDebugLevel', 0);

    % Get the full screen size (should be 2944x1080 in your case)
    screen_num = max(Screen('Screens'));
    [total_width, total_height] = Screen('WindowSize', screen_num);

    % Define rect for second monitor (VGA-1 starts at x=1920)
    second_screen_rect = [1920, 0, total_width, total_height];
    %screen_rect = Screen('Rect', screen_num); 

    % Open a window specifically on the second monitor portion
    %[w, rect] = Screen('OpenWindow', screen_num, 128, screen_rect)

    [w, rect] = Screen('OpenWindow', screen_num, 128, second_screen_rect);
    center = rect(3:4) / 2;

    % Text properties and blending
    Screen('TextFont', w, 'Times');
    Screen('TextSize', w, 24);
    Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % Hide mouse
    HideCursor;
end
%}









