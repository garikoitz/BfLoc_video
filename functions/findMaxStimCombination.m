
function [bestCombinations, maxSelect] = findMaxStimCombination(isivideoDurations, targetTotal, tolerance)
    maxSelect = 0;
    bestCombinations = [];
    
    % Search from 6 to 12 elements (prioritizing larger combinations)
    for nSelect = 6:12
        combs = nchoosek(1:12, nSelect);
        currentBest = [];
        closestDiff = Inf;
        
        for i = 1:size(combs, 1)
            currentSum = sum(isivideoDurations(combs(i, :)));
            
            % Maintain tolerance condition
            if (currentSum >= targetTotal) && (currentSum - targetTotal <= tolerance)
                currentDiff = currentSum - targetTotal;
                
                % Keep closest matches
                if currentDiff < closestDiff || isempty(currentBest)
                    currentBest = combs(i, :);
                    closestDiff = currentDiff;
                elseif currentDiff == closestDiff
                    currentBest = [currentBest; combs(i, :)];
                end
            end
        end
        
        % Update best combinations if found larger valid combinations
        if ~isempty(currentBest)
            if nSelect > maxSelect
                maxSelect = nSelect;
                bestCombinations = currentBest;
            elseif nSelect == maxSelect
                bestCombinations = [bestCombinations; currentBest];
            end
        end
    end
end