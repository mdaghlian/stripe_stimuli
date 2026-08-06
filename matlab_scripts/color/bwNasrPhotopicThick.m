function bwNasrPhotopicThick(name_subj, name_sess, name_run)
% bwNasrPhotopicThick  Photopic motion localiser targeting thick-type
% (motion-selective / MT-projecting) columns as strongly as possible.
%
%   bwNasrPhotopicThick(name_subj, name_sess, name_run)
%
%   Rationale / sources (see bwNasrScotopic_photopic_motion_notes.md in
%   this folder for the full literature review):
%
%   1) The defining contrast for localising thick-type / MT columns is
%      MOVING vs. STATIONARY presentation of an otherwise identical
%      grating - not motion vs. blank, and not an orientation manipulation:
%
%        "Thick-type columns were localized by contrasting the activity
%         produced by moving (vs. stationary) gratings... MT was defined
%         as a site in the medial temporal sulcus which responds
%         strongly to the moving versus stationary stimulus contrast."
%           - Tootell & Nasr (2021) Cerebral Cortex 31(2):1163-1181
%
%      This script therefore alternates MOVING and STATIONARY blocks of
%      the same grating (same orientation/contrast/spatial frequency),
%      plus periodic blank baseline blocks. Cond.mat exposes 'rest',
%      'moving' and 'stationary' as separate regressors so the
%      moving>stationary contrast can be computed downstream.
%
%   2) That same paper used 0.2 cyc/deg specifically because it was
%      shown to drive thick- and thin-type columns EQUALLY (Tootell &
%      Nasr 2017, J Neurosci 37(33):8014-8032) - i.e. it is an unbiased
%      probe, not a motion-biased one. To push as hard as possible
%      toward the motion (magnocellular-fed) pathway, this script uses
%      a lower spatial frequency (0.1 cyc/deg - the low end of the
%      spatial-frequency sweep tested in Tootell & Nasr 2017) and a
%      higher drift speed (8 deg/s, vs. 4 deg/s in the scotopic/thin
%      localizer) so that BOTH spatial and temporal frequency lean
%      toward known magnocellular tuning (lower spatial frequency,
%      higher temporal frequency; Derrington & Lennie 1984; Shapley
%      et al. 1981, as cited in Tootell & Nasr 2017). These two numbers
%      (0.1 cyc/deg, 8 deg/s) are a literature-motivated choice, not a
%      value quoted verbatim from a single published MT localizer - see
%      the notes file for the reasoning and caveats.
%
%   3) Photopic light: present at normal photopic display luminance.
%      Unlike the scotopic script, there is no dark adaptation and no
%      neutral-density filtering required - that was a physical/room
%      setup manipulation in the source paper (mean 52 cd/m^2), not
%      something this code needs to implement.
%
%   Follows the same conventions as bwProject.m / cheqProject.m /
%   bwNasrScotopic.m in this folder.

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
stim_cpd      = 0.1;   % spatial frequency, cyc/deg - low end of Tootell &
                        % Nasr (2017) sweep (0.1/0.27/0.73/2.08/5.79),
                        % chosen to bias toward magnocellular/thick tuning
speed_dps     = 8;     % drift speed, deg/s (raised vs. the 4 deg/s
                        % scotopic/thin-column value to raise temporal
                        % frequency, which also favours the M pathway)
reversalTime  = 6;     % motion direction reversal period within a
                        % MOVING block, s (anti-adaptation; Tootell &
                        % Nasr 2021)
nCycles       = 6;     % number of [moving, stationary, blank] cycles
MovingTime    = 16;    % moving-grating block duration, s
StationaryTime= 16;    % stationary-grating block duration, s
BlankTime     = 16;    % blank block duration, s (between cycles)
initial_blank = 16;    % blank duration at run onset, s
nPhaseSteps   = 60;    % grating phase resolution (motion is driven by
                        % real elapsed time, not frame count)
fixSize       = 10;    % fixation square half-size, px
save_screen   = 0;     % set to 1 to save a screenshot every frame

% Base grating orientations to render (a grating is visually identical
% under 180 deg rotation). Orientation is not the manipulation of
% interest here (moving vs. stationary is), so one orientation is drawn
% per [moving, stationary] cycle just to avoid always using the same one.
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
pathfile = [dir_base fs name_subj fs 'bwNasrPhotopicThick' fs name_sess];
runDir   = [pathfile fs 'Run_' sprintf('%d', name_run)];
if ~isfolder(runDir)
    mkdir(runDir);
    mkdir([runDir fs 'logfiles']);
end
FileName = [runDir fs 'logfiles' fs name_subj '_' name_sess ...
            '_Run' sprintf('%d', name_run) '_bwNasrPhotopicThick'];

