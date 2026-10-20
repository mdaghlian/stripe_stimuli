function bwNasrScotopic(name_subj, name_sess, name_run)
% bwNasrScotopic  Achromatic drifting-grating localiser (scotopic paradigm).
%
%   bwNasrScotopic(name_subj, name_sess, name_run)
%
%   Stimulus: full-contrast achromatic (black/white) sinusoidal grating,
%   0.2 cycles/degree, drifting continuously at 4 deg/s. Motion direction
%   reverses every 6 s. Grating orientation steps by 45 deg from one
%   block to the next (starting orientation randomised per run).
%
%   Gratings are pre-rendered by makeScotopic (settings in scot_cfg,
%   cfg_start.m) and loaded from <subj>/bwNasrScotopic/<sess>/stimuli.
%   Run makeScotopic first.
%
%   Timing: each run opens with a 16 s spatially-uniform (blank) field,
%   followed by 7 blocks of 16 s stimulation, each block followed by
%   16 s blank. Total run duration = 16 + 7*(16+16) = 240 s.
%
%   Follows the same conventions as colourProject.m / cheqProject.m in this
%   folder (cfg_start for display geometry, PTB draw loop, fixation
%   vigilance task, SPM-style Cond.mat + raw logfile .mat output).

close all
cfg_start;
fs = filesep;

if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess',  'var'), name_sess  = 'TestSess'; end
if ~exist('name_run',   'var'), name_run   = 1;          end

% name_run may be passed as text (e.g. '1') - sprintf('%d', ...) below
% would silently reinterpret a char array as ASCII codes (e.g. '1' -> 49)
% rather than erroring, so normalise to numeric here.
if ischar(name_run) || isstring(name_run)
    name_run = str2double(name_run);
end

% -------------------------------------------------------------------------
% Unpack display config (from cfg_start)
% -------------------------------------------------------------------------
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
dir_base    = cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end

% -------------------------------------------------------------------------
% Stimulus / timing parameters (scot_cfg in cfg_start). Image-dependent
% values (stim_cpd, nPhaseSteps, baseOriList) are taken from the
% makeScotopic metadata below so they always match the frames on disk.
% -------------------------------------------------------------------------
speed_dps     = scot_cfg.speed_dps;
reversalTime  = scot_cfg.reversalTime;
oriStep       = scot_cfg.oriStep;
nBlocks       = scot_cfg.nBlocks;
BlockTime     = scot_cfg.BlockTime;
BlankTime     = scot_cfg.BlankTime;
initial_blank = scot_cfg.initial_blank;
save_screen   = scot_cfg.save_screen;

% -------------------------------------------------------------------------
% Keys
% -------------------------------------------------------------------------
escapeKey   = KbName('ESCAPE');
DetectKey   = KbName('1!');
TriggerSign = KbName('5%');

% -------------------------------------------------------------------------
% Paths & logfile
% -------------------------------------------------------------------------
pathfile = [dir_base fs name_subj fs 'bwNasrScotopic' fs name_sess];
stimPath = [pathfile fs 'stimuli'];
metaFile = [stimPath fs 'logfiles' fs 'stim_metadata.mat'];
if exist(metaFile,'file')~=2
    fprintf('No scotopic stimuli in %s - building them now.\n', stimPath);
    makeScotopic(name_subj, name_sess);
end
load(metaFile, 'stim_params_scot');
if stim_params_scot.nPhaseSteps ~= scot_cfg.nPhaseSteps
    % e.g. stimuli made before nPhaseSteps was chosen for a whole number of steps per frame
    fprintf('scotopic stimuli in %s have %d phase steps, scot_cfg.nPhaseSteps is %d - rebuilding them.\n', ...
        stimPath, stim_params_scot.nPhaseSteps, scot_cfg.nPhaseSteps);
    makeScotopic(name_subj, name_sess);
    load(metaFile, 'stim_params_scot');
end
stim_cpd    = stim_params_scot.stim_cpd;
nPhaseSteps = stim_params_scot.nPhaseSteps;
% A grating is identical under a 180 deg rotation, so the block sequence
% (which can run past 180) only needs these rendered orientations.
baseOriList = stim_params_scot.baseOriList;
px_per_deg_image  = stim_params_scot.px_per_deg;    % half-resolution image px
px_per_deg_screen = px_per_deg_image / stim_params_scot.cfg.image_frac;

