function seq = edit_videos(seq)
% edit_videos Edit seq so that video blocks use 6 variable-length videos
% that sum to ~6 seconds (matching image block duration).
% Fixes: sequential onset calculation, 1-back probe preservation.

    all_video_lengths = seq.all_video_lengths;

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

        video_ind = find(~cellfun(@isempty, strfind(stim_names, 'LSE')));

        n_complete_blocks = floor(length(video_ind) / 12);
        if n_complete_blocks == 0
            disp('DEBUG: Contents of stim_names for this run:');
            disp(stim_names');
            error('No complete video blocks found (need at least 12 videos)');
        end
        video_ind = video_ind(1 : n_complete_blocks * 12);  % Trim incomplete block

        % Accumulate indices to remove across all blocks
        all_video_ind_to_remove = [];

        for nb = 1:n_complete_blocks
            % Block indices (12 consecutive video positions)
            block_vids = video_ind(12 * (nb - 1) + (1:12));
            queryStrings = stim_names(block_vids);
            all_times = nan(size(queryStrings));

            for k = 1:numel(queryStrings)
                rowIdx = find(matches(all_video_lengths.Filename, queryStrings{k}), 1);
                if ~isempty(rowIdx)
                    all_times(k) = all_video_lengths.Duration_Secs(rowIdx);
                end
            end

            % Select 6 videos that sum close to 6 seconds
            targetTotal = 6; % secs
            nSelect = 6;
            fill_strategy = 'more_isi';
            [videos, new_isi] = find_video_combination(all_times, targetTotal, nSelect, isi, fill_strategy);

            % --- guarantee that the oddball video is kept (task 3) ---
            oddball_idx_in_block = find(task_probes(block_vids) == 1);
            if ~isempty(oddball_idx_in_block)
                if ~ismember(oddball_idx_in_block, videos)
                    videos(end) = oddball_idx_in_block;
                end
            end

            % --- Handle 1-back probes in video blocks ---
            if seq.task_num == 1
                block_probe_positions = find(task_probes(block_vids) == 1);
                if ~isempty(block_probe_positions)
                    % Re-create a valid 1-back probe pair within the 6 kept videos.
                    % Pick two adjacent positions in the kept set: predecessor + probe.
                    videos_sorted = sort(videos);
                    new_probe_rank = randi(length(videos_sorted) - 1) + 1; % rank 2-6
                    pred_idx_in_block = videos_sorted(new_probe_rank - 1);
                    probe_idx_in_block = videos_sorted(new_probe_rank);

                    % Set probe video name to match predecessor (1-back repeat)
                    stim_names{block_vids(probe_idx_in_block)} = ...
                        stim_names{block_vids(pred_idx_in_block)};
                    % Update duration: probe plays the same video as predecessor
                    all_times(probe_idx_in_block) = all_times(pred_idx_in_block);

                    % Clear old probes in this block and set the new one
                    task_probes(block_vids) = 0;
                    task_probes(block_vids(probe_idx_in_block)) = 1;

                    % Recalculate ISI for updated total video duration
                    total_video_time = sum(all_times(videos));
                    diff_time = targetTotal - total_video_time;
                    new_isi = max(0, diff_time / nSelect);
                    if total_video_time > targetTotal
                        warning('Video block %d run %d exceeds %.1fs target (%.2fs) after 1-back adjustment', ...
                            nb, rr, targetTotal, total_video_time);
                    end
                end
            end

            % Record indices to remove (the 6 videos NOT selected)
            videos_to_remove = block_vids(~ismember(1:numel(block_vids), videos));
            all_video_ind_to_remove = [all_video_ind_to_remove; videos_to_remove];

            % Set ISIs for kept videos in this block
            old_videos_isis(block_vids(videos)) = new_isi;

            % Calculate sequential onsets for kept videos within the block.
            % Each video starts after the previous video ends + ISI.
            videos_sorted = sort(videos);
            block_start = stim_onsets(block_vids(1));
            cumulative_onset = block_start;
            for v = 1:length(videos_sorted)
                orig_idx = block_vids(videos_sorted(v));
                stim_onsets(orig_idx) = cumulative_onset;
                cumulative_onset = cumulative_onset + all_times(videos_sorted(v)) + new_isi;
            end
        end

        % Remove unused videos from all arrays at once
        stim_names(all_video_ind_to_remove) = [];
        stim_onsets(all_video_ind_to_remove) = [];
        task_probes(all_video_ind_to_remove) = [];
        old_videos_isis(all_video_ind_to_remove) = [];

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