% -------------------------------------------------------------------------
% Orientation per cycle (independent random draw; matched between the
% moving and stationary block within a cycle so the only difference
% between those two blocks is the presence/absence of motion)
% -------------------------------------------------------------------------
cycleOri = baseOriList(randi(length(baseOriList), 1, nCycles));

% -------------------------------------------------------------------------
% Build block sequence: [blank] then nCycles x [moving, stationary, blank]
% -------------------------------------------------------------------------
BlockList = struct('type', {}, 'duration', {}, 'ori', {}, 'cycleNum', {});

BlockList(end+1) = struct('type','blank','duration',initial_blank,'ori',NaN,'cycleNum',NaN);
for c = 1:nCycles
    BlockList(end+1) = struct('type','moving',   'duration',MovingTime,     'ori',cycleOri(c),'cycleNum',c);
    BlockList(end+1) = struct('type','stationary','duration',StationaryTime,'ori',cycleOri(c),'cycleNum',c);
    BlockList(end+1) = struct('type','blank',    'duration',BlankTime,      'ori',NaN,         'cycleNum',NaN);
end

blockOnsets = zeros(1, numel(BlockList));
t = 0;
for b = 1:numel(BlockList)
    blockOnsets(b) = t;
    t = t + BlockList(b).duration;
end
totalDuration = t;

fprintf('\n--- bwNasrPhotopicThick: %s / %s / Run %d ---\n', name_subj, name_sess, name_run);
fprintf('Cycle orientations (deg): '); fprintf('%d ', cycleOri); fprintf('\n');
fprintf('Predicted run duration: %.1f s\n', totalDuration);
t_end = datetime('now') + seconds(totalDuration);
fprintf('Expected end time: %s\n\n', datestr(t_end, 'HH:MM:SS'));

% -------------------------------------------------------------------------
% Generate grating stimuli (in-memory, full contrast achromatic gratings)
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
BGimage = uint8(128 * ones(height, width));   % photopic grey background

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
    LogData      = [];   % [elapsed, blockTypeCode, orientationDeg, phaseStep, direction]
                          % blockTypeCode: 0=blank, 1=moving, 2=stationary
    FixationData = [];   % [code, t]  1=green1 2=green2 3=response
    TriggerTime  = [];
    img_count    = 0;

    % Continuous drift state (real-time based, robust to actual frame rate).
    % Only advanced during 'moving' blocks; frozen (unchanged) otherwise,
    % which is exactly what makes the 'stationary' condition stationary.
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

        isMoving    = strcmp(currentBlock.type, 'moving');
        isStationary= strcmp(currentBlock.type, 'stationary');
        isGrating   = isMoving || isStationary;

        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        direction = 0;
        if isMoving
            % Direction reverses every reversalTime s within the block.
            % Starting direction alternates cycle-to-cycle for balance.
            segIdx    = floor(localElapsed / reversalTime);
            startSign = (-1) ^ (currentBlock.cycleNum - 1);
            direction = startSign * (-1) ^ segIdx;

            distanceDeg = distanceDeg + direction * speed_dps * dt;
            phaseCycles = distanceDeg * stim_cpd;
            phaseIdx    = mod(floor(phaseCycles * nPhaseSteps), nPhaseSteps) + 1;
        end
        % isStationary: phaseIdx is simply left unchanged (frozen frame)

        if isGrating
            imgIdx = find(baseOriList == currentBlock.ori);
            Screen('DrawTexture', wptr, gratingTex(imgIdx, phaseIdx), [], [0 0 width height]);
        end

        Screen('DrawTexture', wptr, fixTex(FixIndex), [], [X1 Y1 X2 Y2]);
        Screen('Flip', wptr);

        % --- Log ---
        blockTypeCode = 0;
        if isMoving,     blockTypeCode = 1; end
        if isStationary, blockTypeCode = 2; end
        oriLog = NaN; if isGrating, oriLog = currentBlock.ori; end
        tempLog = [elapsed, blockTypeCode, oriLog, phaseIdx, direction];
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
    % Save SPM-style condition file: rest / moving / stationary. The
    % contrast of interest for isolating thick-type / MT activity is
    % moving > stationary (not moving > rest).
    % -----------------------------------------------------------------------
    isBlank      = strcmp({BlockList.type}, 'blank');
    isMovingB    = strcmp({BlockList.type}, 'moving');
    isStationaryB= strcmp({BlockList.type}, 'stationary');

    names     = {'rest', 'moving', 'stationary'};
    onsets    = {blockOnsets(isBlank), blockOnsets(isMovingB), blockOnsets(isStationaryB)};
    durations = {[BlockList(isBlank).duration], [BlockList(isMovingB).duration], [BlockList(isStationaryB).duration]};

    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', ...
         'cycleOri', 'BlockList', 'stim_cpd', 'speed_dps', 'reversalTime', ...
         'px_per_deg', 'nPhaseSteps', '-mat');
    fprintf('Run saved to: %s\n', FileName);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end
