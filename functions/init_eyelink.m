function [el, dummymode, edfFile] = init_eyelink(session, run_num, window, rect, screenNumber, calib_area_proportion)
% INIT_EYELINK  Initialize EyeLink connection for a BfLoc_video run.
%
%   [el, dummymode, edfFile] = init_eyelink(session, run_num, window, rect,
%                                            screenNumber, calib_area_proportion)
%
%   Inputs
%   ------
%   session               : fLocSession object (needs session.name, session.exp_dir)
%   run_num               : current run number (integer)
%   window                : PTB window pointer
%   rect                  : PTB window rect  [0 0 width height]
%   screenNumber          : PTB screen number (0 in BfLoc_video / do_screen.m)
%   calib_area_proportion : [x y] proportion of screen to calibrate over.
%                           Controls the "zoom" of the calibration grid.
%                           Examples:
%                             [0.477 0.678]  -> 1920x1080 projector (default)
%                             [0.715 0.715]  -> 1280x1024 old iMac
%                             [1.0   1.0  ]  -> full screen
%                           Set this in session.el_calib_area before calling run_exp.
%
%   Outputs
%   -------
%   el         : EyelinkInitDefaults structure (colours, target settings, etc.)
%   dummymode  : 0 = real EyeLink connected, 1 = dummy/no hardware
%   edfFile    : EDF filename used on the Host PC (max 8 chars, no extension)

    %% STEP 1: INITIALIZE EYELINK CONNECTION
    % dummymode = 0  -> try to connect to real tracker
    % dummymode = 1  -> run without hardware (for testing)
    dummymode = 0;

    % Optional: set a non-default Host PC IP address before connecting.
    % Eyelink('SetAddress', '100.1.1.1');

    EyelinkInit(dummymode); % initialize EyeLink connection
    status = Eyelink('IsConnected');
    if status < 1   % if not connected, fall back to dummy mode
        dummymode = 1;
        warning('EyeLink not connected — running in dummy mode.');
    end

    %% Build EDF filename (max 8 chars: letters, digits, underscores — Host PC limit)
    %
    % Session name convention:  'XX_YY_sub-NN_ses-NN'
    %   e.g.  's2_t2_sub-02_ses-02'
    %
    % Mapping to short Host PC name (same logic as BfLoc votclocSession):
    %   1. Take first 5 chars of name      -> 's2_t2'
    %   2. Append '_' + run_num            -> 's2_t2_1'  (7 chars, ≤8 ✓)
    %                                         's2_t2_10' (8 chars, ≤8 ✓)
    %
    % The timestamped copy on disk is named: edfFile_yyyy-MM-dd_HH-mm.edf
    %   e.g.  s2_t2_1_2026-04-25_14-30.edf
    %
    % EDF filename: take first 5 characters of session.name as the subject token.
    % With names like 's2_t2_sub-02_ses-02', this gives 's2_t2' (5 chars),
    % and edfFile becomes 's2_t2_1' (7 chars) -- safely within the 8-char limit.
    session_name = session.name(1:5);
    new_name = sprintf('%s_%d', session_name, run_num);
    edfFile = new_name;
    if length(edfFile) > 8
        fprintf('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)\n');
        error('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)');
    end
    fprintf('Host PC EDF filename: ''%s.edf''\n', edfFile);

    %% Open EDF file on Host PC
    failOpen = Eyelink('OpenFile', edfFile);
    if failOpen ~= 0
        error('Cannot create EDF file ''%s'' on EyeLink Host PC.', edfFile);
    end

    %% STEP 2: SELECT SAMPLE / EVENT DATA TO SAVE
    % Get tracker version so we know whether HTARGET (head-target sticker) data
    % is available (EyeLink 1000+, Portable Duo).
    ELsoftwareVersion = 0;
    [ver, versionstring] = Eyelink('GetTrackerVersion');
    if dummymode == 0
        [~, vnumcell] = regexp(versionstring, '.*?(\d)\.\d*?', 'Match', 'Tokens');
        ELsoftwareVersion = str2double(vnumcell{1}{1});
        fprintf('Running on %s version %d\n', versionstring, ver);
    end

    % Write session preamble into EDF (visible in DataViewer Inspector)
    preambleText = sprintf('RECORDED BY BfLoc_video | session: %s | edfFile: %s', ...
        session.name, edfFile);
    Eyelink('Command', 'add_file_preamble_text "%s"', preambleText);

    % Events saved to EDF
    Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    % Events available online (gaze-contingent use)
    Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
    % Samples saved to EDF
    if ELsoftwareVersion > 3
        Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
        Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
    else
        Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,GAZERES,BUTTON,STATUS,INPUT');
        Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
    end

    %% STEP 3: CALIBRATION DEFAULTS, COLOURS, AND TARGET SETTINGS
    el = EyelinkInitDefaults(window);

    % Background and target colours — keep close to experiment background (128 grey)
    el.backgroundcolour        = [128 128 128]; % match blank_color in fLocSession
    el.calibrationtargetcolour = [0   0   0  ]; % black target
    el.calibrationtargetsize   = 3;             % outer target size (% of screen)
    el.calibrationtargetwidth  = 0.7;           % inner dot size   (% of screen)
    el.msgfontcolour           = [0   0   0  ]; % instruction text on Host PC

    % Use a fixation image instead of the default bull's-eye target.
    % If fixTarget.jpg does not exist the default target will be used automatically.
    fixTargetPath = fullfile(session.exp_dir, 'stimuli', 'fixTarget.jpg');
    if exist(fixTargetPath, 'file')
        el.calTargetType           = 'image';
        el.calImageTargetFilename  = fixTargetPath;
    end

    % Silence calibration beeps (set to 1 to re-enable)
    el.targetbeep   = 0;
    el.feedbackbeep = 0;

    EyelinkUpdateDefaults(el);

    %% STEP 4: SCREEN GEOMETRY & CALIBRATION GRID
    width  = rect(3);
    height = rect(4);

    % Tell the Host PC the pixel coordinates of the stimulus screen.
    % This is critical so DataViewer overlays gaze correctly on stimuli.
    Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
    Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);

    % Calibration grid: HV13 = 13-point horizontal-vertical grid (most accurate)
    Eyelink('Command', 'calibration_type = HV13');

    % --- ZOOM / CALIBRATION AREA CONTROL ---
    % calib_area_proportion [x y] sets what fraction of the screen the
    % calibration dots are spread over.  Smaller values = dots more central
    % (useful when the projector only illuminates part of the screen, or when
    % you want calibration to focus on the stimulus region).
    %   [0.477 0.678]  typical for 1920x1080 MRI projector
    %   [0.715 0.715]  typical for 1280x1024 iMac
    %   [1.0   1.0  ]  full screen (maximum spread)
    if nargin < 6 || isempty(calib_area_proportion)
        calib_area_proportion = [0.477 0.678]; % safe default for 1920x1080
    end
    Eyelink('Command', sprintf('calibration_area_proportion = %.4f %.4f', ...
        calib_area_proportion(1), calib_area_proportion(2)));
    Eyelink('Command', sprintf('validation_area_proportion  = %.4f %.4f', ...
        calib_area_proportion(1), calib_area_proportion(2)));
    fprintf('Calibration area proportion set to [%.4f  %.4f]\n', ...
        calib_area_proportion(1), calib_area_proportion(2));

    % Allow the button box (button 5) to accept calibration targets
    Eyelink('Command', 'button_function 5 "accept_target_fixation"');

    %% STEP 5: CALIBRATE
    HideCursor(screenNumber);
    ListenChar(-1); % suppress keypresses going to MATLAB windows
    Eyelink('Command', 'clear_screen 0');
    Screen('FillRect', window, el.backgroundcolour);
    EyelinkDoTrackerSetup(el);  % opens Host PC camera + calibration GUI

    disp("eyelink initialized ");
end
