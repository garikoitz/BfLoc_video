function [keys, timestamps, device_ids, is_empty] = record_keys_ts(start_time, dur, device_num)
% Collects all keypresses for a given duration (in secs), recording
% absolute GetSecs timestamps for each press.
% Pass device_num=-1 to merge ALL connected HID devices (PTB convention).
%
% Returns:
%   keys       - cell array of key name strings
%   timestamps - corresponding GetSecs timestamps (seconds)
%   device_ids - device_num value used (same for all entries; -1 = merged all)
%   is_empty   - 1 if no keys were pressed, 0 otherwise

keys       = {};
timestamps = [];
device_ids = [];

% wait until any held keys are released
while KbCheck(device_num)
    if (GetSecs - start_time) > dur
        is_empty = isempty(keys);
        return
    end
end

% poll for keypresses until duration expires
while 1
    [key_is_down, t_press, key_code] = KbCheck(device_num);
    if key_is_down
        key_name = KbName(key_code);
        if iscell(key_name)
            key_name = strjoin(key_name, '+');
        end
        keys{end+1}       = key_name;    %#ok<AGROW>
        timestamps(end+1) = t_press;     %#ok<AGROW>
        device_ids(end+1) = device_num;  %#ok<AGROW>
        % wait for release before polling again
        while KbCheck(device_num)
            if (GetSecs - start_time) > dur
                break
            end
        end
    end
    if (GetSecs - start_time) > dur
        break
    end
end

is_empty = isempty(keys);
end
