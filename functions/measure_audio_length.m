function audioData = measure_audio_length(folderPath)
% MEASURE_AUDIO_LENGTH  Return a table of .wav filenames and durations (s)
%   for all .wav files in folderPath.

    wavFiles = dir(fullfile(folderPath, '*.wav'));

    if isempty(wavFiles)
        disp('No WAV files found in the specified folder.');
        audioData = table();
        return;
    end

    audioData = table('Size', [numel(wavFiles), 2], ...
        'VariableTypes', {'string', 'double'}, ...
        'VariableNames', {'Filename', 'Duration_Secs'});

    for i = 1:numel(wavFiles)
        try
            info = audioinfo(fullfile(folderPath, wavFiles(i).name));
            audioData.Filename(i)      = wavFiles(i).name;
            audioData.Duration_Secs(i) = info.Duration;
        catch ME
            fprintf('Error reading file: %s\n', wavFiles(i).name);
            fprintf('Error message: %s\n', ME.message);
        end
    end
end
