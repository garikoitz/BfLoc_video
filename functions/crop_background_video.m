function crop_background_video(video_path, bg_path, crop_size, new_file_path, target_rgb, baseline)
%crop_background_video Crop video to the size and substitute gray bg with new file
%   Crop video to the size and substitute gray bg with new file
    
%{
% Edit below and run and it will convert all videos in the location

basedir = '/Users/glerma/toolboxes/fLoc';
video_path = fullfile(basedir, 'stimuli/video');
bg_path = fullfile(basedir, 'stimuli/scrambled');
crop_size = [1024, 1024];
new_file_path = fullfile(video_path,'new_video');
target_rgb = [149,149,149];
baseline = true;

% CALL FUNCTION
crop_background_video(video_path, bg_path, crop_size, new_file_path, target_rgb, baseline)

figure;imshow(c_resp)

%}

    % Get all the videos in the folder
    VIDEOS = dir(fullfile(video_path, '*.mp4'));
    % Get all the backgrounds in the folder
    BACKGROUNDS = dir(fullfile(bg_path, '*.jpg'));
    % Create output folder if it does not exist
    if ~isfolder(new_file_path); mkdir(new_file_path); end

    % Start editing videos
    for nv = 1:length(VIDEOS)
        % Do all videos
        video_name = VIDEOS(nv).name;
        v = VideoReader(fullfile(video_path, video_name));
        % Select random background per video
        rng('shuffle'); 
        random_number = randi(length(BACKGROUNDS));
        bg_I = imread(fullfile(bg_path, BACKGROUNDS(random_number).name));
        % Assert that crop_size is the same as background size
        assert(isequal(crop_size, size(bg_I)))
        % Now add the 3 channels for later on
        rgb_bw = cat(3, bg_I, bg_I, bg_I);

        % Video data
        numFrames = round(v.FrameRate * v.Duration);
        vidHeight = v.Height;
        vidWidth = v.Width;

        % COLOR: Preallocate a 4D array: Height x Width x Channels x Frames
        videoMatrix = zeros(vidHeight, vidWidth, 3, numFrames, 'uint8');
        crop_videoMatrix = zeros(crop_size(1), crop_size(2), 3, numFrames, 'uint8');
    
        % READ, CROP, ADD BG
        target_height = 1024;
        scale = target_height / vidHeight;
        for k = 1:numFrames
            videoMatrix(:,:,:,k) = readFrame(v);
            % Step 1: Resize so height is 1024, width scales accordingly
            resized_I = imresize(videoMatrix(:,:,:,k), scale);
            % Step 2: Center crop to 1024x1024
            [~, resized_width, ~] = size(resized_I);
            x_start = floor((resized_width - crop_size(2))/2) + 1;
            y_start = 1; % since height matches exactly
            cropped_I = imcrop(resized_I, [x_start, y_start, crop_size(1)-1, crop_size(2)-1]);
            % ADD BACKGROUND
            mask = all(cropped_I == reshape(target_rgb, 1, 1, 3), 3);
            mask_3d = repmat(mask, 1, 1, 3); 
            if baseline
                % 1. Generate random Gabor parameters
                num_filters = 4; % Number of random filters
                wavelengths = randi([4 20], 1, num_filters); % Random wavelengths (4-20 pixels)
                orientations = rand(1, num_filters) * 180; % Random orientations (0-180°)

                % 2. Create Gabor filter bank with random parameters
                gabor_bank = gabor(wavelengths, orientations);

                % 3. Apply filters to grayscale image
                grayI = rgb2gray(cropped_I);
                [mag, ~] = imgaborfilt(grayI, gabor_bank);

                % 4. Combine responses (max projection for visible effect)
                c_resp = max(mag, [], 3);
                cropped_I = cat(3, c_resp, c_resp, c_resp);
            end
            cropped_I(mask_3d) = rgb_bw(mask_3d);
            % Just in case it was color, make it gray
            % c_gray = im2gray(cropped_I);
            % c_gray3 = cat(3, c_gray, c_gray, c_gray);
            % assign the frame
            crop_videoMatrix(:,:,:,k) = cropped_I;
        end
        
        % SAVE IT
        new_video_name = strrep(video_name, '.mp4','_crop_scrambled.mp4');
        writer = VideoWriter(fullfile(new_file_path,new_video_name), 'MPEG-4');
        open(writer);
        
        for k = 1:numFrames
            frame = crop_videoMatrix(:,:,:,k); % Each frame must be an image (uint8 RGB)
            writeVideo(writer, frame);
        end
        
        close(writer);

    end

end