runDir   = [pathfile fs 'Run_' sprintf('%d', name_run)];
if exist(runDir,'dir')~=7
    mkdir(runDir);
    mkdir([runDir fs 'logfiles']);
end
FileName = [runDir fs 'logfiles' fs name_subj '_' name_sess ...
            '_Run' sprintf('%d', name_run) '_bwNasrScotopic'];

% -------------------------------------------------------------------------
% Orientation sequence: random starting orientation, then +oriStep deg
% per block (wrapped to 0-360).
% -------------------------------------------------------------------------
nOriOptions = 360 / oriStep;
startOri    = oriStep * (randi(nOriOptions) - 1);
oriSeq      = mod(startOri + (0:nBlocks-1) * oriStep, 360);   % deg, length nBlocks

% Map each block's nominal orientation onto one of the 4 rendered images
imgOriIdx = zeros(1, nBlocks);
for b = 1:nBlocks
    imgOriIdx(b) = find(baseOriList == mod(oriSeq(b), 180));
end

% -------------------------------------------------------------------------
% Build block sequence: [blank] [stim blank] x nBlocks
% -------------------------------------------------------------------------
BlockList = struct('type', {}, 'duration', {}, 'ori', {}, 'stimNum', {});

BlockList(end+1) = struct('type','blank','duration',initial_blank,'ori',NaN,'stimNum',NaN);
for b = 1:nBlocks
    BlockList(end+1) = struct('type','stim','duration',BlockTime,'ori',oriSeq(b),'stimNum',b);
    BlockList(end+1) = struct('type','blank','duration',BlankTime,'ori',NaN,'stimNum',NaN);
end

blockOnsets = zeros(1, numel(BlockList));
t = 0;
for b = 1:numel(BlockList)
    blockOnsets(b) = t;
    t = t + BlockList(b).duration;
end
totalDuration = t;

fprintf('\n--- bwNasrScotopic: %s / %s / Run %d ---\n', name_subj, name_sess, name_run);
fprintf('Orientation sequence (deg): '); fprintf('%d ', oriSeq); fprintf('\n');
fprintf('Predicted run duration: %.1f s (expected 240 s)\n', totalDuration);
if abs(totalDuration - 240) > 1e-6
    warning('Total run duration (%.2f s) does not equal the expected 240 s.', totalDuration);
end
t_end = datetime('now') + seconds(totalDuration);
fprintf('Expected end time: %s\n\n', datestr(t_end, 'HH:MM:SS'));

% -------------------------------------------------------------------------
% Load grating stimuli (pre-rendered by makeScotopic)
% -------------------------------------------------------------------------
gratingImgs = cell(length(baseOriList), nPhaseSteps);
for o = 1:length(baseOriList)
    oriFolder = [stimPath fs 'bw_grating_' sprintf('%d', baseOriList(o)) '_degrees'];
    for step = 1:nPhaseSteps
        gratingImgs{o, step} = imread([oriFolder fs sprintf('%d', step) '.png']);
    end
end

