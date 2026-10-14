function stimViewerLive()
% stimViewerLive  Preview stimuli interactively - no participant/session
% needed, no disk-based stimuli. Everything is generated on the fly.
%
%   stimViewerLive()
%
%   Unlike stimViewer.m (which loads pre-rendered PNGs from a specific
%   participant's stimuli folder), this version builds every stimulus
%   procedurally at runtime, using the same maths as makeCheq.m /
%   makeStimuli.m / bwNasrScotopic.m / bwNasrPhotopicThick.m. Nothing is
%   read from or written to disk, so it can be run standalone, e.g. for
%   quickly sanity-checking display geometry or a new parameter set.
%
%   Keys:
%     1        -> flashing radial checkerboard (cheq_cfg params)
%     2        -> drifting B&W grating          (stim_cfg.stim_cpd, e.g. 0.4 cyc/deg)
%     3        -> drifting colour grating        (uncalibrated preview - NOT isoluminance corrected)
%     4        -> Nasr scotopic-style grating    (0.2 cyc/deg, 4 deg/s, direction reverses every 6 s)
%     5        -> Nasr photopic-thick grating    (0.1 cyc/deg, 8 deg/s - see bwNasrPhotopicThick.m)
%     Left/Right arrows -> cycle grating orientation (modes 2-5)
%     M        -> toggle motion on/off (moving vs. stationary - the actual
%                 contrast bwNasrPhotopicThick.m uses to target thick-type
%                 columns; handy for previewing that condition directly)
%     ESCAPE   -> quit
%
%   No MRI triggers, no logging, no logfiles, no participant folders.

close all;
cfg_start;

% -------------------------------------------------------------------------
% Config (pulled from the same cfg structs the real experiment scripts use)
% -------------------------------------------------------------------------
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
image_frac  = cfg.image_frac;
distance_cm = cfg.distance_cm;
height_cm   = cfg.height_cm;

% --- Checkerboard params ---
TF_hz          = cheq_cfg.TF_hz;
reversalPeriod = 1 / TF_hz;
cheq_cpd       = cheq_cfg.stim_cpd;
nWedges        = cheq_cfg.nWedges;

% --- Grating geometry (shared by all grating modes) ---
gw = round(width  * image_frac);
gh = round(height * image_frac);
px_per_cm  = gh / height_cm;                    % accounts for downsampling
cm_per_deg = 2 * distance_cm * tan(deg2rad(0.5));
deg_per_px = 1 / (px_per_cm * cm_per_deg);
[Xm, Ym]   = meshgrid(1:gw, 1:gh);

nPhaseSteps = 40;              % phase resolution for the live viewer
baseOriList = [0 45 90 135];   % cycled with left/right arrows

% Mode presets: cyc/deg, speed (deg/s), colour flag, label.
% Modes 2/3 match the standard bwProject/colourProject grating; modes 4/5
% match bwNasrScotopic.m / bwNasrPhotopicThick.m respectively.
modeCPD    = containers.Map({2,3,4,5}, {stim_cfg.stim_cpd, stim_cfg.stim_cpd, 0.2, 0.1});
modeSpeed  = containers.Map({2,3,4,5}, {4, 4, 4, 8});
modeColour = containers.Map({2,3,4,5}, {false, true, false, false});
modeLabel  = containers.Map({2,3,4,5}, { ...
    sprintf('B&W grating (%.2f cyc/deg)', stim_cfg.stim_cpd), ...
    sprintf('Colour grating - UNCALIBRATED preview (%.2f cyc/deg)', stim_cfg.stim_cpd), ...
    'Nasr scotopic-style (0.2 cyc/deg, 4 deg/s, auto-reverses every 6 s)', ...
    'Nasr photopic-thick (0.1 cyc/deg, 8 deg/s) - press M for moving/stationary'});

fixSize = 10;

% -------------------------------------------------------------------------
% Keys
% -------------------------------------------------------------------------
escapeKey  = KbName('ESCAPE');
key1       = KbName('1!');
key2       = KbName('2@');
key3       = KbName('3#');
key4       = KbName('4$');
key5       = KbName('5%');
keyLeft    = KbName('LeftArrow');
keyRight   = KbName('RightArrow');
keyM       = KbName('m');

% -------------------------------------------------------------------------
% Fixed geometry
% -------------------------------------------------------------------------
X1 = width/2  - fixSize;  X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;  Y2 = height/2 + fixSize;

FixationImage_White  = 255 * ones(3,3,3);
FixationImage_Green1 = 255 * ones(3,3,3); FixationImage_Green1(:,:,[1 3]) = 0;
BGimage = uint8(128 * ones(height, width));

% -------------------------------------------------------------------------
% PTB open
% -------------------------------------------------------------------------
try
    oldVDL = Screen('Preference','VisualDebugLevel', 3);
    oldSAW = Screen('Preference','SuppressAllWarnings', 1);
    wptr   = Screen('OpenWindow', screenid);
    HideCursor;
    Screen('BlendFunction', wptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % --- Build checkerboard textures (once, procedurally - see makeCheq.m) ---
    [cheqTex, ~] = buildCheckerboardTextures(wptr, width, height, distance_cm, height_cm, cheq_cpd, nWedges);

    % --- Background & fixation ---
    bgTex    = Screen('MakeTexture', wptr, BGimage);
    fixWhite = Screen('MakeTexture', wptr, FixationImage_White);
    fixGreen = Screen('MakeTexture', wptr, FixationImage_Green1);

    % -----------------------------------------------------------------------
    % Instruction screen
    % -----------------------------------------------------------------------
    Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);
    Screen('TextSize', wptr, 32);
    DrawFormattedText(wptr, ...
        ['1 = Checkerboard\n2 = B&W grating\n3 = Colour grating (uncalibrated)\n' ...
         '4 = Nasr scotopic-style\n5 = Nasr photopic-thick\n\n' ...
         'Left/Right = orientation   M = toggle motion   ESC = quit'], ...
        'center', 'center', 255);
    Screen('Flip', wptr);

    % -----------------------------------------------------------------------
    % State
    % -----------------------------------------------------------------------
    currentMode = 0;    % 0 = idle, 1 = cheq, 2-5 = grating modes
    oriIdx      = 1;    % index into baseOriList
    motionOn    = true;

    gratingTex   = [];  % current phase-step texture stack (grating modes)
    builtMode    = -1;  % which mode/orientation/cpd gratingTex was built for
    builtOriIdx  = -1;

    phaseIdx    = 1;
    distanceDeg = 0;

    tic;
    lastFrameTime = toc;
    segStart      = toc;   % start of current 6 s reversal segment (mode 4)
    direction     = 1;

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        nowTime = toc;
        dt = nowTime - lastFrameTime;
        lastFrameTime = nowTime;

        % --- Key check ---
        [KeyIsDown, ~, KeyCode] = KbCheck;
        if KeyIsDown
            if KeyCode(escapeKey)
                break
            elseif KeyCode(key1), currentMode = 1;
            elseif KeyCode(key2), currentMode = 2;
            elseif KeyCode(key3), currentMode = 3;
            elseif KeyCode(key4), currentMode = 4;
            elseif KeyCode(key5), currentMode = 5;
            elseif KeyCode(keyLeft)
                oriIdx = mod(oriIdx - 2, length(baseOriList)) + 1;
                WaitSecs(0.15);   % simple debounce
            elseif KeyCode(keyRight)
                oriIdx = mod(oriIdx, length(baseOriList)) + 1;
                WaitSecs(0.15);
            elseif KeyCode(keyM)
                motionOn = ~motionOn;
                WaitSecs(0.2);
            end
        end

        % --- (Re)build grating textures if mode/orientation changed ---
        if ismember(currentMode, [2 3 4 5]) && ...
                (currentMode ~= builtMode || oriIdx ~= builtOriIdx)
            if ~isempty(gratingTex)
                Screen('Close', gratingTex);
            end
            cpd_here    = modeCPD(currentMode);
            isColour    = modeColour(currentMode);
            thetaDeg    = baseOriList(oriIdx);
            spatialFreq_cpp = cpd_here * deg_per_px;
            gratingTex  = buildGratingTextures(wptr, Xm, Ym, spatialFreq_cpp, thetaDeg, nPhaseSteps, isColour);
            builtMode   = currentMode;
            builtOriIdx = oriIdx;
            phaseIdx    = 1;
            distanceDeg = 0;
            segStart    = nowTime;
        end

        % --- Draw ---
        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        switch currentMode
            case 0   % idle
                Screen('TextSize', wptr, 26);
                DrawFormattedText(wptr, ...
                    '1 Cheq   2 BW   3 Colour   4 Scotopic   5 PhotopicThick   |/-> ori   M motion   ESC quit', ...
                    'center', height*0.9, 200);
                Screen('DrawTexture', wptr, fixWhite, [], [X1 Y1 X2 Y2]);

            case 1   % flashing checkerboard
                phaseIndex = mod(floor(nowTime / reversalPeriod), 2) + 1;
                Screen('DrawTexture', wptr, cheqTex(phaseIndex), [], [0 0 width height]);
                Screen('DrawTexture', wptr, fixGreen, [], [X1 Y1 X2 Y2]);
                drawStatusText(wptr, height, sprintf('Checkerboard: %.2f cyc/deg radial, %d wedges, %.1f Hz reversal', cheq_cpd, nWedges, TF_hz));

            otherwise   % 2-5: drifting/static gratings
                speed_dps = modeSpeed(currentMode);
                cpd_here  = modeCPD(currentMode);

                if motionOn
                    if currentMode == 4
                        % Nasr scotopic-style: auto-reverse direction every 6 s
                        if nowTime - segStart >= 6
                            segStart  = nowTime;
                            direction = -direction;
                        end
                    end
                    distanceDeg = distanceDeg + direction * speed_dps * dt;
                    phaseCycles = distanceDeg * cpd_here;
                    phaseIdx    = mod(floor(phaseCycles * nPhaseSteps), nPhaseSteps) + 1;
                end
                % motionOn == false: phaseIdx frozen (stationary condition)

                Screen('DrawTexture', wptr, gratingTex(phaseIdx), [], [0 0 width height]);
                Screen('DrawTexture', wptr, fixGreen, [], [X1 Y1 X2 Y2]);

                motionLabel = 'moving';
                if ~motionOn, motionLabel = 'STATIONARY'; end
                drawStatusText(wptr, height, sprintf('%s | orientation %d deg | %s', ...
                    modeLabel(currentMode), baseOriList(oriIdx), motionLabel));
        end

        Screen('Flip', wptr);
    end

    % -----------------------------------------------------------------------
    % Clean up
    % -----------------------------------------------------------------------
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',    oldVDL);
    Screen('Preference','SuppressAllWarnings', oldSAW);

catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end

end % main function


% =============================================================================
function tex = buildGratingTextures(wptr, Xm, Ym, spatialFreq_cpp, thetaDeg, nPhaseSteps, isColour)
% Build one full cycle of phase-stepped grating textures at the given
% orientation/spatial frequency. Same construction as makeStimuli.m /
% bwNasrScotopic.m, but without any isoluminance fitting - the colour
% mode here is an UNCALIBRATED preview only.

thetaRad = deg2rad(thetaDeg);
Xt = Xm * cos(thetaRad) + Ym * sin(thetaRad);
Xp = Xt * spatialFreq_cpp * 2 * pi;

[gh, gw] = size(Xm);
phaseStep = 1 / nPhaseSteps;
tex = zeros(1, nPhaseSteps);

for step = 1:nPhaseSteps
    phaseRad = phaseStep * step * 2 * pi;
    gratingA = sin(Xp + phaseRad);                 % [-1, 1]

    if isColour
        gratingB = sin(Xp + phaseRad + pi);         % 180 deg out of phase
        img = zeros(gh, gw, 3);
        img(:,:,1) = ((gratingA + 1) / 2) * 255;    % red channel
        img(:,:,3) = ((gratingB + 1) / 2) * 255;    % blue channel
        img = uint8(img);
    else
        img = uint8(((gratingA + 1) / 2) * 255);
    end

    tex(step) = Screen('MakeTexture', wptr, img);
end
end


% =============================================================================
function [tex, checkerMeta] = buildCheckerboardTextures(wptr, width, height, distance_cm, height_cm, cpd, nWedges)
% Build the two-frame flashing radial checkerboard, procedurally.
% Identical maths to makeCheq.m, just done in memory instead of on disk.

px_per_cm  = height / height_cm;
cm_per_deg = 2 * distance_cm * tan(deg2rad(0.5));
deg_per_px = 1 / (px_per_cm * cm_per_deg);

[Xm, Ym] = meshgrid(1:width, 1:height);
cx = width  / 2;
cy = height / 2;
Xc = Xm - cx;
Yc = Ym - cy;

R_px  = sqrt(Xc.^2 + Yc.^2);
R_deg = R_px * deg_per_px;
Theta = atan2(Yc, Xc);

radialPart  = sin(2 * pi * cpd * R_deg);
angularPart = sin(nWedges * Theta);
checker = sign(radialPart) .* sign(angularPart);
checker(R_px < 1) = 0;

frame0 = uint8(((checker + 1) / 2) * 255);
frame1 = uint8(((-checker + 1) / 2) * 255);

tex(1) = Screen('MakeTexture', wptr, frame0);
tex(2) = Screen('MakeTexture', wptr, frame1);

checkerMeta.deg_per_px = deg_per_px;
end


% =============================================================================
function drawStatusText(wptr, height, txt)
Screen('TextSize', wptr, 22);
DrawFormattedText(wptr, txt, 'center', height*0.93, 220);
end
