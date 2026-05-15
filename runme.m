

function runme(name, trigger, stim_set, num_runs, task_num, start_run, use_eyelink)
%{ 
Prompts experimenter for session parameters and executes functional
localizer experiment used to define regions in high-level visual cortex
selective to faces, places, bodies, and printed characters.

Inputs (optional):
  1) name       -- session-specific identifier string.
                   REQUIRED FORMAT:  'XX_YY_sub-NN_ses-MM'
                   where:
                     XX    : short subject code (e.g. s1)
                     YY    : short session label (e.g. t1)
                     sub-NN: BIDS subject ID  (e.g. sub-01)
                     ses-MM: BIDS session number (e.g. ses-01)
                   -------------------------------------------------------
                   *** IMPORTANT — The first two tokens XX_YY are used as
                   the EyeLink EDF filename on the Host PC (max 8 chars).
                   They must:
                     (a) be unique per subject+session combination so that
                         EDF files from different sessions are never mixed up
                     (b) match the sub-NN and ses-MM tokens in meaning
                         (e.g. 's1_t1' should correspond to sub-01, ses-01)
                     (c) together be exactly 5 characters long so that
                         appending '_<run>' stays within the 8-char limit:
                           XX_YY_<run>  ->  e.g. s1_t1_1  (7 chars ✓)
                                                 s1_t1_10 (8 chars ✓)
                   -------------------------------------------------------
                   Examples:
                     's1_t1_sub-01_ses-01'  -> subject 01, session 01, test 1

                   The full session ID written to disk is auto-built as:
                     sub-NN_ses-MM_task-BfLocVideo_<date>_Stimset<S>_<task>_<R>runs
                     e.g. sub-01_ses-01_task-BfLocVideo_oddball_25-Apr-2026_Stimset1_oddball_2runs
                   EyeLink EDF on Host PC (≤8 chars, auto-derived from XX_YY + run):
                     s1_t1_1  (run 1),  s1_t1_2  (run 2), ...  s1_t1_10 (run 10)
                   Example calls:
                     runme('s1_t1_sub-01_ses-01', 0, 1, 2, 3)        %% no scanner, oddball
                  
  2) trigger    -- option to trigger scanner (0 = no, 1 = yes)
     NOTE: In BCBL MRI scanner, the trigger should always be 0.
  
  3) stim_set   -- stimulus set (1 = standard, 2 = alternate, 3 = both)
  4) num_runs   -- number of runs (stimuli repeat after 2 runs/set)
  5) task_num   -- which task (1 = 1-back, 2 = 2-back, 3 = oddball)
  6) start_run  -- run number to begin with (if sequence is interrupted)
  7) use_eyelink -- use EyeLink eye-tracker? (0 = no [default], 1 = yes)
                    When 1, calibration runs before the first scanner trigger.
                    To adjust the calibration zoom (area proportion), edit
                    session.el_calib_area after fLocSession() is created:
                      session.el_calib_area = [0.477 0.678]; %% 1920x1080 projector
                      session.el_calib_area = [0.715 0.715]; %% 1280x1024 iMac
TO run the experiment, go with this sample command 

runme('s1_s1_sub-01_ses-01_test-01', 0, 1, 2, 3, 0)


# To end the process: 
cmd+0: to be in the command line
shift+cmd+0: to go  back to the editor
shift+return: 
ctrl-c
sca
Screen('Close')



%}

%% add paths and check inputs

% session name
if nargin < 1
    name = [];
    while isempty(deblank(name))
        name = input('Subject initials : ', 's');
    end
end

% option to trigger scanner
if nargin < 2
    trigger = -1;
    while ~ismember(trigger, 0:1)
        trigger = input('Trigger scanner? (0 = no, 1 = yes) : ');
    end
end

% which stimulus set/s to use
if nargin < 3
    stim_set = -1;
    while ~ismember(stim_set, 1:3)
        stim_set = input('Which stimulus set? (1 = standard, 2 = alternate, 3 = both) : ');
    end
end

% number of runs to generate
if nargin < 4
    num_runs = -1;
    while ~ismember(num_runs, 1:24)
        num_runs = input('How many runs? : ');
    end
end

