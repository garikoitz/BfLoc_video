
classdef fLocSequence

    properties
        num_runs    % number of runs in experiment
        stim_onsets % onset times of each stimulus in a run
        stim_names  % sequence of stimulus file names
        task_probes % index of stimuli that are task probes
        all_video_lengths % lengths of the videos
        video_isis % calculated isi-s for videos so that all sums 6 secs
        exp_dir
    end

    properties (Hidden)
        stim_set     % stimulus set/s (1 = standard, 2 = alternate, 3 = both)
        task_num     % task number (1 = 1-back, 2 = 2-back, 3 = oddball)
        block_onsets % block onsets relative to beginning of run (seconds)
        block_conds  % block conditions labels
    end

    properties (Constant)
        stim_conds = {'English' 'Chinese' 'Images' 'Videos'};
        stim_per_block = 12;   % stimuli per block
        stim_duty_cycle = 0.5; % duration of stimulus duty cycle (s)
    end

    properties (Constant, Hidden)

        stim_set1 = {'EN_RW' 'CH_RW' 'IMG_RI' 'Processed_Videos'};
        stim_set2 = {'EN_SC' 'CH_SC' 'IMG_SC' 'Scrambled_Processed_Videos'};
        %stim_set3 = [stim_set1, stim_set2];
        % JP
        %stim_set1 = {'body' 'JP_word1' 'adult' 'JP_FF1' 'JP_CB1' 'Processed_Videos'};
        %stim_set2 = {'limb' 'JP_word2' 'child' 'JP_CS1' 'JP_SC1' 'Processed_Videos'};
        % EU
        % stim_set1 = {'body' 'JP_word1' 'adult' 'JP_FF1' 'JP_CB1'};
        % stim_set2 = {'limb' 'JP_word2' 'child' 'JP_CS1' 'JP_SC1'};
        % ES
        % stim_set1 = {'body' 'JP_word1' 'adult' 'JP_FF1' 'JP_CB1'};
        % stim_set2 = {'limb' 'JP_word2' 'child' 'JP_CS1' 'JP_SC1'};
        stim_per_set = 72;
        task_names = {'1back' '2back' 'oddball'};
        task_freq = 0.5;
    end

    properties (Dependent)
        task_name % descriptor for each task number
        run_dur   % run duration (seconds)
        stim_dur  % stimulus duration (seconds)
        isi_dur   % interstimulus interval duration (seconds)
    end

    properties (Dependent, Hidden)
        num_conds % number of conditions in experiment
        run_sets  % stimulus set used in each run
    end

    methods

        % class constructor
        function seq = fLocSequence(stim_set, num_runs, task_num,exp_dir)
            if nargin < 1
                seq.stim_set = 3;
            else
                seq.stim_set = stim_set;
            end
            if nargin < 2
                seq.num_runs = 4;
            else
                seq.num_runs = num_runs;
            end
            if nargin < 3
                seq.task_num = 3;
            else
                seq.task_num = task_num;
            end
            if nargin < 4
                seq.exp_dir = pwd;  % fallback if not passed
            else
                seq.exp_dir = exp_dir;
            end
        end

        % get name of task
        function task_name = get.task_name(seq)
            task_name = seq.task_names{seq.task_num};
        end

        % get run duration given stimulus duty cycle
        function run_dur = get.run_dur(seq)
            block_dur = seq.stim_per_block * seq.stim_duty_cycle;
            blocks_per_run = 1 + (1 + length(seq.stim_conds)) ^ 2 + 1;
            run_dur = block_dur * blocks_per_run;
        end

        % get ISI duration given task
        function isi_dur = get.isi_dur(seq)
            if seq.task_num == 3
                isi_dur = 0;
            else
                isi_dur = 0.1;
            end
        end

        % get stimulus duration given ISI
        function stim_dur = get.stim_dur(seq)
            stim_dur = seq.stim_duty_cycle - seq.isi_dur;
        end

        % get number of experimental conditions including baseline
        function num_conds = get.num_conds(seq)
            num_conds = 1 + length(seq.stim_conds);
        end

        % get image sets for each run given selection
        function run_sets = get.run_sets(seq)
            switch seq.stim_set
                case 1
                    run_sets = repmat(seq.stim_set1, seq.num_runs, 1);
                case 2
                    run_sets = repmat(seq.stim_set2, seq.num_runs, 1);
                case 3
                    % Combine both sets
                    combined_set = [seq.stim_set1, seq.stim_set2];
                    num_categories = numel(seq.stim_set1); 
                    run_sets = cell(seq.num_runs, num_categories);
                    for r = 1:seq.num_runs
                        idx = randperm(numel(combined_set), num_categories);
                        run_sets(r, :) = combined_set(idx);
                    end
                otherwise
                    error('Invalid stim_set argument.');
            end
            
        % Ensure at least one video category is present in every run
        video_cats = {'Processed_Videos', 'Scrambled_Processed_Videos'};
        for r = 1:size(run_sets,1)
            if ~any(ismember(run_sets(r,:), video_cats))
                replace_idx = randi(size(run_sets,2));
                % Insert a sensible default based on the selected stimulus set
                switch seq.stim_set
                    case 1
                        run_sets(r, replace_idx) = {'Processed_Videos'};
                    case 2
                        run_sets(r, replace_idx) = {'Scrambled_Processed_Videos'};
                    otherwise  % stim_set == 3
                        run_sets(r, replace_idx) = video_cats(randi(2));
                end
            end
        end
     end

        % generate randomized stimulus sequences and insert task probes
        function seq = make_runs(seq)
            % --- Setup ---
            num_conds = seq.num_conds;
            stim_per_block = seq.stim_per_block;
            num_runs = seq.num_runs;
            run_sets = seq.run_sets;

            % --- Get block conditions ---
            block_conds = make_orders(num_conds, num_conds, num_runs);
            block_conds = [zeros(1, num_runs); block_conds; zeros(1, num_runs)];
            block_dur = stim_per_block * seq.stim_duty_cycle;
            block_onsets = repmat(0:block_dur:seq.run_dur - block_dur, num_runs, 1)';

            % --- Build stim_mat: category for each stimulus position ---
            stim_mat = cell(stim_per_block, num_conds^2 + 2, num_runs);
            for rr = 1:num_runs
                cat_list = ['baseline' run_sets(rr, :)];
                cat_seq = cat_list(block_conds(:, rr) + 1);
                stim_mat(:, :, rr) = repmat(cat_seq, stim_per_block, 1);
            end
            stim_cat_list = reshape(stim_mat, [], 1);

            % --- Assign stimulus numbers per actual category occurrence ---
            unique_cats = unique(stim_cat_list);
            stim_num_list = cell(size(stim_cat_list));
            for cc = 1:length(unique_cats)
                cat_idxs = find(strcmp(unique_cats{cc}, stim_cat_list));
                n_cat = length(cat_idxs);
                if n_cat <= seq.stim_per_set
                    stim_nums = randperm(seq.stim_per_set, n_cat);
                else
                    stim_nums = [randperm(seq.stim_per_set), randsample(seq.stim_per_set, n_cat - seq.stim_per_set, true)'];
                    
                end
                stim_num_list(cat_idxs) = num2cell(stim_nums(:));
            end

            % --- Build file extensions (image/video) ---
            is_video = contains(stim_cat_list, 'Video', 'IgnoreCase', true);
            file_exts = repmat({'.jpg'}, size(stim_cat_list));
            file_exts(is_video) = {'.mp4'};

            % --- Build full filenames for each stimulus ---
            stim_num_list_fixed = cell(size(stim_cat_list));
            for i = 1:length(stim_cat_list)
                if strcmpi(stim_cat_list{i}, 'baseline')
                    stim_num_list_fixed{i} = '.jpg';
                else
                    stim_num_list_fixed{i} = ['-' num2str(stim_num_list{i}) file_exts{i}];
                end
            end
            stim_list = cellfun(@(X, Y) [X Y], stim_cat_list, stim_num_list_fixed, 'uni', false);
            % insert task probes in randomly-selected stimulus blocks
            probes_per_run = floor(seq.task_freq * seq.num_conds ^ 2);
            if seq.task_num == 2
                probe_pos = randi(seq.stim_per_block - 3, [probes_per_run seq.num_runs]) + 2;
            else
                probe_pos = randi(seq.stim_per_block - 2, [probes_per_run seq.num_runs ]) + 1;
            end
            probe_stim_mat = zeros(seq.stim_per_block, seq.num_conds ^ 2 + 2, seq.num_runs);
            for rr = 1:seq.num_runs
                stim_block_idxs = shuffle(find(block_conds(:, rr) > 0));
                xi = probe_pos(:, rr);
                yi = sort(stim_block_idxs(1:probes_per_run));
                zi = repmat(rr, probes_per_run, 1);
                run_probe_idxs = sub2ind(size(probe_stim_mat), xi, yi, zi);
                probe_stim_mat(run_probe_idxs) = 1;
            end
            probe_stim_idxs = find(probe_stim_mat);
            if seq.task_num == 1
                probe_stim_names = stim_list(probe_stim_idxs - 1);
            elseif seq.task_num == 2
                probe_stim_names = stim_list(probe_stim_idxs - 2);
            else
                
                % Oddball logic for task_num == 3
                % Only the oddball video inserted as a probe in a video block gets '_oddball' appended.
                % This allows display logic to show a green dot only for this video.
                probe_stim_names = cell(size(probe_stim_idxs));
                for j = 1:length(probe_stim_idxs)
                    idx = probe_stim_idxs(j);
                    if contains(stim_list{idx}, '.mp4', 'IgnoreCase', true)
                        % Mark ONLY the oddball video with '_oddball' before the extension
                        [base, ext] = strtok(stim_list{idx}, '.');
                        probe_stim_names{j} = [base '_oddball' ext];
                    else
                        % For image blocks, use a randomly selected valid image from the same category as the oddball
                        % Extract the category from the filename
                        this_cat = regexprep(stim_cat_list{idx}, '-?\d+\.jpg', '');
                        % Find all possible images in this category
                        valid_idxs = find(strcmp(stim_cat_list, this_cat) & ~contains(stim_list, '_oddball') & contains(stim_list, '.jpg'));
                        % Exclude the two images being separated by the oddball, if possible
                        exclude_idxs = [idx-1, idx+1];
                        valid_idxs = setdiff(valid_idxs, exclude_idxs);
                        % Randomly select one
                        if isempty(valid_idxs)
                            % fallback: just pick any image from this category
                            valid_idxs = find(strcmp(stim_cat_list, this_cat) & contains(stim_list, '.jpg'));
                        end
                        rand_idx = valid_idxs(randi(numel(valid_idxs)));
                        % Mark the oddball image with _oddball before the extension
                        [base, ext] = strtok(stim_list{rand_idx}, '.');
                        probe_stim_names{j} = [base '_oddball' ext];
                    
                    end
                end
                
            end
            
            stim_list(probe_stim_idxs) = probe_stim_names;
            stim_names = reshape(stim_list', [], seq.num_runs);
            stim_onsets = repmat(0:seq.stim_duty_cycle:seq.run_dur - seq.stim_duty_cycle, seq.num_runs, 1)';
            task_probes = reshape(probe_stim_mat, [], seq.num_runs);

            flRP = seq.exp_dir;
            % Determine which video folders to scan based on stim_set
            if seq.stim_set == 1
                video_folders = {'Processed_Videos'};
            elseif seq.stim_set == 2
                video_folders = {'Scrambled_Processed_Videos'};
            else  % stim_set == 3
                video_folders = {'Processed_Videos', 'Scrambled_Processed_Videos'};
            end
            all_video_lengths = table();
            for vf = 1:numel(video_folders)
                folder_path = fullfile(flRP, 'stimuli', video_folders{vf});
                if ~isfolder(folder_path)
                    error('Video folder cannot be found: %s', folder_path);
                end
                tmp_tbl = measure_video_length(folder_path);
                all_video_lengths = [all_video_lengths; tmp_tbl]; 
            end

            % Robust check for at least 12 videos in total
            if height(all_video_lengths) < 12
                warning('There are only %d videos across the specified folders. At least 12 are required for a complete video block. Experiment will halt.', height(all_video_lengths));
                error('Not enough videos in specified video folders.');
            end

            % store stimulus sequence parameters
            seq.block_onsets = block_onsets;
            seq.block_conds = block_conds;
            seq.stim_onsets = stim_onsets;
            seq.stim_names = stim_names;
            seq.task_probes = task_probes;
            seq.all_video_lengths = all_video_lengths;
            seq.video_isis = zeros(size(stim_onsets));
        end

    end

end
















































	








 

