function seq = edit_videos(seq)
% edit_videos Edit seq so that it calculates video sequence and onsets

    all_video_lengths = seq.all_video_lengths;

    % Detect the video onsets and stimuli to go from 12 to 6
    how_many_stims = size(seq.stim_names, 1);
    how_many_videos = length(find(~cellfun(@isempty, strfind(seq.stim_names(:,1), 'Video'))));
    new_how_many_videos = round(how_many_stims - how_many_videos / 2); 

    % Preallocate per-run cell containers
    new_stim_names = cell(1, seq.num_runs);
    new_stim_onsets = cell(1, seq.num_runs);
    new_task_probes = cell(1, seq.num_runs);
    new_videos_isis = cell(1, seq.num_runs);

    isi = seq.isi_dur;

    for rr = 1:seq.num_runs
        % Extract run-specific data
        stim_names = seq.stim_names(:, rr);
        stim_onsets = seq.stim_onsets(:, rr);
        task_probes = seq.task_probes(:, rr);
        old_videos_isis = isi * ones(size(task_probes));

        video_ind = find(~cellfun(@isempty, strfind(stim_names, 'Video')));

        n_complete_blocks = floor(length(video_ind) / 12);
        if n_complete_blocks == 0
            disp('DEBUG: Contents of stim_names for this run:');
            disp(stim_names');

            error('No complete video blocks found (need at least 12 videos)');
        end
        video_ind = video_ind(1 : n_complete_blocks * 12);  % Trim incomplete block

        % Accumulate indices and durations to keep
        all_video_ind_to_remove = [];
        all_video_ind_to_keep = [];
        all_video_length_to_keep = [];
        new_isis = [];

        for nb = 1:n_complete_blocks
            % Block indices
            block_vids = video_ind(12 * (nb - 1) + (1:12));
            queryStrings = stim_names(block_vids);
            all_times = nan(size(queryStrings));

            for k = 1:numel(queryStrings)
                rowIdx = find(matches(all_video_lengths.Filename, queryStrings{k}), 1); % Find first match
                if ~isempty(rowIdx)
                    all_times(k) = all_video_lengths.Duration_Secs(rowIdx);
                end
            end

            % Select 6 videos that sum close to 6 seconds
            targetTotal = 6; % secs
            nSelect = 6;
            fill_strategy = 'more_isi'; % 'more_videos' or 'more_isi'
            [videos, new_isi] = find_video_combination(all_times, targetTotal, nSelect, isi, fill_strategy);

            % --- guarantee that the oddball video is kept ---
            oddball_idx_in_block = find(contains(queryStrings, '_oddball'));
           
            if ~isempty(oddball_idx_in_block)
                if ~ismember(oddball_idx_in_block, videos)
                    
                    videos(end) = oddball_idx_in_block;
                end
            end

            videos_to_remove = block_vids(~ismember(1:numel(block_vids), videos));
            all_video_ind_to_remove = [all_video_ind_to_remove; videos_to_remove];
            all_video_ind_to_keep = [all_video_ind_to_keep; block_vids(videos)];
            all_video_length_to_keep = [all_video_length_to_keep; all_times(videos)];
            new_isis = [new_isis; new_isi * ones(size(all_times(videos)))];

            old_videos_isis(block_vids(videos)) = new_isi * ones(size(all_times(videos)));
        end

        % Remove unused videos
        stim_names(all_video_ind_to_remove) = [];
        task_probes(all_video_ind_to_remove) = [];
        old_videos_isis(all_video_ind_to_remove) = [];

        % Update video onset times
        stim_onsets(all_video_ind_to_keep + 1) = stim_onsets(all_video_ind_to_keep) + all_video_length_to_keep + new_isis;
        stim_onsets(all_video_ind_to_remove) = [];

        % Ensure all are column vectors for consistent concatenation
        stim_names = stim_names(:);
        stim_onsets = stim_onsets(:);
        task_probes = task_probes(:);
        old_videos_isis = old_videos_isis(:);


        % Store run-specific processed data
        new_stim_names{rr} = stim_names;
        new_stim_onsets{rr} = stim_onsets;
        new_task_probes{rr} = task_probes;
        new_videos_isis{rr} = old_videos_isis;
    end
    % --- equalise column lengths across runs ----
    max_len = max(cellfun(@numel, new_stim_names));
    padBaseline = 'baseline';
    for rr = 1:seq.num_runs
        pad_n = max_len - numel(new_stim_names{rr});
        if pad_n > 0
            % pad stimulus names with additional baseline rows
            new_stim_names{rr}(end+1:max_len,1) = {padBaseline};
            % Pad onsets: continue stepping by stim_duty_cycle
            last_onset = new_stim_onsets{rr}(end);
            step = seq.stim_duty_cycle;
            new_stim_onsets{rr}(end+1:max_len,1) = last_onset + step*(1:pad_n)';
            % Pad probes / ISIs with zeros
            new_task_probes{rr}(end+1:max_len,1) = 0;
            new_videos_isis{rr}(end+1:max_len,1) = seq.isi_dur;
        end
    end

    % Concatenate across runs
    seq.stim_names = horzcat(new_stim_names{:});
    seq.stim_onsets = horzcat(new_stim_onsets{:});
    seq.task_probes = horzcat(new_task_probes{:});
    seq.video_isis = horzcat(new_videos_isis{:});
end



