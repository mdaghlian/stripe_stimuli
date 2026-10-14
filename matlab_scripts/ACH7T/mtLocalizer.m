function mtLocalizer(name_subj, name_sess, name_run)
% mtLocalizer  MT localiser: expanding/contracting rings vs static rings.
%
%   mtLocalizer(name_subj, name_sess, name_run)
%
%   Based on NasrOriginal/Motion/My_MT_localizer_HighRes.m. Nasr's version
%   loads 24 pre-rendered ring images; here the rings are generated in
%   memory from mt_cfg (cfg_start.m), in degrees of visual angle.
%
%   Stimulus: thin dark rings on a grey background inside a circular
%   aperture. In moving blocks the rings expand/contract at
%   mt_cfg.speed_dps, reversing direction every mt_cfg.reversalTime s.
%   In static blocks the rings are frozen where the motion stopped.
%   Motion is driven by real elapsed time, not frame count, so speed does
%   not depend on the refresh rate.
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

% -------------------------------------------------------------------------
% Unpack config (from cfg_start)
% -------------------------------------------------------------------------
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
image_frac  = cfg.image_frac;
distance_cm = cfg.distance_cm;
height_cm   = cfg.height_cm;
dir_base    = cfg.dir_base;

ringPeriod_deg = mt_cfg.ringPeriod_deg;
ringWidth_deg  = mt_cfg.ringWidth_deg;
speed_dps      = mt_cfg.speed_dps;
apertureFrac   = mt_cfg.apertureFrac;
ringLum        = mt_cfg.ringLum;
bgLum          = mt_cfg.bgLum;
nPhaseSteps    = mt_cfg.nPhaseSteps;
initial_blank  = mt_cfg.initial_blank;
end_blank      = mt_cfg.end_blank;
StaticTime     = mt_cfg.StaticTime;
MovingTime     = mt_cfg.MovingTime;
nCycles        = mt_cfg.nCycles;
reversalTime   = mt_cfg.reversalTime;
startDir       = mt_cfg.startDir;
save_screen    = mt_cfg.save_screen;
fixSize        = stim_cfg.fixSize;   % same fixation as colourProject

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
runDir   = [pathfile fs 'Run_' sprintf('%d', name_run)];
if ~isfolder(runDir)
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

fprintf('\n--- mtLocalizer: %s / %s / Run %d ---\n', name_subj, name_sess, name_run);
fprintf('Pair order: %s then %s\n', pairTypes{1}, pairTypes{2});
fprintf('Predicted run duration: %.1f s\n', totalDuration);
t_end = datetime('now') + seconds(totalDuration);
fprintf('Expected end time: %s\n\n', datestr(t_end, 'HH:MM:SS'));

% -------------------------------------------------------------------------
% Generate ring stimuli (in memory). One full ring period is rendered in
% nPhaseSteps images; the radial offset of each image is
% (step-1)/nPhaseSteps of a period, so higher step = rings further out.
% -------------------------------------------------------------------------
gw = round(width  * image_frac);
gh = round(height * image_frac);

px_per_cm  = gh / height_cm;                    % accounts for downsampling
cm_per_deg = 2 * distance_cm * tan(deg2rad(0.5));
px_per_deg = px_per_cm * cm_per_deg;

period_px   = ringPeriod_deg * px_per_deg;
ringW_px    = ringWidth_deg  * px_per_deg;
aperture_px = apertureFrac   * gh;

[Xm, Ym] = meshgrid(1:gw, 1:gh);
R = sqrt((Xm - (gw+1)/2).^2 + (Ym - (gh+1)/2).^2);

ringImgs = cell(1, nPhaseSteps);
for step = 1:nPhaseSteps
    offset_px = (step - 1) / nPhaseSteps * period_px;
    % distance (px) from the centre line of the nearest ring
    e = abs(mod(R - offset_px + period_px/2, period_px) - period_px/2);
    % ring coverage with a 1-px linear edge (anti-aliasing)
    cover = min(max(ringW_px/2 - e + 0.5, 0), 1);
    % soft aperture edge
    cover = cover .* min(max(aperture_px - R + 0.5, 0), 1);
    ringImgs{step} = uint8(round(bgLum + (ringLum - bgLum) * cover));
end

% -------------------------------------------------------------------------
% Fixation geometry & images (same as colourProject / bwNasrScotopic)
% -------------------------------------------------------------------------
X1 = width/2  - fixSize;  X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;  Y2 = height/2 + fixSize;

FixationImage_White  = 255 * ones(3,3,3);
FixationImage_Green1 = 255 * ones(3,3,3); FixationImage_Green1(:,:,[1 3]) = 0;
FixationImage_Green2 = 180 * ones(3,3,3); FixationImage_Green2(:,:,[1 3]) = 0;
BGimage = uint8(bgLum * ones(height, width));