% -------------------------------------------------------------------------
% Fixation task (fix_cfg in cfg_start) & background
% -------------------------------------------------------------------------
fixTask = FixationTask(fix_cfg, width, height);
BGimage = uint8(128 * ones(height, width));   % grey background (spatially uniform field)

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
    Priority(MaxPriority(wptr));

    % --- Grating textures ---
    gratingTex = zeros(length(baseOriList), nPhaseSteps);
    for o = 1:length(baseOriList)
        for step = 1:nPhaseSteps
            img = gratingImgs{o, step};
            img = double(img) / double(intmax(class(img)));   % 16-bit (or older 8-bit) PNG -> [0,1]
            gratingTex(o, step) = Screen('MakeTexture', wptr, img, [], [], 1);
        end
    end

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
    StartTime        = t0;

    % Post-trigger flip (fixation task starts)
    fixTask.start();
    Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);
    fixTask.draw(wptr);
    vbl = Screen('Flip', wptr);

    % ---- Log structures ----
    % Frame log, preallocated for up to 240 Hz (+10 s margin) and trimmed after the loop.
    % columns: [elapsed, isStim, orientationDeg, phaseStep, direction, flipOnset], flipOnset = Screen('Flip') StimulusOnsetTime - t0 (PTB GetSecs clock, s)
    LogData      = nan(ceil((totalDuration + 10) * 240), 6);
    nLog         = 0;
    img_count    = 0;

    % Frame timing: each frame's stimulus is computed for tF, its predicted
    % onset (previous flip + one refresh interval, s since trigger 1). Drift
    % phase accumulates stepsPerSec*dtF and is rounded to a step: a whole
    % number of steps per frame at the expected refresh rate (smooth), and
    % after a dropped frame it skips ahead, so speed and phase stay right.
    stepsPerSec = speed_dps * stim_cpd * nPhaseSteps;   % phase steps per second
    stepPos     = 0;
    tPrev       = vbl + ifi - StartTime;
    phaseIdx     = 1;

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        elapsed = vbl + ifi - StartTime;   % predicted onset of this frame
        if elapsed >= totalDuration, break; end
        dtF   = elapsed - tPrev;
        tPrev = elapsed;

        % --- Determine current block ---
        cumT = 0;
        currentBlock = BlockList(1);
        localElapsed = elapsed;
        for b = 1:numel(BlockList)
            if elapsed < cumT + BlockList(b).duration
                currentBlock = BlockList(b);
                localElapsed = elapsed - cumT;
                break
            end
            cumT = cumT + BlockList(b).duration;
        end

        isStim = strcmp(currentBlock.type, 'stim');

        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        if isStim
            % Direction reverses every reversalTime s within the block.
            % Starting direction alternates block-to-block for balance.
            segIdx    = floor(localElapsed / reversalTime);
            startSign = (-1) ^ (currentBlock.stimNum - 1);
            direction = startSign * (-1) ^ segIdx;

            stepPos  = stepPos + direction * stepsPerSec * dtF;
            phaseIdx = mod(round(stepPos), nPhaseSteps) + 1;

            imgIdx = imgOriIdx(currentBlock.stimNum);
            Screen('DrawTexture', wptr, gratingTex(imgIdx, phaseIdx), [], [0 0 width height]);
        else
            direction = 0;
        end

        fixTask.update(elapsed);
        fixTask.draw(wptr);
        [vbl, onsetT] = Screen('Flip', wptr);

        % --- Log ---
        oriLog = NaN; if isStim, oriLog = currentBlock.ori; end
        nLog = nLog + 1;
        LogData(nLog, :) = [elapsed, isStim, oriLog, phaseIdx, direction, onsetT - t0];

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

    % --- End screen ---
    Screen('FillRect', wptr, [0 0 0], [0 0 width height]);
    Screen('Flip', wptr);
    exitFlag = 0;
    while ~exitFlag
        [~,~,KeyCode] = KbCheck;
        if KeyCode(escapeKey), exitFlag = 1; end
    end

    Priority(0);
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',    oldVDL);
    Screen('Preference','SuppressAllWarnings', oldSAW);

    % -----------------------------------------------------------------------
    % Save SPM-style condition file, grouped by the 4 unique visual
    % orientations (0/45/90/135 deg, mod 180) plus rest.
    % -----------------------------------------------------------------------
    isBlank = strcmp({BlockList.type}, 'blank');
    rest_onset    = blockOnsets(isBlank);
    rest_duration = [BlockList(isBlank).duration];

    names     = {'rest'};
    onsets    = {rest_onset};
    durations = {rest_duration};
    for o = 1:length(baseOriList)
        isThisOri = false(1, numel(BlockList));
        for b = 1:numel(BlockList)
            if strcmp(BlockList(b).type,'stim') && mod(BlockList(b).ori,180) == baseOriList(o)
                isThisOri(b) = true;
            end
        end
        names{end+1}     = sprintf('ori%d', baseOriList(o));
        onsets{end+1}     = blockOnsets(isThisOri);
        durations{end+1}  = [BlockList(isThisOri).duration];
    end

    FixationData = fixTask.data;   % [code, t]  1=A->B 2=B->A 3=response
    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', ...
         'oriSeq', 'BlockList', 'stim_cpd', 'speed_dps', 'reversalTime', ...
         'px_per_deg_image', 'px_per_deg_screen', 'nPhaseSteps', 'fix_cfg', '-mat');
    fprintf('Run saved to: %s\n', FileName);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    if exist('keys','var'), try, keys.release(); catch, end, end
    Priority(0);
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end
