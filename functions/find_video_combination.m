function [validCombination, new_isi] = find_video_combination(videoDurations, targetTotal, nSelect, isi, fill_strategy)
    % find_video_combination  Select nSelect videos from 12 that best fit
    % into targetTotal seconds (including inter-stimulus intervals).
    %
    % Returns:
    %   validCombination – 1×nSelect vector of indices into videoDurations
    %   new_isi          – adjusted ISI so the block fills targetTotal

    % Add isi seconds to all videos for transitions
    isivideoDurations = isi + videoDurations;
    new_isi = isi;
    tolerance = 0.1; % Adjust if needed
    nTotal = numel(videoDurations);

    switch fill_strategy
        case 'more_videos'
            [bestCombinations, ~] = findMaxStimCombination(isivideoDurations, targetTotal, tolerance);
            validCombination = bestCombinations(1,:);
            return

        case 'more_isi'
            % Generate all combinations of nSelect from nTotal
            combs = nchoosek(1:nTotal, nSelect);
            combSums = sum(isivideoDurations(combs), 2);

            % Find combinations that fit within target + tolerance
            validMask = combSums <= targetTotal + tolerance;

            if any(validMask)
                validCombinations = combs(validMask, :);
                validSums = combSums(validMask);
                % Pick a random valid combination
                pick = randi(size(validCombinations, 1));
                validCombination = validCombinations(pick, :);
            else
                % Fallback: pick the combination with the smallest total
                % (the 6 shortest videos). Accept slightly longer block.
                [~, bestIdx] = min(combSums);
                validCombination = combs(bestIdx, :);
                warning('find_video_combination: no %d-video combo fits in %.1fs. Using shortest combo (%.2fs). ISI set to 0.', ...
                    nSelect, targetTotal, sum(videoDurations(validCombination)));
            end

            % Adjust ISI to fill remaining time (or clamp to 0)
            totalVideoDur = sum(videoDurations(validCombination));
            diff_time = targetTotal - totalVideoDur;
            if diff_time > 0
                new_isi = diff_time / nSelect;
            else
                new_isi = 0;
            end

        case 'exact_timing'
            combs = nchoosek(1:nTotal, nSelect);
            combSums = sum(isivideoDurations(combs), 2);

            validMask = (combSums <= targetTotal) & ((targetTotal - combSums) < tolerance);

            if any(validMask)
                validCombinations = combs(validMask, :);
                pick = randi(size(validCombinations, 1));
                validCombination = validCombinations(pick, :);
            else
                % Fallback: pick closest to target
                [~, bestIdx] = min(abs(combSums - targetTotal));
                validCombination = combs(bestIdx, :);
                warning('find_video_combination: no exact combo found. Using closest (%.2fs vs %.1fs target).', ...
                    combSums(bestIdx), targetTotal);
            end

            totalVideoDur = sum(videoDurations(validCombination));
            diff_time = targetTotal - totalVideoDur;
            if diff_time > 0
                new_isi = diff_time / nSelect;
            else
                new_isi = 0;
            end

        otherwise
            error('Only more_videos, more_isi, or exact_timing are valid options here')
    end
end
