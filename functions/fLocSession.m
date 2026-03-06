


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
    end

    properties (Hidden)
        stim_set  % stimulus set/s (1 = standard, 2 = alternate, 3 = both)
        task_num  % task number (1 = 1-back, 2 = 2-back, 3 = oddball)
        input     % device number of input used for response collection
        keyboard  % device number of native computer keyboard
        hit_cnt   % number of hits per run
        fa_cnt    % number of false alarms per run
    end

    properties (Constant)
        count_down = 12; % pre-experiment countdown (secs)
        stim_size = 768; % size to display images in pixels
    end

    properties (Constant, Hidden)
        task_names = {'1back' '2back' 'oddball'};
        exp_dir = fileparts(fileparts(which(mfilename, 'class')));
        fix_color = [255 0 0]; % fixation marker color (RGB)
        text_color = 255;      % instruction text color (grayscale)
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
        function session = fLocSession(name, trigger, stim_set, num_runs, task_num)
            session.name = deblank(name);
            session.trigger = trigger;
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
        function id = get.id(session)
            par_str = [session.name '_' session.date];
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
                instructions = 'Fixate. Press a button when when an oddball (green dot) image or video appears.';
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
                save(fpath, 'seq', '-v7.3');
            else
                load(fpath);
            end
            session.sequence = seq;
        end

        % register input devices 
        function session = find_inputs(session)
            laptop_key = get_keyboard_num;
            button_key = laptop_key; % get_box_num; % Uncomment and implement get_box_num for MRI response box
            if session.trigger == 1 && button_key ~= 0
                session.keyboard = laptop_key;
                session.input = button_key;
            else
                session.keyboard = button_key;
                session.input = button_key;
            end
            % MRI troubleshooting log
            fprintf('[MRI] Keyboard device: %d, Input device: %d\n', session.keyboard, session.input);
        end

        % execute a run of the experiment
        function session = run_exp(session, run_num)
            % get timing information and initialize response containers
            session = find_inputs(session); k = session.input;
            sdc = session.sequence.stim_duty_cycle;
            stim_dur = session.sequence.stim_dur;
            isi_dur = session.sequence.isi_dur;
            stim_names = session.sequence.stim_names(:, run_num);
            stim_dir = fullfile(session.exp_dir, 'stimuli');
            tcol = session.text_color; bcol = session.blank_color; fcol = session.fix_color;
            resp_keys = {}; resp_press = zeros(length(stim_names), 1);
            % setup screen and load all stimuli in run
            [window_ptr, center] = do_screen;
            center_x = center(1); center_y = center(2); s = session.stim_size / 2;
            stim_rect = [center_x - s center_y - s center_x + s center_y + s];
            img_ptrs = [];
            for ii = 1:length(stim_names)
                if contains(stim_names{ii}, 'baseline')
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
                        img_name = stim_names{ii};
                        if contains(img_name, '_oddball') && strcmpi(lower(ext), '.jpg')
                            img_name = strrep(img_name, '_oddball', '');
                        end
                        full_path = fullfile(stim_dir, cat_dir, img_name);
                        img = imread(full_path);
                        img_ptrs(ii) = Screen('MakeTexture', window_ptr, img);
                    elseif strcmpi(ext, '.mp4')
                        img_ptrs(ii) = -1;  % Flag as video
                    else
                        warning('Unsupported stimulus type: %s', stim_names{ii});
                        img_ptrs(ii) = 0;
                    end
                end
            end

            % start experiment triggering scanner if applicable
            if session.trigger == 0
                Screen('FillRect', window_ptr, bcol);
                Screen('Flip', window_ptr);
                DrawFormattedText(window_ptr, session.instructions, 'center', 'center', tcol);
                Screen('Flip', window_ptr);
                get_key('5', session.keyboard);
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
                if floor(rem_time) <= cnt
                    DrawFormattedText(window_ptr, num2str(cnt), 'center', 'center', tcol);
                    Screen('Flip', window_ptr);
                    cnt = cnt - 1;
                end
                rem_time = cnt_time - GetSecs;
            end

            % main display loop
            start_time = GetSecs;
            for ii = 1:length(stim_names)
                if contains(stim_names{ii}, 'baseline')
                    Screen('FillRect', window_ptr, bcol);
                    draw_fixation(window_ptr, center, fcol);
                    Screen('Flip', window_ptr);
                    WaitSecs(stim_dur);
                    continue;
                end
                if img_ptrs(ii) == -1
                    stim_name = stim_names{ii};
                    if contains(stim_name, '_oddball')
                        [base, ext] = strtok(stim_name, '.');
                        stim_name_for_loading = [erase(base, '_oddball') ext];
                    else
                        stim_name_for_loading = stim_name;
                    end
                    video_durs_table = session.sequence.all_video_lengths;
                    idx = find(video_durs_table.Filename == stim_name_for_loading);
                    if ~any(idx)
                        error('Video not found: %s', stim_name_for_loading);
                    end
                    video_duration = video_durs_table.Duration_Secs(idx);
                    dash_idx = strfind(stim_name_for_loading, '-');
                    if isempty(dash_idx)
                        error('Unexpected video filename format: %s', stim_name_for_loading);
                    end
                    video_cat_folder = stim_name_for_loading(1:dash_idx(1)-1);
                    moviePath = fullfile(session.exp_dir, 'stimuli', video_cat_folder, stim_name_for_loading);
                    moviePtr = Screen('OpenMovie', window_ptr, moviePath);
                    Screen('PlayMovie', moviePtr, 1);
                    movieStart = GetSecs;
                    while (GetSecs - movieStart) < video_duration
                        tex = Screen('GetMovieImage', window_ptr, moviePtr, 1);
                        if tex <= 0
                            continue;
                        end
                        Screen('DrawTexture', window_ptr, tex, [], stim_rect);
                        [~, ~, ext] = fileparts(stim_names{ii});
                        isOddballVideo = contains(stim_names{ii}, '_oddball') && strcmpi(lower(ext), '.mp4');
                        draw_fixation(window_ptr, center, fcol, isOddballVideo);
                        Screen('Flip', window_ptr);
                        Screen('Close', tex);
                    end
                    Screen('PlayMovie', moviePtr, 0);
                    Screen('CloseMovie', moviePtr);
                    WaitSecs(session.sequence.video_isis(ii));
                else
                    Screen('DrawTexture', window_ptr, img_ptrs(ii), [], stim_rect);
                    [~, ~, ext] = fileparts(stim_names{ii});
                    isOddballImage = contains(stim_names{ii}, '_oddball') && strcmpi(lower(ext), '.jpg');
                    draw_fixation(window_ptr, center, fcol, isOddballImage);
                    Screen('Flip', window_ptr);
                    WaitSecs(stim_dur);
                end
                ii_press = []; ii_keys = [];
                [keys, ie] = record_keys(start_time + (ii - 1) * sdc, stim_dur, k);
                ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                if isi_dur > 0
                    Screen('FillRect', window_ptr, bcol);
                    draw_fixation(window_ptr, center, fcol);
                    [keys, ie] = record_keys(start_time + (ii - 1) * sdc + stim_dur, isi_dur, k);
                    ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                    Screen('Flip', window_ptr);
                end
                resp_keys{ii} = ii_keys;
                resp_press(ii) = min(ii_press);
            end
            session.responses(run_num).keys = resp_keys;
            session.responses(run_num).press = resp_press;
            fname = [session.id '_backup_run' num2str(run_num) '.mat'];
            fpath = fullfile(session.exp_dir, 'data', session.id, fname);
            save(fpath, 'resp_keys', 'resp_press', '-v7.3');
            session = score_task(session, run_num);
            num_probes = num2str(sum(session.sequence.task_probes(:, run_num)));
            hit_cnt = num2str(session.hit_cnt(run_num));
            fa_cnt = num2str(session.fa_cnt(run_num));
            hit_rate = num2str(session.hit_rate(run_num) * 100);
            hit_str = ['Hits: ' hit_cnt '/' num_probes ' (' hit_rate '%)'];
            fa_str = ['False alarms: ' fa_cnt];
            for i = 1:length(img_ptrs)
                if img_ptrs(i) > 0
                    Screen('Close', img_ptrs(i));
                end
            end
            Screen('FillRect', window_ptr, bcol);
            Screen('Flip', window_ptr);
            score_str = [hit_str '\n' fa_str];
            DrawFormattedText(window_ptr, score_str, 'center', 'center', tcol);
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
            cols = {[1 1 1] [0 0 1] [0 0 0] [1 0 0] [.8 .8 0] [0 1 0] [0.5 0.5 0.5]};
            for rr = 1:session.num_runs
                block_onsets = session.sequence.block_onsets(:, rr);
                block_conds = session.sequence.block_conds(:, rr);
                if max(block_conds + 1) > length(cols)
                    error('block_conds index exceeds number of defined condition colors.');
                end
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

         % write vistasoft-compatible event.tsv file for each run
        function session = write_event_tsv(session)
            disp('Start writing vistasoft-compatible event.tsv files');
            session.event = cell(1, session.num_runs);

            % Define condition/category names and block duration
            conds = ['Baseline' session.sequence.stim_conds];
            stim_cat = ['baseline' session.sequence.stim_set1];
            duration = session.sequence.stim_per_block * session.sequence.stim_duty_cycle;

            for rr = 1:session.num_runs
                block_onsets = session.sequence.block_onsets(:, rr);
                block_conds = session.sequence.block_conds(:, rr);
                cond_names = stim_cat(block_conds + 1);

                % Create a filename using session id and run number
                parts_id = split(session.id, '_');
                fname = [parts_id{1} '_' parts_id{2} '_' parts_id{3} '_run-' num2str(rr, '%02d') '_events.tsv'];
                fpath = fullfile(session.exp_dir, 'data', session.id, fname);

                fid = fopen(fpath, 'w');
                fprintf(fid, 'onset\tduration\ttrial_type\n');
                for bb = 1:length(block_onsets)
                    fprintf(fid, '%.2f\t%d\t%s\n', block_onsets(bb), duration, cond_names{bb});
                end
                fclose(fid);
                session.event{rr} = fpath;
            end
        end

       
    end

end












































