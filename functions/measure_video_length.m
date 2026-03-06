function videoData = measure_video_length(folderPath)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

    % Get list of MP4 files
    mp4Files = dir(fullfile(folderPath, '*.mp4'));
    
    % Check if any files were found
    if isempty(mp4Files)
        disp('No MP4 files found in the specified folder.');
        videoData = table();
        return;
    end
    
    % Initialize results table
    videoData = table('Size', [numel(mp4Files), 2],...
        'VariableTypes', {'string', 'double'},...
        'VariableNames', {'Filename', 'Duration_Secs'});
    
    % Process each file
    for i = 1:numel(mp4Files)
        try
            % Create VideoReader object
            vidPath = fullfile(folderPath, mp4Files(i).name);
            v = VideoReader(vidPath);
            
            % Store data
            videoData.Filename(i) = mp4Files(i).name;
            videoData.Duration_Secs(i) = v.Duration;

           
        catch ME
            % Handle potential errors in file reading
            fprintf('Error reading file: %s\n', mp4Files(i).name);
            fprintf('Error message: %s\n', ME.message);
        end
    end
     % Print the full table at the end
    %disp('All video durations:');
    %disp(videoData);
end
