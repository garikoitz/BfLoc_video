
function [w, rect, center, screen_num] = do_screen(mode)
% Opens a PTB window on the correct display depending on the setup.
%
%   'lab'  (default) — MRI lab: both screens are merged by the OS into one
%                      virtual desktop (3840x1080). Open on screen 0 at the
%                      right half [1920,0,3840,1080].
%
%   'dev'            — Mac dev setup: Mac 4K as primary, 2K external as the
%                      secondary PTB screen. Open fullscreen on the highest
%                      screen index (the external display).
%
% To switch modes, set  session.screen_mode = 'dev';  in fLocSession.m
% (or in runme.m right after the session is created) before calling run_exp.

if nargin < 1 || isempty(mode)
    mode = 'lab';
end

Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0);

switch lower(mode)

    case 'lab'
        % MRI lab: OS merges both 1920x1080 displays into one 3840x1080 desktop.
        % screen_num=0 sees the full virtual desktop; open a window on the
        % right half so it appears on the projector/second monitor.
        screen_num = 0;
        second_screen_rect = [1920, 0, 3840, 1080];
        [w, rect] = Screen('OpenWindow', screen_num, 128, second_screen_rect);

    case 'dev'
        % Mac development setup: 4K primary + 2K external.
        % PTB assigns separate screen indices; the highest index is the
        % external display. Open fullscreen on that display.
        all_screens = Screen('Screens');
        if length(all_screens) < 2
            warning('do_screen: only one screen found in dev mode — opening on screen 0.');
            screen_num = 0;
        else
            screen_num = max(all_screens);
        end
        [w, rect] = Screen('OpenWindow', screen_num, 128);

    otherwise
        error('do_screen: unknown mode "%s". Use ''lab'' or ''dev''.', mode);
end

center = [rect(1) + (rect(3)-rect(1))/2, rect(2) + (rect(4)-rect(2))/2];

Screen('TextFont', w, 'Times');
Screen('TextSize', w, 24);
Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
HideCursor;

end
