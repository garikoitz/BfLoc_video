classdef fLocSession

    properties
        name      % participant initials or id string
        date      % session date
        trigger   % option to trigger scanner (0 = no, 1 = yes)
        num_runs  % number of runs in experiment
        sequence  % session fLocSequence object
        responses % behavioral response data structure
        parfiles  % paths to vistasoft-compatible parfiles
        event     % paths to BIDS event.tsv files (added)
        use_eyelink  % option to use EyeLink eye-tracker (0 = no, 1 = yes)
    end

    properties (Hidden)
        stim_set  % stimulus set/s (1 = standard, 2 = alternate, 3 = both)
        task_num  % task number (1 = 1-back, 2 = 2-back, 3 = oddball)
        input     % device number of input used for response collection
        keyboard  % device number of native computer keyboard
        hit_cnt   % number of hits per run
        fa_cnt    % number of false alarms per run
        el            % EyelinkInitDefaults structure (colours, target settings)
        edfFile       % EDF filename used on Host PC (max 8 chars, no extension)
        dummymode     % 0 = real tracker connected, 1 = dummy/no hardware
        el_calib_area % [x y] calibration area proportion — controls tracker zoom.
                      %   [0.477 0.678] -> 1920x1080 projector (default)
                      %   [0.715 0.715] -> 1280x1024 old iMac
                      %   [1.0   1.0  ] -> full screen
    end

    properties (Constant)
        count_down = 12; % pre-experiment countdown (secs)
        stim_size = 768; % size to display images in pixels
    end

    properties (Constant, Hidden)
        task_names = {'1back' '2back' 'oddball'};
        exp_dir = fileparts(fileparts(which(mfilename, 'class')));
        fix_color = [0 255 0];     % normal fixation color (green)
        oddball_color = [255 0 0]; % oddball fixation color (red)
        text_color = 255;          % instruction text color (grayscale)
        blank_color = 128;     % baseline screen color (grayscale)
        wait_dur = 1;          % seconds to wait for response
    end

    properties (Dependent)
        id        % session-specific id string
        task_name % descriptor for each task number
    end

    properties (Dependent, Hidden)
        hit_rate     % proportion of task probes detected in each run
        instructions % task-specific instructions for participant
    end

    methods

        % class constructor
        function session = fLocSession(name, trigger, stim_set, num_runs, task_num, use_eyelink)
            session.name = deblank(name);
            session.trigger = trigger;
            if nargin < 6
                session.use_eyelink = 0;  % default: no eye-tracker
            else
                session.use_eyelink = use_eyelink;
            end
            % Calibration area proportion [x y]: change to control the zoom of
            % the EyeLink calibration grid on the stimulus screen.
            %   [0.477 0.678] -> 1920x1080 MRI projector
            %   [0.715 0.715] -> 1280x1024 iMac
            %   [1.0   1.0  ] -> full screen coverage
            session.el_calib_area = [0.477 0.678];
            if nargin < 3
                session.stim_set = 3;
            else
                session.stim_set = stim_set;
            end
            if nargin < 4
                session.num_runs = 4;
            else
                session.num_runs = num_runs;
            end
            if nargin < 5
                session.task_num = 3;
            else
                session.task_num = task_num;
            end
            session.date = date;
            session.hit_cnt = zeros(1, session.num_runs);
            session.fa_cnt = zeros(1, session.num_runs);
        end

        % get session-specific id string
        % Expects session.name in the format: 'XX_YY_sub-NN_ses-NN'
        %   e.g. 's2_t2_sub-02_ses-02'  ->  id starts with 'sub-02_ses-02_task-BfLocVideo_...'
        % The first two underscore-separated tokens (XX_YY) are used as the
        % short EDF filename on the Host PC (see init_eyelink.m).
        function id = get.id(session)
            parts = split(session.name, '_');
            % this is giving the name of the session under data dir 
            par_str = [parts{3} '_' parts{4} '_task-BfLocVideo_' session.date];
            exp_str = ['Stimset' num2str(session.stim_set) '_' session.task_name '_' num2str(session.num_runs) 'runs'];
            id = [par_str '_' exp_str];
        end

        % get name of task
        function task_name = get.task_name(session)
            task_name = session.task_names{session.task_num};
        end

        % get hit rate for task
        function hit_rate = get.hit_rate(session)
            num_probes = sum(session.sequence.task_probes);
            hit_rate = session.hit_cnt ./ num_probes;
        end

        % get instructions for participant given task
        function instructions = get.instructions(session)
            if session.task_num == 1
                instructions = 'Fixate. Press a button when an image repeats on sequential trials.';
            elseif session.task_num == 2
                instructions = 'Fixate. Press a button when an image repeats with one intervening image.';
            else
                instructions = 'Fixate. Press a button when an oddball appears: a scrambled image or a video with a red cross.';
            end
        end

        % define/load stimulus sequences for this session
        function session = load_seqs(session)
            fname = [session.id '_fLocSequence.mat'];
            fpath = fullfile(session.exp_dir, 'data', session.id, fname);
            % make stimulus sequences if not already defined for session
            if ~exist(fpath, 'file')
                seq = fLocSequence(session.stim_set, session.num_runs, session.task_num, session.exp_dir);
                seq = make_runs(seq);
                mkdir(fileparts(fpath));
                % EDIT seq HERE, so that the videos are 6
                if isempty(seq.all_video_lengths); 
                    error('Could not get video lengths, check code'); 
                end
                seq = edit_videos(seq);
                seq = edit_audios(seq);

                % --- Reassign stimulus numbers for video/audio categories after trimming ---
                % OLD BEHAVIOUR: make_runs() assigned stimulus numbers BEFORE edit_videos /
                % edit_audios ran. Those functions trim each 12-slot block down to 6 clips
                % chosen by duration fit (not randomly), so some stimuli were systematically
                % never shown even though they received a slot number.
                %
                % FIX: reassign fresh numbers here, AFTER trimming, so every surviving slot
                % draws from a fair cycling randperm across all stim_per_set stimuli.
                all_names = seq.stim_names(:);
                is_media  = ~cellfun(@isempty, regexp(all_names, '\.(mp4|wav)$', 'ignorecase'));
                media_idxs = find(is_media);
                if ~isempty(media_idxs)
                    % Extract category (everything before the first '-') for each media slot
                    cats_in_media = cellfun(@(n) n(1 : strfind(n,'-') - 1), ...
                                            all_names(media_idxs), 'UniformOutput', false);
                    unique_media_cats = unique(cats_in_media);
                    for mc = 1:numel(unique_media_cats)
                        cat          = unique_media_cats{mc};
                        cat_slot_idxs = media_idxs(strcmp(cats_in_media, cat));
                        n_cat        = numel(cat_slot_idxs);
                        [~, ~, ext]  = fileparts(all_names{cat_slot_idxs(1)});  % '.mp4' or '.wav'
                        % Cycle through randperm to assign non-repeated numbers fairly
                        n_cycles = ceil(n_cat / seq.stim_per_set);
                        new_nums = repmat(randperm(seq.stim_per_set), 1, n_cycles);
                        new_nums = new_nums(1:n_cat);
                        for kk = 1:n_cat
                            all_names{cat_slot_idxs(kk)} = sprintf('%s-%d%s', cat, new_nums(kk), ext);
                        end
                    end
                    seq.stim_names = reshape(all_names, size(seq.stim_names));
                end
                % --- End reassignment ---

                save(fpath, 'seq', '-v7.3');
            else
                load(fpath);
            end
            session.sequence = seq;
        end

        % register input devices 
        function session = find_inputs(session)
            laptop_key = get_keyboard_num;
            button_key = get_box_num; % NNL scanner trigger (KeyWarrior8 Flex)
            if button_key ~= 0
                session.keyboard = laptop_key;
                session.input = button_key;
            else
                warning('NNL trigger box not found — falling back to laptop keyboard for all input.');
                session.keyboard = laptop_key;
                session.input = laptop_key;
            end
            % Log all connected HID devices for troubleshooting
            fprintf('[MRI] Keyboard device: %d, Input device: %d\n', session.keyboard, session.input);
            d = PsychHID('Devices');
            fprintf('[MRI] All connected HID devices:\n');
            for dd = 1:length(d)
                fprintf('  [%2d] vendorID=%5d  productID=%5d  name="%s"\n', ...
                    dd, d(dd).vendorID, d(dd).productID, d(dd).product);
            end
        end

        % execute a run of the experiment
        function session = run_exp(session, run_num)
            % get timing information and initialize response containers
            session = find_inputs(session);
            % k=-1 tells PTB to merge ALL connected keyboards/input devices into one
            % stream, capturing button box, laptop keyboard, and any other HID device.
            k = -1;  % all devices merged
            sdc = session.sequence.stim_duty_cycle;
            stim_dur = session.sequence.stim_dur;
            isi_dur = session.sequence.isi_dur;
            stim_names   = session.sequence.stim_names(:, run_num);
            stim_onsets  = session.sequence.stim_onsets(:, run_num);  % precomputed absolute onsets
            stim_dir = fullfile(session.exp_dir, 'stimuli');
            tcol = session.text_color; bcol = session.blank_color;
            fcol = session.fix_color;           % green: normal fixation
            oddball_fcol = session.oddball_color; % red: oddball fixation
            run_task_probes = session.sequence.task_probes(:, run_num);
            resp_keys = {}; resp_press = zeros(length(stim_names), 1);
            % setup screen and load all stimuli in run
            [window_ptr, rect, center, screen_num] = do_screen;
            ifi = Screen('GetFlipInterval', window_ptr); % inter-frame interval for scheduling
            center_x = center(1); center_y = center(2); s = session.stim_size / 2;
            stim_rect = [center_x - s center_y - s center_x + s center_y + s];
            % initialize audio
            aud_target_fs = 44100;
            img_ptrs = [];
            aud_data    = cell(length(stim_names), 1);
            aud_fs      = zeros(length(stim_names), 1);  % per-clip sample rate
            aud_players = cell(length(stim_names), 1);   % preloaded audioplayer handles
            aud_bg_ptrs = zeros(length(stim_names), 1);  % background image texture per audio clip
            % preload scrambled images list for audio backgrounds
            scrambled_dir = fullfile(stim_dir, 'scrambled');
            scrambled_files = dir(fullfile(scrambled_dir, '*.jpg'));
            n_scrambled = numel(scrambled_files);
            for ii = 1:length(stim_names)
                if strcmpi(stim_names{ii}, 'baseline')
                    img_ptrs(ii) = 0;
                else
                    [~, ~, ext] = fileparts(stim_names{ii});
                    dashIdx = find(stim_names{ii} == '-', 1);
                    if ~isempty(dashIdx)
                        cat_dir = stim_names{ii}(1:dashIdx-1);
                    else
                        cat_dir = '';
                        warning('Could not determine category for stimulus: %s', stim_names{ii});
                    end
                    full_path = fullfile(stim_dir, cat_dir, stim_names{ii});
                    if ismember(lower(ext), {'.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff'})
                        full_path = fullfile(stim_dir, cat_dir, stim_names{ii});
                        img = imread(full_path);
                        img_ptrs(ii) = Screen('MakeTexture', window_ptr, img);
                    elseif strcmpi(ext, '.mp4')
                        img_ptrs(ii) = -1;  % Flag as video
                    elseif strcmpi(ext, '.wav')
                        img_ptrs(ii) = -2;  % Flag as audio
                        wav_path = fullfile(stim_dir, cat_dir, stim_names{ii});
                        [y, fs] = audioread(wav_path);
                        aud_data{ii} = y;   % samples x channels for audioplayer
                        aud_fs(ii)   = fs;
                        aud_players{ii} = audioplayer(y, fs);
                        % load a random scrambled image as background
                        if n_scrambled > 0
                            rnd_file = scrambled_files(randi(n_scrambled)).name;
                            bg_img = imread(fullfile(scrambled_dir, rnd_file));
                            aud_bg_ptrs(ii) = Screen('MakeTexture', window_ptr, bg_img);
                        end
                    else
                        warning('Unsupported stimulus type: %s', stim_names{ii});
                        img_ptrs(ii) = 0;
                    end
                end
            end

            % --- EyeLink: initialize, calibrate, and start recording ---
            % This block runs (and blocks for calibration) before scanner trigger.
            % The current audio/video/image display logic is completely unchanged;
            % EyeLink messages are fire-and-forget and never block PTB rendering.
            if session.use_eyelink == 1
                [session.el, session.dummymode, session.edfFile] = ...
                    init_eyelink(session, run_num, window_ptr, rect, screen_num, session.el_calib_area);
                Eyelink('SetOfflineMode');  % put tracker in idle before recording
                Eyelink('StartRecording'); % begin eye-movement recording
                WaitSecs(0.05);            % brief pause to ensure recording started
            end

            % start experiment triggering scanner if applicable
            if session.trigger == 0
                Screen('FillRect', window_ptr, bcol);
                Screen('Flip', window_ptr);
                DrawFormattedText(window_ptr, session.instructions, 'center', 'center', tcol);
                Screen('Flip', window_ptr);
                get_key('s', session.keyboard);
            elseif session.trigger == 1
                Screen('FillRect', window_ptr, bcol);
                Screen('Flip', window_ptr);
                DrawFormattedText(window_ptr, session.instructions, 'center', 'center', tcol);
                Screen('Flip', window_ptr);
                while 1
                    get_key('g', session.keyboard);
                    [status, ~] = start_scan;
                    if status == 0
                        break
                    else
                        message = 'Trigger failed.';
                        DrawFormattedText(window_ptr, message, 'center', 'center', fcol);
                        Screen('Flip', window_ptr);
                    end
                end
            end
            % display countdown numbers
            [cnt_time, rem_time] = deal(session.count_down + GetSecs);
            cnt = session.count_down;
            while rem_time > 0
                % --- Escape key check ---
                [~, ~, keyCode] = KbCheck(session.keyboard);
                if keyCode(KbName('ESCAPE'))
                    cleanup_run(img_ptrs, window_ptr);
                    error('Experiment aborted by user (Escape key).');
                end
                if floor(rem_time) <= cnt
                    DrawFormattedText(window_ptr, num2str(cnt), 'center', 'center', tcol);
                    Screen('Flip', window_ptr);
                    cnt = cnt - 1;
                end
                rem_time = cnt_time - GetSecs;
            end

            % Warm up the GPU pipeline with a dummy draw+flip so the first
            % stimulus flip has no extra latency
            Screen('FillRect', window_ptr, bcol);
            Screen('Flip', window_ptr);
            WaitSecs(0.2);

            % Warm up audio output once so the first played clip is not truncated.
            if any(~cellfun(@isempty, aud_players))
                try
                    warmup_tone = zeros(round(0.05 * aud_target_fs), 1);
                    ap_warm = audioplayer(warmup_tone, aud_target_fs);
                    playblocking(ap_warm);
                catch ME
                    warning('Audio warm-up failed: %s', ME.message);
                end
            end

            % main display loop
            start_time = GetSecs;
            if session.use_eyelink == 1
                Eyelink('Message', 'RUN_START run=%d session=%s', run_num, session.id);
            end
            flip_log = nan(length(stim_names), 1);  % record actual flip time of each stimulus
            % Timestamped keylog: one row per press — key name, absolute time, run-relative time, stimulus index, device
            keylog = struct('key', {}, 'time_abs', {}, 'time_rel', {}, 'stim_idx', {}, 'device_id', {});
            for ii = 1:length(stim_names)
                % --- Escape key check ---
                [~, ~, keyCode] = KbCheck(session.keyboard);
                if keyCode(KbName('ESCAPE'))
                    cleanup_run(img_ptrs, window_ptr);
                    error('Experiment aborted by user (Escape key).');
                end
                if strcmpi(stim_names{ii}, 'baseline')
                    t_onset = start_time + stim_onsets(ii);
                    Screen('FillRect', window_ptr, bcol);
                    flip_log(ii) = Screen('Flip', window_ptr, t_onset - ifi/2);
                    if session.use_eyelink == 1
                        Eyelink('Message', 'FIXATION_ONSET trial=%d time_ms=%d', ...
                            ii, round((flip_log(ii) - start_time) * 1000));
                    end
                    WaitSecs('UntilTime', t_onset + sdc);
                    if session.use_eyelink == 1
                        Eyelink('Message', 'FIXATION_OFFSET trial=%d time_ms=%d', ...
                            ii, round((GetSecs - start_time) * 1000));
                    end
                    continue;
                end
                ii_press = []; ii_keys = [];
                if img_ptrs(ii) == -1
                    stim_name = stim_names{ii};
                    video_durs_table = session.sequence.all_video_lengths;
                    idx = find(video_durs_table.Filename == stim_name);
                    if ~any(idx)
                        error('Video not found: %s', stim_name);
                    end
                    video_duration = video_durs_table.Duration_Secs(idx);
                    dash_idx = strfind(stim_name, '-');
                    if isempty(dash_idx)
                        error('Unexpected video filename format: %s', stim_name);
                    end
                    video_cat_folder = stim_name(1:dash_idx(1)-1);
                    moviePath = fullfile(session.exp_dir, 'stimuli', video_cat_folder, stim_name);
                    moviePtr = Screen('OpenMovie', window_ptr, moviePath);
                    Screen('PlayMovie', moviePtr, 1);
                    movieStart = GetSecs;
                    if session.use_eyelink == 1
                        Eyelink('Message', 'VIDEO_ONSET trial=%d/%d name=%s time_ms=%d', ...
                            ii, length(stim_names), stim_names{ii}, ...
                            round((movieStart - start_time) * 1000));
                    end
                    isOddball = (run_task_probes(ii) == 1);
                    draw_oddball_fix = (session.task_num == 3 && isOddball);
                    last_key_down = false;  % debounce state for video keypresses
                    while (GetSecs - movieStart) < video_duration
                        tex = Screen('GetMovieImage', window_ptr, moviePtr, 1);
                        if tex <= 0
                            continue;
                        end
                        Screen('DrawTexture', window_ptr, tex, [], stim_rect);
                        if draw_oddball_fix
                            draw_fixation(window_ptr, center, oddball_fcol);
                        end
                        Screen('Flip', window_ptr);
                        Screen('Close', tex);
                        % Collect keypresses during video playback
                        [key_is_down, t_press, key_code] = KbCheck(k);
                        if key_is_down && ~last_key_down
                            key_name = KbName(key_code);
                            if iscell(key_name); key_name = strjoin(key_name, '+'); end
                            ii_keys{end+1} = key_name; %#ok<AGROW>
                            ii_press(end+1) = 0;        %#ok<AGROW> % mark as pressed
                            keylog(end+1) = struct('key', key_name, 'time_abs', t_press, ...
                                'time_rel', t_press - start_time, 'stim_idx', ii, 'device_id', k); %#ok<AGROW>
                        end
                        last_key_down = key_is_down;
                    end
                    Screen('PlayMovie', moviePtr, 0);
                    Screen('CloseMovie', moviePtr);
                    if session.use_eyelink == 1
                        Eyelink('Message', 'VIDEO_OFFSET trial=%d name=%s time_ms=%d', ...
                            ii, stim_names{ii}, ...
                            round((movieStart + video_duration - start_time) * 1000));
                    end
                    Screen('FillRect', window_ptr, bcol);
                    Screen('Flip', window_ptr);
                    video_isi = session.sequence.video_isis(ii);
                    if video_isi > 0
                        isi_end = movieStart + video_duration + video_isi;
                        [keys, ts, devs, ie] = record_keys_ts(movieStart + video_duration, video_isi, k);
                        WaitSecs('UntilTime', isi_end);
                        ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                        for kk = 1:numel(ts); keylog(end+1) = struct('key', keys{kk}, 'time_abs', ts(kk), 'time_rel', ts(kk)-start_time, 'stim_idx', ii, 'device_id', devs(kk)); end %#ok<AGROW>
                    end
                elseif img_ptrs(ii) == -2
                    % Audio stimulus: show paired background image while playing
                    isOddball = (run_task_probes(ii) == 1);
                    Screen('FillRect', window_ptr, bcol);
                    if aud_bg_ptrs(ii) > 0
                        Screen('DrawTexture', window_ptr, aud_bg_ptrs(ii), [], stim_rect);
                    end
                    if session.task_num == 3 && isOddball
                        draw_fixation(window_ptr, center, oddball_fcol);
                    end
                    Screen('Flip', window_ptr);
                    clip_dur = size(aud_data{ii}, 1) / aud_fs(ii);
                    ap = aud_players{ii};
                    aud_start = GetSecs;
                    play(ap, 1); % start from sample 1 (rewind + play)
                    if session.use_eyelink == 1
                        Eyelink('Message', 'AUDIO_ONSET trial=%d/%d name=%s time_ms=%d', ...
                            ii, length(stim_names), stim_names{ii}, ...
                            round((aud_start - start_time) * 1000));
                    end
                    % Collect responses during clip.
                    % Do NOT call stop(ap) — the ISI can be shorter than
                    % the audio device startup latency, so stopping at
                    % aud_start+clip_dur+aud_isi would cut off the tail.
                    % audioplayer stops automatically when samples run out.
                    [keys, ts, devs, ie] = record_keys_ts(aud_start, clip_dur, k);
                    ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                    for kk = 1:numel(ts); keylog(end+1) = struct('key', keys{kk}, 'time_abs', ts(kk), 'time_rel', ts(kk)-start_time, 'stim_idx', ii, 'device_id', devs(kk)); end %#ok<AGROW>
                    aud_isi = session.sequence.audio_isis(ii);
                    % ISI: flip to blank screen and collect responses
                    Screen('FillRect', window_ptr, bcol);
                    Screen('Flip', window_ptr);
                    [keys, ts, devs, ie] = record_keys_ts(aud_start + clip_dur, aud_isi, k);
                    ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                    for kk = 1:numel(ts); keylog(end+1) = struct('key', keys{kk}, 'time_abs', ts(kk), 'time_rel', ts(kk)-start_time, 'stim_idx', ii, 'device_id', devs(kk)); end %#ok<AGROW>
                    if session.use_eyelink == 1
                        Eyelink('Message', 'AUDIO_OFFSET trial=%d name=%s time_ms=%d', ...
                            ii, stim_names{ii}, ...
                            round((aud_start + clip_dur + aud_isi - start_time) * 1000));
                    end
                else
                    t_onset = start_time + stim_onsets(ii);
                    Screen('DrawTexture', window_ptr, img_ptrs(ii), [], stim_rect);
                    isOddball = (run_task_probes(ii) == 1);
                    if session.task_num == 3 && isOddball
                        draw_fixation(window_ptr, center, oddball_fcol);
                    end
                    flip_log(ii) = Screen('Flip', window_ptr, t_onset - ifi/2);
                    if session.use_eyelink == 1
                        Eyelink('Message', 'IMAGE_ONSET trial=%d/%d name=%s time_ms=%d', ...
                            ii, length(stim_names), stim_names{ii}, ...
                            round((flip_log(ii) - start_time) * 1000));
                    end
                    [keys, ts, devs, ie] = record_keys_ts(t_onset, stim_dur, k);
                    ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                    for kk = 1:numel(ts); keylog(end+1) = struct('key', keys{kk}, 'time_abs', ts(kk), 'time_rel', ts(kk)-start_time, 'stim_idx', ii, 'device_id', devs(kk)); end %#ok<AGROW>
                    if isi_dur > 0
                        Screen('FillRect', window_ptr, bcol);
                        Screen('Flip', window_ptr, t_onset + stim_dur - ifi/2);
                        [keys, ts, devs, ie] = record_keys_ts(t_onset + stim_dur, isi_dur, k);
                        ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                        for kk = 1:numel(ts); keylog(end+1) = struct('key', keys{kk}, 'time_abs', ts(kk), 'time_rel', ts(kk)-start_time, 'stim_idx', ii, 'device_id', devs(kk)); end %#ok<AGROW>
                    end
                    if session.use_eyelink == 1
                        Eyelink('Message', 'IMAGE_OFFSET trial=%d name=%s time_ms=%d', ...
                            ii, stim_names{ii}, ...
                            round((t_onset + stim_dur - start_time) * 1000));
                    end
                end
                resp_keys{ii} = ii_keys;
                if isempty(ii_press)
                    resp_press(ii) = 0;
                else
                    resp_press(ii) = min(ii_press);
                end
            end
            % --- EyeLink: stop recording, close EDF, transfer to display PC ---
            if session.use_eyelink == 1
                Eyelink('Message', 'RUN_END run=%d', run_num);
                Eyelink('StopRecording');
                Eyelink('SetOfflineMode');
                Eyelink('Command', 'clear_screen 0'); % clear Host PC backdrop
                WaitSecs(0.5);                        % allow buffer to flush
                Eyelink('CloseFile');                 % close EDF on Host PC

                % Stop and delete all audioplayer objects before EDF transfer.
                % audioplayer uses Java audio threads; if left running they corrupt
                % the heap inside the EyeLink MEX receive_data_file_feedback()
                % callback, causing abort(). Clearing them joins those threads first.
                for ii_ap = 1:length(aud_players)
                    if ~isempty(aud_players{ii_ap})
                        try; stop(aud_players{ii_ap}); catch; end
                    end
                end
                aud_players = {};
                clear aud_players;
                WaitSecs(0.2); % allow Java audio threads to fully terminate

                transferFile(session, window_ptr, rect(4));
            end

            session.responses(run_num).keys   = resp_keys;
            session.responses(run_num).press  = resp_press;
            session.responses(run_num).keylog = keylog;  % timestamped log: key, time_abs, time_rel, stim_idx

            % Save session immediately so responses are never lost if a later crash occurs
            session_fname = [session.id '_fLocSession.mat'];
            session_fpath = fullfile(session.exp_dir, 'data', session.id, session_fname);
            save(session_fpath, 'session', '-v7.3');

            % --- Block timing diagnostic ---
            block_dur  = session.sequence.stim_per_block * sdc;
            block_onsets_run = session.sequence.block_onsets(:, run_num);
            fprintf('\n=== Run %d block timing (target = %.3f s) ===\n', run_num, block_dur);
            for bb = 1:length(block_onsets_run)
                t_block_start = start_time + block_onsets_run(bb);
                t_block_end   = t_block_start + block_dur;
                % find stimuli belonging to this block
                in_block = (stim_onsets >= block_onsets_run(bb)) & ...
                           (stim_onsets <  block_onsets_run(bb) + block_dur);
                valid_flips = flip_log(in_block & ~isnan(flip_log));
                if isempty(valid_flips)
                    fprintf('  Block %2d (onset=%6.3fs): no image flips logged\n', bb, block_onsets_run(bb));
                else
                    actual_first = valid_flips(1)   - start_time;
                    actual_last  = valid_flips(end)  - start_time;
                    actual_dur   = (t_block_end) - valid_flips(1);
                    fprintf('  Block %2d onset=%6.3fs | first flip=%6.3fs | last flip=%6.3fs | block dur=%.3fs\n', ...
                        bb, block_onsets_run(bb), actual_first, actual_last, actual_dur);
                end
            end
            fprintf('==========================================\n\n');
            fname = [session.id '_backup_run' num2str(run_num) '.mat'];
            fpath = fullfile(session.exp_dir, 'data', session.id, fname);
            save(fpath, 'resp_keys', 'resp_press', 'keylog', '-v7.3');
            session = score_task(session, run_num);
            for i = 1:length(img_ptrs)
                if img_ptrs(i) > 0
                    Screen('Close', img_ptrs(i));
                end
            end
            for i = 1:length(aud_bg_ptrs)
                if aud_bg_ptrs(i) > 0
                    Screen('Close', aud_bg_ptrs(i));
                end
            end
            Screen('FillRect', window_ptr, bcol);
            Screen('Flip', window_ptr);
            DrawFormattedText(window_ptr, 'Thanks, this is the end of this run', 'center', 'center', tcol);
            Screen('Flip', window_ptr);
            get_key('4', session.keyboard);
            ShowCursor;
            Screen('CloseAll');
        end

        % quantify performance in stimulus task
        function session = score_task(session, run_num)
            sdc = session.sequence.stim_duty_cycle;
            fpw = session.wait_dur / sdc;
            resp_presses = session.responses(run_num).press;
            resp_correct = session.sequence.task_probes(:, run_num);
            probe_idxs = find(resp_correct);
            hit_windows = zeros(size(resp_correct));
            for ww = 1:ceil(fpw)
                hit_windows(probe_idxs + ww - 1) = 1;
            end
            hit_resp_windows = resp_presses(hit_windows == 1);
            fa_resp_windows = resp_presses(hit_windows == 0);
            session.hit_cnt(run_num) = sum(max(reshape(hit_resp_windows, fpw, [])));
            session.fa_cnt(run_num) = sum(fa_resp_windows);
        end

        % write vistasoft-compatible parfile for each run
        function session = write_parfiles(session)
            session.parfiles = cell(1, session.num_runs);
            conds = ['Baseline' session.sequence.stim_conds];
            % Auto-generate one distinct color per condition using HSV colormap
            % so we never run out regardless of how many stim_conds exist.
            num_conds = length(conds);
            base_cols = {[1 1 1] [0 0 1] [0 0 0] [1 0 0] [.8 .8 0] [0 1 0] [0.5 0.5 0.5]};
            if num_conds <= length(base_cols)
                cols = base_cols(1:num_conds);
            else
                hsv_cols = hsv(num_conds);
                cols = cell(1, num_conds);
                for cc = 1:num_conds
                    cols{cc} = hsv_cols(cc, :);
                end
            end
            for rr = 1:session.num_runs
                block_onsets = session.sequence.block_onsets(:, rr);
                block_conds = session.sequence.block_conds(:, rr);
                cond_names = conds(block_conds + 1);
                cond_cols = cols(block_conds + 1);
                fname = [session.id '_fLoc_run' num2str(rr) '.par'];
                fpath = fullfile(session.exp_dir, 'data', session.id, fname);
                fid = fopen(fpath, 'w');
                for bb = 1:length(block_onsets)
                    fprintf(fid, '%d \t %d \t', block_onsets(bb), block_conds(bb));
                    fprintf(fid, '%s \t', cond_names{bb});
                    fprintf(fid, '%i %i %i \n', cond_cols{bb});
                end
                fclose(fid);
                session.parfiles{rr} = fpath;
            end
        end

        % write BIDS-compatible events.tsv file for each run
        function session = write_event_tsv(session)
            disp('Writing BIDS-compatible events.tsv files');
            session.event = cell(1, session.num_runs);

            duration = session.sequence.stim_per_block * session.sequence.stim_duty_cycle;

            % build BIDS filename prefix from name parts: XX_YY_sub-NN_ses-NN -> sub-NN_ses-NN_task-BfLocVideo
            name_parts = split(session.name, '_');
            bids_prefix = [name_parts{3} '_' name_parts{4} '_task-BfLocVideo'];

            out_dir = fullfile(session.exp_dir, 'data', session.id);
            if ~exist(out_dir, 'dir'); mkdir(out_dir); end

            for rr = 1:session.num_runs
                block_onsets = session.sequence.block_onsets(:, rr);
                stim_onsets  = session.sequence.stim_onsets(:, rr);
                stim_names   = session.sequence.stim_names(:, rr);

                fname = [bids_prefix '_run-' num2str(rr, '%02d') '_events.tsv'];
                fpath = fullfile(out_dir, fname);

                fid = fopen(fpath, 'w');
                fprintf(fid, 'onset\tduration\ttrial_type\n');
                for bb = 1:length(block_onsets)
                    % find the first stimulus whose onset matches this block start
                    idx = find(abs(stim_onsets - block_onsets(bb)) < 0.01, 1, 'first');
                    if isempty(idx)
                        trial_type = 'baseline';
                    else
                        stim_name = stim_names{idx};
                        dash_pos  = strfind(stim_name, '-');
                        if isempty(dash_pos)
                            trial_type = 'baseline';
                        else
                            trial_type = stim_name(1:dash_pos(1)-1);
                        end
                    end
                    fprintf(fid, '%.2f\t%.2f\t%s\n', block_onsets(bb), duration, trial_type);
                end
                fclose(fid);
                session.event{rr} = fpath;
            end
        end

        % Transfer EDF file from EyeLink Host PC to the Display PC.
        % Transfer EDF file from EyeLink Host PC to the Display PC.
        % Must be called with the PTB window still open — the EyeLink MEX
        % progress callback (receive_data_file_feedback) uses el.window
        % internally and requires a valid open PTB window.
        function transferFile(session, window, height)
            try
                if session.dummymode == 0   % connected to real EyeLink
                    Screen('FillRect', window, session.el.backgroundcolour);
                    Screen('DrawText', window, 'Receiving data file...', 5, height - 35, 0);
                    Screen('Flip', window);
                    fprintf('Receiving data file ''%s.edf''\n', session.edfFile);

                    dst_dir = fullfile(session.exp_dir, 'data', session.id);
                    if ~exist(dst_dir, 'dir'); mkdir(dst_dir); end
                    newName = [session.edfFile, '_', ...
                        char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd_HH-mm')), ...
                        '.edf'];
                    fullDest = fullfile(dst_dir, newName);
                    fprintf('[EDF] Host PC filename : ''%s.edf''\n', session.edfFile);
                    fprintf('[EDF] Destination path : ''%s''\n', fullDest);
                    fprintf('[EDF] Calling Eyelink(''ReceiveFile'', [], dest, 0) ...\n');
                    status = Eyelink('ReceiveFile', [], fullDest, 0);
                    fprintf('[EDF] ReceiveFile returned status = %d\n', status);
                    if status > 0
                        fprintf('[EDF] EDF file size: %.1f KB\n', status / 1024);
                    end
                    fprintf('Data file ''%s'' can be found in ''%s''\n', newName, dst_dir);
                else
                    fprintf('No EDF file saved in Dummy mode\n');
                end
            catch ME
                fprintf('Problem receiving data file ''%s'': %s\n', session.edfFile, ME.message);
                psychrethrow(psychlasterror);
            end
        end

       
    end

end

function cleanup_run(img_ptrs, window_ptr)
% CLEANUP_RUN  Close all textures and PTB screen gracefully.
    try
        for i = 1:length(img_ptrs)
            if img_ptrs(i) > 0
                Screen('Close', img_ptrs(i));
            end
        end
    catch
    end
    try
        ShowCursor;
        Screen('CloseAll');
    catch
    end
end












































