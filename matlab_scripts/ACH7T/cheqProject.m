function cheqProject(name_subj, name_sess, name_run)
% cheqProject  Present a flashing checkerboard and record responses.
%
%   cheqProject(name_subj, name_sess, name_run)
%
%   The checkerboard reverses contrast cheq_cfg.TF_hz times per second.
%   Block timing is controlled by cheq_cfg.BlockTime and cheq_cfg.OffTime.

close all
cfg_start;
fs = filesep;

if ~exist('name_subj','var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess  = 'TestSess';  end
if ~exist('name_run',  'var'), name_run   = 1;            end

% -------------------------------------------------------------------------
% Unpack config
% -------------------------------------------------------------------------
screenid  = cfg.screenid;
width     = cfg.width;
height    = cfg.height;

nBlocks   = cheq_cfg.nBlocks;
BlockTime = cheq_cfg.BlockTime;   % ON duration  (seconds)
OffTime   = cheq_cfg.OffTime;     % OFF duration (seconds)
TF_hz     = cheq_cfg.TF_hz;      % reversals per second
save_screen = cheq_cfg.save_screen;

initial_blank = cheq_cfg.initial_blank;
end_blank     = cheq_cfg.end_blank;

reversalPeriod = 1 / TF_hz;      % seconds per half-cycle (one phase)

% -------------------------------------------------------------------------
% Keys
% -------------------------------------------------------------------------
escapeKey  = KbName('ESCAPE');
DetectKey  = KbName('1!');
TriggerSign = KbName('5%');

% -------------------------------------------------------------------------
% Paths & logfile
% -------------------------------------------------------------------------
dir_base = cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
pathfile = [dir_base fs name_subj fs 'cheq' fs name_sess];
stimPath = [pathfile fs 'stimuli' fs 'checkerboard_frames'];
metaFile = [pathfile fs 'stimuli' fs 'logfiles' fs 'stim_metadata.mat'];
rebuild  = exist([stimPath fs 'frame1.png'],'file')~=2 || exist(metaFile,'file')~=2;
if ~rebuild
    m = load(metaFile, 'stim_params_cheq');
    rebuild = ~isfield(m.stim_params_cheq, 'background');   % made before gamma correction / matched background
end
if rebuild
    fprintf('Checkerboard stimuli in %s missing or out of date - building them now.\n', stimPath);
    makeCheq(name_subj, name_sess);
end
load(metaFile, 'stim_params_cheq');

runDir = [pathfile fs 'Run_' sprintf('%d', name_run)];
if exist(runDir,'dir')~=7
    mkdir(runDir);
    mkdir([runDir fs 'logfiles']);
end
FileName = [runDir fs 'logfiles' fs name_subj '_' name_sess ...
            '_Run' sprintf('%d', name_run) '_checker'];

% -------------------------------------------------------------------------
% Build block sequence: OFF ON OFF ON … OFF
% Each element: struct with fields 'type' ('off'|'on') and 'duration'
% -------------------------------------------------------------------------
%   Structure: [off] [on off] × nBlocks
%   Total duration = OffTime + nBlocks*(BlockTime + OffTime)
BlockList = struct('type', {}, 'duration', {});

% --- Initial blank (extra padding before everything) ---
if initial_blank > 0
    BlockList(end+1) = struct('type','off','duration', initial_blank);
end

% --- Standard design ---
for b = 1:nBlocks
    BlockList(end+1) = struct('type','on',  'duration', BlockTime);
    BlockList(end+1) = struct('type','off', 'duration', OffTime);
end

% --- End blank (extra padding after everything) ---
if end_blank > 0
    BlockList(end+1) = struct('type','off','duration', end_blank);
end
% Pre-compute onset times for each block (used in log)
blockOnsets = zeros(1, numel(BlockList));
t = 0;
for b = 1:numel(BlockList)
    blockOnsets(b) = t;
    t = t + BlockList(b).duration;
end
totalDuration = t;

% -------------------------------------------------------------------------
% Fixation task (fix_cfg in cfg_start) & background
% -------------------------------------------------------------------------
fixTask = FixationTask(fix_cfg, width, height);
BGimage = uint8(round(stim_params_cheq.background.drive) * ones(height, width));   % matched grey background (makeCheq)

% 
predictedDuration = initial_blank + nBlocks * (BlockTime + OffTime) + end_blank;

fprintf(['Predicted run time:\n' ...
         '  Initial blank (initial): %.2f s\n' ...
         '  Blocks: %d × (%.2f s ON + %.2f s OFF)\n' ...
         '  Final blanks (final): %.2f s\n' ...
         '  Total: %.2f s \n\n' ...
         ], ...
         initial_blank, nBlocks, BlockTime, OffTime, end_blank, ...
         predictedDuration);
t_end = datetime('now') + seconds(predictedDuration);
fprintf('Expected end time:    %s\n\n', datestr(t_end, 'HH:MM:SS'));

% -------------------------------------------------------------------------
% PTB
% -------------------------------------------------------------------------
try
    oldVDL = Screen('Preference','VisualDebugLevel', 3);
    oldSAW = Screen('Preference','SuppressAllWarnings', 1);
    wptr   = Screen('OpenWindow', screenid);
    HideCursor;
    Screen('BlendFunction', wptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    ifi = checkRefreshRate(wptr, cfg);   % flip interval; aborts unless cfg.expectedHz
    useIdentityGamma(wptr);              % identity gamma table, as in the calibration (RestoreCluts on exit)
    Priority(MaxPriority(wptr));

    % --- Load checkerboard frames ---
    img0 = double(imread([stimPath fs 'frame0.png'])) / 65535;
    img1 = double(imread([stimPath fs 'frame1.png'])) / 65535;
    tex(1) = Screen('MakeTexture', wptr, img0, [], [], 1);  % phase 0
    tex(2) = Screen('MakeTexture', wptr, img1, [], [], 1);  % phase 1 (inverted)

    % --- Background texture ---
    bgTex = Screen('MakeTexture', wptr, BGimage);

    % --- Pre-trigger screen (idle fixation on grey) ---
    Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);
    fixTask.draw(wptr);
    Screen('Flip', wptr);

    % --- Wait for trigger ---
    % Key queue: logs every trigger and response with its own GetSecs time
    % (see ScannerKeys.m). t0 = first trigger = time zero of the run.
    keys = ScannerKeys(TriggerSign, DetectKey, escapeKey);
    t0   = keys.waitForTrigger();

    % --- Start timing: all run times are GetSecs - StartTime (s since trigger 1) ---
    StartTime     = t0;

    % Post-trigger flip (fixation task starts)
    fixTask.start();
    Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);
    fixTask.draw(wptr);
    vbl = Screen('Flip', wptr);

    % ---- Log structures ----
    % Frame log, preallocated for up to 240 Hz (+10 s margin) and trimmed after the loop.
    % columns: [t isOn phaseIndex flipOnset], flipOnset = Screen('Flip') StimulusOnsetTime - t0 (PTB GetSecs clock, s)
    LogData      = nan(ceil((totalDuration + 10) * 240), 4);
    nLog         = 0;
    img_count    = 0;

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    % Frame timing: each frame is computed for its predicted onset (previous
    % flip + one refresh interval), so reversals fall on exact frames.
    while true
        elapsed = vbl + ifi - StartTime;   % predicted onset of this frame
        if elapsed >= totalDuration, break; end

        % --- Determine current block ---
        cumT = 0;
        currentBlock = BlockList(1);
        for b = 1:numel(BlockList)
            if elapsed < cumT + BlockList(b).duration
                currentBlock = BlockList(b);
                break
            end
            cumT = cumT + BlockList(b).duration;
        end

        % --- Determine which checkerboard phase (from the frame onset time) ---
        phaseIndex = mod(floor(elapsed / reversalPeriod + 1e-6), 2) + 1;   % +1e-6: timestamp jitter at a boundary
        % phaseIndex = 1 → frame0 (normal), 2 → frame1 (inverted)

        % --- Draw ---
        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        if strcmp(currentBlock.type, 'on')
            Screen('DrawTexture', wptr, tex(phaseIndex), [], [0 0 width height]);
        end
        % In 'off' blocks: just grey background (already drawn)

        fixTask.update(elapsed);
        fixTask.draw(wptr);
        [vbl, onsetT] = Screen('Flip', wptr);

        % --- Log ---
        isOn = strcmp(currentBlock.type,'on');
        nLog = nLog + 1;
        LogData(nLog, :) = [elapsed, isOn, phaseIndex, onsetT - t0];

        % --- Key presses since the last frame (triggers are stored in keys) ---
        [respTimes, escapePressed] = keys.poll(t0);
        for r = respTimes
            fixTask.respond(r);
        end
        if escapePressed
            break
        end

        % --- Optional screenshot ---
        if save_screen
            imgDir = [runDir fs 'img'];
            if exist(imgDir,'dir')~=7, mkdir(imgDir); end
            imageArray = Screen('GetImage', wptr, [0 0 width height]);
            imwrite(imageArray, [imgDir fs 'img_' num2str(img_count) '.png']);
            img_count = img_count + 1;
        end
    end

    LogData = LogData(1:nLog, :);
    keys.release();
    TriggerTime = keys.triggerTimes(t0);   % s since the first trigger (first = 0)
    keys.report(t0, totalDuration);

    % -----------------------------------------------------------------------
    % Compute onset/duration arrays for SPM-style saving
    % -----------------------------------------------------------------------
    % Logical arrays for indexing
    isOffBlock = strcmp({BlockList.type}, 'off');
    isOnBlock  = strcmp({BlockList.type}, 'on');
    rest_onset = blockOnsets(isOffBlock);
    stim_onset = blockOnsets(isOnBlock);

    names     = {'rest', 'checkerboard'};
    onsets    = {rest_onset, stim_onset};
    rest_durations = [BlockList(isOffBlock).duration];
    stim_durations = [BlockList(isOnBlock).duration];

    durations = {rest_durations, stim_durations};

    FixationData = fixTask.data;   % [code, t]  1=A->B 2=B->A 3=response
    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', 'fix_cfg', '-mat');

    % --- End screen: matched grey, wait for Esc ---
    if escapePressed, endState = 'stopped early (Esc)'; else, endState = 'completed'; end
    waitAtEnd(wptr, round(stim_params_cheq.background.drive)*[1 1 1], sprintf('Run %d %s and saved:\n  %s', name_run, endState, FileName));

    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',   oldVDL);
    Screen('Preference','SuppressAllWarnings', oldSAW);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    if exist('keys','var'), try, keys.release(); catch, end, end
    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end