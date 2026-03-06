Screen('CloseAll');
Screen('Preference', 'SkipSyncTests', 1); % For development only

% Open a window on the main screen
screenNumber = max(Screen('Screens'));
[window, rect] = Screen('OpenWindow', screenNumber, [0 0 0]);

disp(['Opened window with pointer: ', num2str(window)]);

Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
ifi = Screen('GetFlipInterval', window);

% Directory containing the videos
videoDir = fullfile(getenv('HOME'), 'toolboxes/fLoc/stimuli/Processed_Videos');
videoFiles = dir(fullfile(videoDir, '*.mp4'));

if isempty(videoFiles)
    error('No .mp4 video files found in: %s', videoDir);
end

% Loop through all videos
for i = 1:length(videoFiles)
    videoPath = fullfile(videoDir, videoFiles(i).name);
    disp(['Now playing: ', videoFiles(i).name]);

    if ~exist(videoPath, 'file')
        warning('File does not exist: %s', videoPath);
        continue;
    end

    % Open and play movie
    [movie, ~, fps, duration, width, height] = Screen('OpenMovie', window, videoPath);
    Screen('PlayMovie', movie, 1);

    % Show video for 2 seconds or until key press
    tStart = GetSecs;
    while ~KbCheck && GetSecs - tStart < 2
        tex = Screen('GetMovieImage', window, movie);
        if tex <= 0
            break;
        end
        Screen('DrawTexture', window, tex);
        Screen('Flip', window);
        Screen('Close', tex);
    end

    % Stop and clean up movie
    Screen('PlayMovie', movie, 0);
    Screen('CloseMovie', movie);
end

% Close screen
Screen('CloseAll');