% which task to use
if nargin < 5
    task_num = -1;
    while ~ismember(task_num, 1:3)
        task_num = input('Which task? (1 = 1-back, 2 = 2-back, 3 = oddball) : ');
    end
end

% which run number to begin executing (default = 1)
if nargin < 6
    start_run = 1;
end

% whether to use EyeLink eye-tracker
if nargin < 7
    use_eyelink = -1;
    while ~ismember(use_eyelink, 0:1)
        use_eyelink = input('Use EyeLink eye-tracker? (0 = no, 1 = yes) : ');
    end
end

%% initialize session object and execute experiment


% setup fLocSession and save session information
session = fLocSession(name, trigger, stim_set, num_runs, task_num, use_eyelink);
session = load_seqs(session);
%session.seq = make_runs(session.seq);  % <== This is the fix

script_session_ID=sprintf("########### Session ID is %s ########### \n", session.id);
disp(script_session_ID);
% print the number of TR in the command to help checking the sequence
seq=session.sequence;
TR=2;
onset_dur=seq.stim_dur+seq.isi_dur;
num_of_stim=length(seq.stim_onsets);

NORDIC_scans=1;
dummy_scans=5;
%counter down is in sec
count_down=session.count_down; 
num_of_TR=dummy_scans+count_down/TR-dummy_scans+round(num_of_stim/(TR/onset_dur))+NORDIC_scans;

script_TR=sprintf("########### Total volumns for this experiment is %i ########### \n", num_of_TR);
disp(script_TR);

run_dur_s      = seq.run_dur;                              % stimulus period per run (s)
run_total_s    = run_dur_s + count_down;                   % including countdown
all_runs_s     = num_runs * run_total_s;                   % all runs combined
script_time = sprintf("########### Run duration: %.0f s (%.1f min) | All %d runs: %.0f s (%.1f min) ########### \n", ...
    run_total_s, run_total_s/60, num_runs, all_runs_s, all_runs_s/60);
disp(script_time);

session_dir = (fullfile(session.exp_dir, 'data', session.id));
if ~exist(session_dir, 'dir') == 7
    mkdir(session_dir);
end
fpath = fullfile(session_dir, [session.id '_fLocSession.mat']);
save(fpath, 'session', '-v7.3');

% execute all runs from start_run to num_runs and save parfiles
fname = [session.id '_fLocSession.mat'];
fpath = fullfile(session.exp_dir, 'data', session.id, fname);
for rr = start_run:num_runs
    session = run_exp(session, rr);
    save(fpath, 'session', '-v7.3');
end
%write_parfiles(session);
write_event_tsv(session);

end

% CREATE TABLE TO CHECK LOGS AND ODDBALLS
%{
S = load('ss02_21-Apr-2026_Stimset1_oddball_2runs_fLocSession.mat');

rr = 1;  % <-- change this to the run you want

kl = S.session.responses(rr).keylog;

if isempty(kl)
    fprintf('No keypresses recorded in run %d.\n', rr);
else
    key             = {kl.key}';
    time_rel        = [kl.time_rel]';
    time_abs        = [kl.time_abs]';
    stim_idx        = [kl.stim_idx]';
    device_id       = [kl.device_id]';
    stim_name       = S.session.sequence.stim_names(stim_idx, rr);
    is_probe        = logical(S.session.sequence.task_probes(stim_idx, rr));
    stim_onset_s    = S.session.sequence.stim_onsets(stim_idx, rr);
    reaction_time_s = time_rel - stim_onset_s;

    T = table(time_rel, stim_onset_s, reaction_time_s, key, ...
              stim_idx, stim_name, is_probe, device_id, time_abs, ...
        'VariableNames', {'Keypress_time_s', 'Stim_onset_s', 'Reaction_time_s', ...
                          'Key', 'Stim_index', 'Stim_name', 'Is_oddball_probe', 'Device_id', 'Time_abs'});

    disp(T);
    fprintf('\nTotal keypresses:         %d\n', height(T));
    fprintf('Hits (on probes):         %d\n', sum(T.Is_oddball_probe));
    fprintf('False alarms (off probe): %d\n', sum(~T.Is_oddball_probe));
    hits = T(T.Is_oddball_probe, :);
    if ~isempty(hits)
        fprintf('Mean RT on hits:          %.3f s\n', mean(hits.Reaction_time_s));
    end
end

%}







