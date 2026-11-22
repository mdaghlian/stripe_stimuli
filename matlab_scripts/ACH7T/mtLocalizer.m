function mtLocalizer(name_subj, name_sess, name_run)
% mtLocalizer  MT localiser: expanding/contracting rings vs static rings.
%
%   mtLocalizer(name_subj, name_sess, name_run)
%
%   Based on NasrOriginal/Motion/My_MT_localizer_HighRes.m. Nasr's version
%   loads 24 pre-rendered ring images; here the rings are pre-rendered by
%   makeMT from mt_cfg (cfg_start.m), in degrees of visual angle, and
%   loaded from <subj>/mt/<sess>/stimuli. Run makeMT first.
%
%   Stimulus: thin dark rings on a grey background, filling the screen
%   (or a circular aperture, mt_cfg.apertureFrac). In moving blocks the rings expand/contract at
%   mt_cfg.speed_dps, reversing direction every mt_cfg.reversalTime s.
%   Ring position is computed from the time within the block, not frame
%   count, so speed does not depend on the refresh rate.
%
%   Static ring phase: every static block in a run freezes the rings at a
%   different phase. With N static blocks the phases are spaced 1/N of a
%   ring period apart (from a random offset per run) and shuffled, so
%   averaged over the static blocks of one run the rings cover the screen
%   evenly (no holes as long as period/N <= ring width; a warning is
%   printed otherwise) and the static condition carries no fixed ring
%   pattern. Each moving block is placed so that it ends exactly at the
%   phase of the static block that follows it (or, for a final moving
%   block, starts at the phase of the one before), so the step change in
%   phase falls at a motion onset, never inside a static block. The
%   phases are saved (blockStep, phaseOffsetFrac) and logged per frame.
%   name_run must be a whole number; for a repeated run, use the next
%   unused number.
%
%   Timing: initial rest, then mt_cfg.nCycles x (static + moving) blocks,
%   then end rest. Whether each pair starts with static or moving is
%   randomised per run (as in Nasr's version). With the default settings:
%   12 + 5*(24+24) + 12 = 264 s.
%
%   Follows the same conventions as bwNasrScotopic.m / cheqProject.m in
%   this folder (cfg_start for display geometry, PTB draw loop, fixation
%   vigilance task, SPM-style Cond.mat + raw logfile .mat output).

close all
cfg_start;
fs = filesep;

if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess',  'var'), name_sess  = 'TestSess'; end
if ~exist('name_run',   'var'), name_run   = 1;          end

% name_run may be passed as text (e.g. '1') - sprintf('%d', ...) below
% would silently reinterpret a char array as ASCII codes, so normalise.
if ischar(name_run) || isstring(name_run)
    name_run = str2double(name_run);
end
% '3b' would become NaN (RunNaN files), so stop here, before the window opens.
if ~(isscalar(name_run) && isfinite(name_run) && name_run >= 1 && name_run == round(name_run))
    error('name_run must be a whole number >= 1 (for a repeated run, use the next unused number).');
end

% -------------------------------------------------------------------------
% Unpack config (from cfg_start)
% -------------------------------------------------------------------------
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
dir_base    = cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end

% Image-dependent values (ring period, nPhaseSteps, bgLum) are taken from
% the makeMT metadata below so they always match the frames on disk.
speed_dps      = mt_cfg.speed_dps;
initial_blank  = mt_cfg.initial_blank;
end_blank      = mt_cfg.end_blank;
StaticTime     = mt_cfg.StaticTime;
MovingTime     = mt_cfg.MovingTime;
nCycles        = mt_cfg.nCycles;
reversalTime   = mt_cfg.reversalTime;
startDir       = mt_cfg.startDir;
save_screen    = mt_cfg.save_screen;

% -------------------------------------------------------------------------
% Keys
% -------------------------------------------------------------------------
escapeKey   = KbName('ESCAPE');
DetectKey   = KbName('1!');
TriggerSign = KbName('5%');

% -------------------------------------------------------------------------
% Paths & logfile
% -------------------------------------------------------------------------
pathfile = [dir_base fs name_subj fs 'mt' fs name_sess];
stimPath = [pathfile fs 'stimuli'];
metaFile = [stimPath fs 'logfiles' fs 'stim_metadata.mat'];
if exist(metaFile,'file')~=2
    fprintf('No MT stimuli in %s - building them now.\n', stimPath);
    makeMT(name_subj, name_sess);
end
load(metaFile, 'stim_params_mt');
ringFields = {'ringPeriod_deg', 'ringWidth_deg', 'apertureFrac', 'ringLum', 'bgLum', 'nPhaseSteps'};   % settings baked into the images
stale = ~isfield(stim_params_mt, 'background');
for f = ringFields
    stale = stale || ~isfield(stim_params_mt.mt_cfg, f{1}) || ~isequal(stim_params_mt.mt_cfg.(f{1}), mt_cfg.(f{1}));
end
if stale
    % stimuli made before gamma correction / the matched background, or
    % before nPhaseSteps was chosen for a whole number of steps per frame
    fprintf('MT stimuli in %s are out of date - rebuilding them.\n', stimPath);
    makeMT(name_subj, name_sess);
    load(metaFile, 'stim_params_mt');
end
ringPeriod_deg = stim_params_mt.ringPeriod_deg;
nPhaseSteps    = stim_params_mt.nPhaseSteps;
bgLum          = stim_params_mt.bgLum;
px_per_deg_image  = stim_params_mt.px_per_deg;    % half-resolution image px
px_per_deg_screen = px_per_deg_image / stim_params_mt.cfg.image_frac;

ringWidth_deg  = stim_params_mt.mt_cfg.ringWidth_deg;

% MATLAB starts every session with the same random seed, so without this
% the pair order and ring phases would repeat whenever MATLAB is restarted.
rng('shuffle');
rngState = rng;

runDir   = [pathfile fs 'Run_' sprintf('%d', name_run)];
if exist(runDir,'dir')~=7
    mkdir(runDir);
    mkdir([runDir fs 'logfiles']);
end
FileName = [runDir fs 'logfiles' fs name_subj '_' name_sess ...
            '_Run' sprintf('%d', name_run) '_mt'];

% -------------------------------------------------------------------------
% Build block sequence: [rest] [static moving] x nCycles [rest]
% Order within each pair is randomised once per run (as in Nasr's script).
% -------------------------------------------------------------------------
staticFirst = rand(1) > 0.5;
if staticFirst
    pairTypes = {'static', 'moving'};
else
    pairTypes = {'moving', 'static'};
end

BlockList = struct('type', {}, 'duration', {});
BlockList(end+1) = struct('type', 'rest', 'duration', initial_blank);
for c = 1:nCycles
    for k = 1:2
        if strcmp(pairTypes{k}, 'static')
            BlockList(end+1) = struct('type', 'static', 'duration', StaticTime);
        else
            BlockList(end+1) = struct('type', 'moving', 'duration', MovingTime);
        end
    end
end
BlockList(end+1) = struct('type', 'rest', 'duration', end_blank);

blockOnsets = zeros(1, numel(BlockList));
t = 0;
for b = 1:numel(BlockList)
    blockOnsets(b) = t;
    t = t + BlockList(b).duration;
end
totalDuration = t;

% -------------------------------------------------------------------------
% Ring phase of every block (in phase steps; frame index = mod(step, nPhaseSteps) + 1)
% -------------------------------------------------------------------------
% Moving blocks: the rings move out and back (direction reverses every
% reversalTime s), a triangle wave in steps; moveSteps(tLocal) is the
% displacement from the block's start phase. It is a function of the time
% within the block, not accumulated frame by frame (that drifted at every
% reversal).
stepsPerSec = speed_dps / ringPeriod_deg * nPhaseSteps;   % phase steps per second
moveSteps   = @(tLocal) startDir * stepsPerSec * ...
              (reversalTime * mod(floor(tLocal / reversalTime), 2) + ...
               (-1) .^ floor(tLocal / reversalTime) .* mod(tLocal, reversalTime));
moveEnd     = moveSteps(MovingTime);   % displacement at the end of a moving block (0 with the defaults)

% Static blocks: N phases 1/N of a period apart from a random offset,
% shuffled, so the static blocks of one run together cover the period.
isStatic  = strcmp({BlockList.type}, 'static');
isMoving  = strcmp({BlockList.type}, 'moving');
nStatic   = sum(isStatic);
phaseOffsetFrac = rand;
staticSteps = mod(round((phaseOffsetFrac + (0:nStatic-1) / nStatic) * nPhaseSteps), nPhaseSteps);
staticSteps = staticSteps(randperm(nStatic));
blockStep   = nan(1, numel(BlockList));   % ring phase of each block (static: shown; moving: start)
blockStep(isStatic) = staticSteps;

% Largest spacing between neighbouring static phases vs the ring width:
% if the spacing is wider, the averaged static rings leave gaps.
sortedSteps = sort(staticSteps);
maxGap_deg  = max(diff([sortedSteps, sortedSteps(1) + nPhaseSteps])) / nPhaseSteps * ringPeriod_deg;
if maxGap_deg > ringWidth_deg + 1e-9
    warning('mtLocalizer: static ring phases up to %.3f deg apart, wider than the rings (%.3f deg): averaged over the static blocks the rings leave gaps. Use more cycles (nCycles) or wider rings.', ...
            maxGap_deg, ringWidth_deg);
end

% Moving blocks end at the phase of the next static block, so the
% moving -> static change is seamless and the phase jump falls at a motion
% onset; a moving block with no static block after it starts at the
% phase of the one before it.
staticIdxList = find(isStatic);
for b = find(isMoving)
    nextS = staticIdxList(find(staticIdxList > b, 1));
    if ~isempty(nextS)
        blockStep(b) = blockStep(nextS) - moveEnd;
    else
        blockStep(b) = blockStep(staticIdxList(find(staticIdxList < b, 1, 'last')));
    end
end

fprintf('\n--- mtLocalizer: %s / %s / Run %d ---\n', name_subj, name_sess, name_run);
fprintf('Pair order: %s then %s\n', pairTypes{1}, pairTypes{2});
fprintf('Static ring phases (step of %d, in block order): %s  (offset %.3f period, max spacing %.3f deg, ring width %.3f deg)\n', ...
        nPhaseSteps, num2str(blockStep(isStatic)), phaseOffsetFrac, maxGap_deg, ringWidth_deg);
fprintf('Predicted run duration: %.1f s\n', totalDuration);
t_end = datetime('now') + seconds(totalDuration);
fprintf('Expected end time: %s\n\n', datestr(t_end, 'HH:MM:SS'));

% -------------------------------------------------------------------------
% Load ring stimuli (pre-rendered by makeMT). One full ring period in
% nPhaseSteps images; higher step = rings further out.
% -------------------------------------------------------------------------
ringImgs = cell(1, nPhaseSteps);
for step = 1:nPhaseSteps
    ringImgs{step} = imread([stimPath fs 'ring_frames' fs sprintf('%d', step) '.png']);
end

% -------------------------------------------------------------------------
% Fixation task (fix_cfg in cfg_start) & background
% -------------------------------------------------------------------------
fixTask = FixationTask(fix_cfg, width, height);
BGimage = uint8(round(bgLum) * ones(height, width));   % matched grey background (makeMT)

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
    gammaInfo = useIdentityGamma(wptr);              % identity gamma table, as in the calibration (RestoreCluts on exit)
    Priority(MaxPriority(wptr));

    % --- Ring textures ---
    ringTex = zeros(1, nPhaseSteps);
    for step = 1:nPhaseSteps
        img = ringImgs{step};
        img = double(img) / double(intmax(class(img)));   % 16-bit (or older 8-bit) PNG -> [0,1]
        ringTex(step) = Screen('MakeTexture', wptr, img, [], [], 1);
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
    % columns: [elapsed, blockCode (0 rest, 1 static, 2 moving), phaseIdx (ring frame 1..nPhaseSteps, 0 = rest), direction, flipOnset], flipOnset = Screen('Flip') StimulusOnsetTime - t0 (PTB GetSecs clock, s)
    LogData      = nan(ceil((totalDuration + 10) * 240), 5);
    frameBlock   = zeros(size(LogData, 1), 1);   % BlockList index of each logged frame
    nLog         = 0;
    img_count    = 0;

    % Frame timing: each frame's stimulus is computed for its predicted
    % onset (previous flip + one refresh interval, s since trigger 1), with
    % the ring phase from blockStep / moveSteps (above). After a dropped
    % frame the rings still skip ahead to the right place.
    phaseIdx    = 0;   % 0 = no rings (rest)

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        elapsed = vbl + ifi - StartTime;   % predicted onset of this frame
        if elapsed >= totalDuration, break; end

        % --- Determine current block ---
        cumT = 0;
        currentBlock = BlockList(1);
        curB         = 1;
        localElapsed = elapsed;
        for b = 1:numel(BlockList)
            if elapsed < cumT + BlockList(b).duration
                currentBlock = BlockList(b);
                curB         = b;
                localElapsed = elapsed - cumT;
                break
            end
            cumT = cumT + BlockList(b).duration;
        end

        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        switch currentBlock.type
            case 'rest'
                blockCode = 0;
                direction = 0;
                phaseIdx  = 0;
            case 'static'
                % rings frozen at this static block's own phase
                blockCode = 1;
                direction = 0;
                phaseIdx  = mod(blockStep(curB), nPhaseSteps) + 1;
                Screen('DrawTexture', wptr, ringTex(phaseIdx), [], [0 0 width height]);
            case 'moving'
                % direction reverses every reversalTime s within the block
                blockCode = 2;
                direction = startDir * (-1) ^ floor(localElapsed / reversalTime);
                phaseIdx  = mod(round(blockStep(curB) + moveSteps(localElapsed)), nPhaseSteps) + 1;
                Screen('DrawTexture', wptr, ringTex(phaseIdx), [], [0 0 width height]);
        end

        fixTask.update(elapsed);
        fixTask.draw(wptr);
        [vbl, onsetT] = Screen('Flip', wptr);

        % --- Log ---
        nLog = nLog + 1;
        LogData(nLog, :) = [elapsed, blockCode, phaseIdx, direction, onsetT - t0];
        frameBlock(nLog) = curB;

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

    LogData    = LogData(1:nLog, :);
    frameBlock = frameBlock(1:nLog);
    keys.release();
    TriggerTime = keys.triggerTimes(t0);   % s since the first trigger (first = 0)
    keys.report(t0, totalDuration);

    % -----------------------------------------------------------------------
    % Save SPM-style condition file: measured onsets/durations (flip time of
    % each block's first frame); blocks not shown (Esc) are left out
    % -----------------------------------------------------------------------
    [blockOnsetsMeas, blockDurMeas] = measuredBlockTiming(frameBlock, LogData(:, 5), blockOnsets, ifi);
    names     = {'rest', 'static', 'moving'};
    onsets    = cell(1, numel(names));
    durations = cell(1, numel(names));
    for n = 1:numel(names)
        isThis       = strcmp({BlockList.type}, names{n}) & ~isnan(blockOnsetsMeas);
        onsets{n}    = blockOnsetsMeas(isThis);
        durations{n} = blockDurMeas(isThis);
    end

    FixationData = fixTask.data;   % [code, t]  1=A->B 2=B->A 3=response
    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', 'gammaInfo', ...
         'BlockList', 'blockOnsets', 'blockOnsetsMeas', 'blockDurMeas', 'frameBlock', ...
         'staticFirst', 'blockStep', 'phaseOffsetFrac', 'rngState', 'mt_cfg', 'fix_cfg', 'px_per_deg_image', 'px_per_deg_screen', '-mat');

    % --- End screen: matched grey, wait for Esc ---
    if escapePressed, endState = 'stopped early (Esc)'; else, endState = 'completed'; end
    waitAtEnd(wptr, round(bgLum)*[1 1 1], sprintf('Run %d %s and saved:\n  %s', name_run, endState, FileName));

    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',    oldVDL);
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