% -------------------------------------------------------------------------
% PTB
% -------------------------------------------------------------------------
try
    oldVDL = Screen('Preference','VisualDebugLevel', 3);
    oldSAW = Screen('Preference','SuppressAllWarnings', 1);
    wptr   = Screen('OpenWindow', screenid);
    HideCursor;
    Screen('BlendFunction', wptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Priority(MaxPriority(wptr));

    % --- Ring textures ---
    ringTex = zeros(1, nPhaseSteps);
    for step = 1:nPhaseSteps
        ringTex(step) = Screen('MakeTexture', wptr, ringImgs{step});
    end

    % --- Background & fixation textures ---
    bgTex     = Screen('MakeTexture', wptr, BGimage);
    fixTex(1) = Screen('MakeTexture', wptr, FixationImage_Green1);
    fixTex(2) = Screen('MakeTexture', wptr, FixationImage_Green2);
    fixTex(3) = Screen('MakeTexture', wptr, FixationImage_White);

    % --- Pre-trigger screen (white fixation on grey) ---
    Screen('DrawTexture', wptr, bgTex,     [], [0 0 width height]);
    Screen('DrawTexture', wptr, fixTex(3), [], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    % --- Wait for trigger ---
    [~,~,KeyCode] = KbCheck;
    while ~KeyCode(TriggerSign)
        [~,~,KeyCode] = KbCheck;
    end

    % --- Start timing ---
    tic;
    StartTime        = toc;
    LastKeyCheck     = toc;
    LastResponseTime = toc;
    lastFrameTime    = toc;

    % Post-trigger flip (green fixation)
    Screen('DrawTexture', wptr, bgTex,     [], [0 0 width height]);
    Screen('DrawTexture', wptr, fixTex(1), [], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    % ---- Log structures ----
    LogData      = [];   % [elapsed, blockCode (0 rest, 1 static, 2 moving), phaseIdx, direction]
    FixationData = [];   % [code, t]  1=green1 2=green2 3=response
    TriggerTime  = [];
    img_count    = 0;

    % Continuous ring position (real-time based, robust to frame rate)
    distanceDeg = 0;     % signed radial distance travelled, deg
    phaseIdx    = 1;

    % Fixation colour cycling: every 4-10 s (time-based)
    nextFixChange  = 4 + 6 * rand(1);
    lastFixChange  = 0;
    FixationColour = 0;
    FixIndex       = 1;  % index into fixTex

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        nowTime = toc;
        elapsed = nowTime - StartTime;
        if elapsed >= totalDuration, break; end
        dt = nowTime - lastFrameTime;
        lastFrameTime = nowTime;

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

        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        switch currentBlock.type
            case 'rest'
                blockCode = 0;
                direction = 0;
            case 'static'
                % rings frozen where the last moving block left them
                blockCode = 1;
                direction = 0;
                Screen('DrawTexture', wptr, ringTex(phaseIdx), [], [0 0 width height]);
            case 'moving'
                % direction reverses every reversalTime s within the block
                blockCode = 2;
                segIdx    = floor(localElapsed / reversalTime);
                direction = startDir * (-1) ^ segIdx;

                distanceDeg = distanceDeg + direction * speed_dps * dt;
                phaseCycles = distanceDeg / ringPeriod_deg;
                phaseIdx    = mod(floor(phaseCycles * nPhaseSteps), nPhaseSteps) + 1;
                Screen('DrawTexture', wptr, ringTex(phaseIdx), [], [0 0 width height]);
        end

        Screen('DrawTexture', wptr, fixTex(FixIndex), [], [X1 Y1 X2 Y2]);
        Screen('Flip', wptr);

        % --- Log ---
        LogData = cat(1, LogData, [elapsed, blockCode, phaseIdx, direction]);

        % --- Key checks (throttled to ~5 Hz) ---
        if toc - LastKeyCheck > 0.2
            LastKeyCheck = toc;
            [KeyIsDown, ~, KeyCode] = KbCheck;
            if KeyIsDown
                if KeyCode(escapeKey)
                    break
                elseif KeyCode(DetectKey) && (toc - LastResponseTime > 0.3)
                    FixationData = cat(1, FixationData, [3, toc - StartTime]);
                    LastResponseTime = toc;
                elseif KeyCode(TriggerSign)
                    TriggerTime = [TriggerTime, toc - StartTime];
                end
            end
        end

        % --- Fixation colour cycling (vigilance task) ---
        if elapsed - lastFixChange >= nextFixChange
            lastFixChange = elapsed;
            nextFixChange = 4 + 6 * rand(1);
            if FixationColour == 0
                FixationColour = 1; FixIndex = 2;
                FixationData   = cat(1, FixationData, [1, toc - StartTime]);
            else
                FixationColour = 0; FixIndex = 1;
                FixationData   = cat(1, FixationData, [2, toc - StartTime]);
            end
        end

        % --- Optional screenshot ---
        if save_screen
            imgDir = [runDir fs 'img'];
            if ~isfolder(imgDir), mkdir(imgDir); end
            imageArray = Screen('GetImage', wptr, [0 0 width height]);
            imwrite(imageArray, [imgDir fs 'img_' num2str(img_count) '.png']);
            img_count = img_count + 1;
        end
    end

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
    % Save SPM-style condition file (planned onsets, as bwNasrScotopic)
    % -----------------------------------------------------------------------
    names     = {'rest', 'static', 'moving'};
    onsets    = cell(1, numel(names));
    durations = cell(1, numel(names));
    for n = 1:numel(names)
        isThis       = strcmp({BlockList.type}, names{n});
        onsets{n}    = blockOnsets(isThis);
        durations{n} = [BlockList(isThis).duration];
    end

    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', ...
         'BlockList', 'staticFirst', 'mt_cfg', 'px_per_deg', '-mat');
    fprintf('Run saved to: %s\n', FileName);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    Priority(0);
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end
