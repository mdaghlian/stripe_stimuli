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
%   Timing: each run opens with a 16 s spatially-uniform (blank) field,
%   followed by 7 blocks of 16 s stimulation, each block followed by
%   16 s blank. Total run duration = 16 + 7*(16+16) = 240 s.
%
%   Follows the same conventions as bwProject.m / cheqProject.m in this
%   folder (cfg_start for display geometry, PTB draw loop, fixation
%   vigilance task, SPM-style Cond.mat + raw logfile .mat output).

close all
cfg_start;
fs = filesep;

if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess',  'var'), name_sess  = 'TestSess'; end
if ~exist('name_run',   'var'), name_run   = 1;          end

% -------------------------------------------------------------------------
% Unpack display config (from cfg_start)
% -------------------------------------------------------------------------
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
image_frac  = cfg.image_frac;
distance_cm = cfg.distance_cm;
height_cm   = cfg.height_cm;
dir_base    = cfg.dir_base;

% -------------------------------------------------------------------------
% ADJUSTABLE STIMULUS PARAMETERS
% -------------------------------------------------------------------------
stim_cpd      = 0.2;   % spatial frequency, cycles/degree
speed_dps     = 4;     % drift speed, deg/s
reversalTime  = 6;     % motion direction reversal period within a block, s
oriStep       = 45;    % orientation step between blocks, deg
nBlocks       = 7;     % number of stimulation blocks
BlockTime     = 16;    % stimulation block duration, s
BlankTime     = 16;    % blank duration after each block, s
initial_blank = 16;    % blank duration at run onset, s
nPhaseSteps   = 60;    % grating phase resolution (motion is driven by
                        % real elapsed time, not frame count, so this
                        % only sets how finely phase is quantised)
fixSize       = 10;    % fixation square half-size, px
save_screen   = 0;     % set to 1 to save a screenshot every frame

% Base grating orientations that actually need to be rendered. A grating
% is visually identical under a 180 deg rotation, so the 45-deg block
% sequence (which can run past 180) only ever needs these 4 images.
baseOriList = [0 45 90 135];

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
runDir   = [pathfile fs 'Run_' sprintf('%d', name_run)];
if ~isfolder(runDir)
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
% Generate grating stimuli (in-memory, no disk dependency / isoluminance
% fitting needed - full-contrast achromatic gratings only)
% -------------------------------------------------------------------------
gw = round(width  * image_frac);
gh = round(height * image_frac);

px_per_cm   = gh / height_cm;                       % accounts for downsampling
cm_per_deg  = 2 * distance_cm * tan(deg2rad(0.5));
deg_per_px  = 1 / (px_per_cm * cm_per_deg);
px_per_deg  = 1 / deg_per_px;
spatialFreq_cpp = stim_cpd * deg_per_px;             % cycles per pixel

X = 1:gw; Y = 1:gh;
[Xm, Ym] = meshgrid(X, Y);

phaseStep = 1 / nPhaseSteps;
gratingImgs = cell(length(baseOriList), nPhaseSteps);
for o = 1:length(baseOriList)
    thetaRad = deg2rad(baseOriList(o));
    Xt = Xm * cos(thetaRad) + Ym * sin(thetaRad);
    Xp = Xt * spatialFreq_cpp * 2 * pi;
    for step = 1:nPhaseSteps
        phaseRad = phaseStep * step * 2 * pi;
        grating  = sin(Xp + phaseRad);                       % [-1, 1]
        gratingImgs{o, step} = uint8(((grating + 1) / 2) * 255); % max contrast, 0-255
    end
end

% -------------------------------------------------------------------------
% Fixation geometry & images
% -------------------------------------------------------------------------
X1 = width/2  - fixSize;  X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;  Y2 = height/2 + fixSize;

FixationImage_White  = 255 * ones(3,3,3);
FixationImage_Green1 = 255 * ones(3,3,3); FixationImage_Green1(:,:,[1 3]) = 0;
FixationImage_Green2 = 180 * ones(3,3,3); FixationImage_Green2(:,:,[1 3]) = 0;
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

    % --- Grating textures ---
    gratingTex = zeros(length(baseOriList), nPhaseSteps);
    for o = 1:length(baseOriList)
        for step = 1:nPhaseSteps
            gratingTex(o, step) = Screen('MakeTexture', wptr, gratingImgs{o, step});
        end
    end

    % --- Background & fixation textures ---
    bgTex     = Screen('MakeTexture', wptr, BGimage);
    fixTex(1) = Screen('MakeTexture', wptr, FixationImage_Green1);
    fixTex(2) = Screen('MakeTexture', wptr, FixationImage_Green2);
    fixTex(3) = Screen('MakeTexture', wptr, FixationImage_White);

    % --- Pre-trigger screen (white fixation on grey) ---
    Screen('DrawTexture', wptr, bgTex,    [], [0 0 width height]);
    Screen('DrawTexture', wptr, fixTex(3),[], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    % --- Wait for trigger ---
    [~,~,KeyCode] = KbCheck;
    while ~KeyCode(TriggerSign)
        [~,~,KeyCode] = KbCheck;
    end

    % --- Start timing ---
    tic;
    StartTime        = toc;
    LastKeyCheck      = toc;
    LastResponseTime  = toc;
    lastFrameTime     = toc;

    % Post-trigger flip (green fixation)
    Screen('DrawTexture', wptr, bgTex,    [], [0 0 width height]);
    Screen('DrawTexture', wptr, fixTex(1),[], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    % ---- Log structures ----
    LogData      = [];   % [elapsed, isStim, orientationDeg, phaseStep, direction]
    FixationData = [];   % [code, t]  1=green1 2=green2 3=response
    TriggerTime  = [];
    img_count    = 0;

    % Continuous drift state (real-time based, robust to actual frame rate)
    distanceDeg  = 0;    % signed distance travelled along motion axis, deg
    phaseIdx     = 1;

    % Fixation colour cycling
    FixCnt         = 0;
    FixRand        = randi(361) + 239;
    FixationColour = 0;
    FixIndex       = 1;   % index into fixTex

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

        isStim = strcmp(currentBlock.type, 'stim');

        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        if isStim
            % Direction reverses every reversalTime s within the block.
            % Starting direction alternates block-to-block for balance.
            segIdx    = floor(localElapsed / reversalTime);
            startSign = (-1) ^ (currentBlock.stimNum - 1);
            direction = startSign * (-1) ^ segIdx;

            distanceDeg = distanceDeg + direction * speed_dps * dt;
            phaseCycles = distanceDeg * stim_cpd;
            phaseIdx    = mod(floor(phaseCycles * nPhaseSteps), nPhaseSteps) + 1;

            imgIdx = imgOriIdx(currentBlock.stimNum);
            Screen('DrawTexture', wptr, gratingTex(imgIdx, phaseIdx), [], [0 0 width height]);
        else
            direction = 0;
        end

        Screen('DrawTexture', wptr, fixTex(FixIndex), [], [X1 Y1 X2 Y2]);
        Screen('Flip', wptr);

        % --- Log ---
        oriLog = NaN; if isStim, oriLog = currentBlock.ori; end
        tempLog = [elapsed, isStim, oriLog, phaseIdx, direction];
        LogData = cat(1, LogData, tempLog);

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
        FixCnt = FixCnt + 1;
        if FixCnt >= FixRand
            FixCnt  = 0;
            FixRand = randi(361) + 239;
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

    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', ...
         'oriSeq', 'BlockList', 'stim_cpd', 'speed_dps', 'reversalTime', ...
         'px_per_deg', 'nPhaseSteps', '-mat');
    fprintf('Run saved to: %s\n', FileName);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end
