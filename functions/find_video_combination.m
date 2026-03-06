function [validCombination, new_isi] = find_video_combination(videoDurations, targetTotal, nSelect, isi, fill_strategy)
    %UNTITLED3 Summary of this function goes here
    %   Detailed explanation goes here

    % Add isi seconds to all videos for transitions
    isivideoDurations = isi + videoDurations;
    new_isi = isi;
    tolerance = 0.1; % Adjust if needed

    switch fill_strategy
        case 'more_videos'
            [bestCombinations, minSelect] = findMaxStimCombination(isivideoDurations, targetTotal, tolerance);
            % Return always the first one
            validCombination = bestCombinations(1,:);
            return
        case 'more_isi'
            % Generate all combinations
            combs = nchoosek(1:12, nSelect);
            validCombinations = [];
            for i = 1:size(combs, 1)
                vids = combs(i, :);
                currentSum = sum(isivideoDurations(combs(i, :)));
                if currentSum <= targetTotal + tolerance
                     validCombinations = [validCombinations; vids];
                end
            end
            % Get random index
            validCombination = validCombinations(randi(size(validCombinations,1)),:);
            time_random_validComb = sum(isivideoDurations(validCombination));
            new_isi = isi;
            if time_random_validComb < targetTotal
                diff_time = targetTotal - sum(videoDurations(validCombination));
                new_isi = diff_time / nSelect;
            end
        case 'exact_timing'
            % Generate all combinations
            combs = nchoosek(1:12, nSelect);
            validCombinations = [];
            for i = 1:size(combs, 1)
                vids = combs(i, :);
                currentSum = sum(isivideoDurations(combs(i, :)));
                disp(targetTotal - currentSum)
                if currentSum <= targetTotal && ((targetTotal - currentSum) < tolerance)
                     validCombinations = [validCombinations; vids];
                end
            end

            % Get random index
            validCombination = validCombinations(randi(size(validCombinations,1)),:);
            time_random_validComb = sum(isivideoDurations(validCombination));
            new_isi = isi;
            if time_random_validComb < targetTotal
                diff_time = targetTotal - sum(videoDurations(validCombination));
                new_isi = diff_time / nSelect;
            end

        otherwise
            error ('Only more_videos or more_isi area valid options here')
    end


    if isempty(validCombination)
        error('No valid combination found.');
    end



end
