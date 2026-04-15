function seq = edit_audios(seq)
% EDIT_AUDIOS  Trim each audio block to exactly 6 s by selecting N clips
%   whose durations sum to the block target, distributing the remainder
%   as equal ISIs (same strategy as edit_videos).

    all_audio_lengths = seq.all_audio_lengths;

    new_stim_names  = cell(1, seq.num_runs);
    new_stim_onsets = cell(1, seq.num_runs);
    new_task_probes = cell(1, seq.num_runs);
    new_audio_isis  = cell(1, seq.num_runs);

    isi = seq.isi_dur;

    for rr = 1:seq.num_runs
        stim_names  = seq.stim_names(:, rr);
        stim_onsets = seq.stim_onsets(:, rr);
        task_probes = seq.task_probes(:, rr);
        old_audio_isis = isi * ones(size(task_probes));

        % Find indices of audio stimuli (contain CH_AW or CH_RAW)
        audio_ind = find(~cellfun(@isempty, regexp(stim_names, 'CH_AW|CH_RAW', 'once')));

        n_complete_blocks = floor(length(audio_ind) / 12);
        if n_complete_blocks == 0
            % No audio blocks in this run — pass through unchanged
            new_stim_names{rr}  = stim_names;
            new_stim_onsets{rr} = stim_onsets;
            new_task_probes{rr} = task_probes;
            new_audio_isis{rr}  = old_audio_isis;
            continue;
        end
        audio_ind = audio_ind(1 : n_complete_blocks * 12);

        all_audio_ind_to_remove = [];

        for nb = 1:n_complete_blocks
            block_auds    = audio_ind(12*(nb-1) + (1:12));
            queryStrings  = stim_names(block_auds);
            all_times     = nan(size(queryStrings));

            for k = 1:numel(queryStrings)
                name_for_lookup = queryStrings{k};
                if contains(name_for_lookup, '_oddball')
                    name_for_lookup = strrep(name_for_lookup, '_oddball', '');
                end
                rowIdx = find(matches(all_audio_lengths.Filename, name_for_lookup), 1);
                if ~isempty(rowIdx)
                    all_times(k) = all_audio_lengths.Duration_Secs(rowIdx);
                end
            end

            % Select clips summing to 6 s
            targetTotal  = 6;
            nSelect      = 6;
            fill_strategy = 'more_isi';
            [clips, new_isi] = find_video_combination(all_times, targetTotal, nSelect, isi, fill_strategy);

            % Preserve oddball clip if present
            oddball_idx = find(task_probes(block_auds) == 1);
            if ~isempty(oddball_idx) && ~ismember(oddball_idx, clips)
                clips(end) = oddball_idx;
            end

            % Handle 1-back probes
            if seq.task_num == 1
                block_probe_positions = find(task_probes(block_auds) == 1);
                if ~isempty(block_probe_positions)
                    clips_sorted     = sort(clips);
                    new_probe_rank   = randi(length(clips_sorted) - 1) + 1;
                    pred_idx         = clips_sorted(new_probe_rank - 1);
                    probe_idx        = clips_sorted(new_probe_rank);
                    stim_names{block_auds(probe_idx)} = stim_names{block_auds(pred_idx)};
                    all_times(probe_idx) = all_times(pred_idx);
                    task_probes(block_auds) = 0;
                    task_probes(block_auds(probe_idx)) = 1;
                    total_audio_time = sum(all_times(clips));
                    diff_time = targetTotal - total_audio_time;
                    new_isi   = max(0, diff_time / nSelect);
                end
            end

            % Mark un-selected clips for removal
            clips_to_remove = block_auds(~ismember(1:numel(block_auds), clips));
            all_audio_ind_to_remove = [all_audio_ind_to_remove; clips_to_remove]; %#ok<AGROW>

            % Set ISIs for kept clips
            old_audio_isis(block_auds(clips)) = new_isi;

            % Recalculate sequential onsets within block
            clips_sorted = sort(clips);
            cumulative_onset = stim_onsets(block_auds(1));
            for v = 1:length(clips_sorted)
                orig_idx = block_auds(clips_sorted(v));
                stim_onsets(orig_idx) = cumulative_onset;
                cumulative_onset = cumulative_onset + all_times(clips_sorted(v)) + new_isi;
            end
        end

        % Remove unused clips
        stim_names(all_audio_ind_to_remove)  = [];
        stim_onsets(all_audio_ind_to_remove) = [];
        task_probes(all_audio_ind_to_remove) = [];
        old_audio_isis(all_audio_ind_to_remove) = [];

        new_stim_names{rr}  = stim_names(:);
        new_stim_onsets{rr} = stim_onsets(:);
        new_task_probes{rr} = task_probes(:);
        new_audio_isis{rr}  = old_audio_isis(:);
    end

    % Equalise column lengths across runs (pad with baseline)
    max_len = max(cellfun(@numel, new_stim_names));
    for rr = 1:seq.num_runs
        pad_n = max_len - numel(new_stim_names{rr});
        if pad_n > 0
            new_stim_names{rr}(end+1:max_len, 1)  = {'baseline'};
            last_onset = new_stim_onsets{rr}(end);
            step = seq.stim_duty_cycle;
            new_stim_onsets{rr}(end+1:max_len, 1) = last_onset + step*(1:pad_n)';
            new_task_probes{rr}(end+1:max_len, 1) = 0;
            new_audio_isis{rr}(end+1:max_len, 1)  = seq.isi_dur;
        end
    end

    seq.stim_names  = horzcat(new_stim_names{:});
    seq.stim_onsets = horzcat(new_stim_onsets{:});
    seq.task_probes = horzcat(new_task_probes{:});
    seq.audio_isis  = horzcat(new_audio_isis{:});
end
