function stimViewer(name_subj, name_sess)
% stimViewer  Preview stimuli interactively.
%
%   Press 1 → flashing checkerboard (from cheqProject)
%   Press 2 → drifting B&W grating  (from colourProject, BW conditions)
%   Press 3 → colour grating         (from colourProject, colour conditions)
%   Press ESCAPE → quit
%
%   No MRI triggers, no logging, no logfiles.

close all;
cfg_start;
fs = filesep;

% -------------------------------------------------------------------------
% Config (pulled from the same cfg structs the originals use)
% -------------------------------------------------------------------------
screenid = cfg.screenid;
width    = cfg.width;
height   = cfg.height;

% --- Checkerboard params ---
TF_hz        = cheq_cfg.TF_hz;          % reversal rate (Hz)
reversalPeriod = 1 / TF_hz;
fixSize_cheq = cheq_cfg.fixSize;

% --- Grating params ---
nSteps           = stim_cfg.nSteps;
orientationList  = stim_cfg.thetaList;
colourCondLabels = stim_cfg.colourCondLabels;  % e.g. {'bw','colour'}
fixSize_grat     = stim_cfg.fixSize;

% Use the same fixSize for everything (pick one or make consistent)
fixSize = fixSize_cheq;

% --- Paths ---
dir_base     = cfg.dir_base;
% Grating stimuli live under the colour experiment folder.
% Adjust name_subj / name_sess if needed, or point directly at stimuli root.
pathfile  = [dir_base fs name_subj fs 'colour' fs name_sess];

cheqStimPath = [dir_base fs name_subj fs 'cheq' fs name_sess ...
                fs 'stimuli' fs 'checkerboard_frames'];

% -------------------------------------------------------------------------
% Keys
% -------------------------------------------------------------------------
escapeKey = KbName('ESCAPE');
key1      = KbName('1!');
key2      = KbName('2@');
key3      = KbName('3#');

% -------------------------------------------------------------------------
% Fixed geometry
% -------------------------------------------------------------------------
X1 = width/2  - fixSize;  X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;  Y2 = height/2 + fixSize;

% -------------------------------------------------------------------------
% Fixation patches
% -------------------------------------------------------------------------
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

    % --- Load checkerboard textures ---
    img0 = double(imread([cheqStimPath fs 'frame0.png'])) / 65535;
    img1 = double(imread([cheqStimPath fs 'frame1.png'])) / 65535;
    cheqTex(1) = Screen('MakeTexture', wptr, img0, [], [], 1);
    cheqTex(2) = Screen('MakeTexture', wptr, img1, [], [], 1);

    % --- Load grating textures ---
    % colourCondLabels{1} = BW conditions, colourCondLabels{end} = colour
    % Load just the first orientation for the viewer (index 1)
    for c = 1:length(colourCondLabels)
        for s = 1:nSteps
            imName = [pathfile fs 'stimuli' fs colourCondLabels{c} ...
                      '_grating_' sprintf('%d', orientationList(1)) ...
                      '_degrees' fs sprintf('%d', s) '.png'];
            img = double(imread(imName)) / 65535;
            gratingTex(c, s) = Screen('MakeTexture', wptr, img, [], [], 1);
        end
    end

    % --- Background & fixation ---
    bgTex    = Screen('MakeTexture', wptr, BGimage);
    fixWhite = Screen('MakeTexture', wptr, FixationImage_White);
    fixGreen = Screen('MakeTexture', wptr, FixationImage_Green1);

    % -----------------------------------------------------------------------
    % Instruction screen
    % -----------------------------------------------------------------------
    Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);
    Screen('TextSize', wptr, 36);
    DrawFormattedText(wptr, ...
        '1 = Flashing checkerboard\n2 = Drifting B&W grating\n3 = Colour grating\n\nESC = quit', ...
        'center', 'center', 255);
    Screen('Flip', wptr);

    % -----------------------------------------------------------------------
    % State
    % -----------------------------------------------------------------------
    currentMode = 0;   % 0 = idle, 1 = cheq, 2 = bw grating, 3 = colour grating
    cnt         = 1;   % grating frame counter
    driftDir    = 1;   % +1 or -1

    tic;
    lastDriftFlip = toc;
    driftPeriod   = 1/60;   % advance one grating step per ~16 ms (≈60 fps)

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        elapsed = toc;

        % --- Key check (every frame is fine for a viewer) ---
        [KeyIsDown, ~, KeyCode] = KbCheck;
        if KeyIsDown
            if KeyCode(escapeKey)
                break
            elseif KeyCode(key1)
                currentMode = 1;
            elseif KeyCode(key2)
                currentMode = 2;
            elseif KeyCode(key3)
                currentMode = 3;
            end
        end

        % --- Draw ---
        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        switch currentMode
            case 0   % idle – just show grey + white fixation + instructions
                Screen('TextSize', wptr, 28);
                DrawFormattedText(wptr, ...
                    '1 = Checkerboard   2 = B&W grating   3 = Colour grating   ESC = quit', ...
                    'center', height*0.85, 200);
                Screen('DrawTexture', wptr, fixWhite, [], [X1 Y1 X2 Y2]);

            case 1   % flashing checkerboard
                phaseIndex = mod(floor(elapsed / reversalPeriod), 2) + 1;
                Screen('DrawTexture', wptr, cheqTex(phaseIndex), [], [0 0 width height]);
                Screen('DrawTexture', wptr, fixGreen, [], [X1 Y1 X2 Y2]);

            case 2   % drifting B&W grating  (colourCondLabels{1})
                % Advance frame counter at ~drift rate
                if elapsed - lastDriftFlip >= driftPeriod
                    lastDriftFlip = elapsed;
                    cnt = cnt + driftDir;
                    if cnt > nSteps, cnt = 1; end
                    if cnt < 1,      cnt = nSteps; end
                end
                Screen('DrawTexture', wptr, gratingTex(1, cnt), [], [0 0 width height]);
                Screen('DrawTexture', wptr, fixGreen, [], [X1 Y1 X2 Y2]);

            case 3   % colour grating  (last colourCondLabels entry)
                if elapsed - lastDriftFlip >= driftPeriod
                    lastDriftFlip = elapsed;
                    cnt = cnt + driftDir;
                    if cnt > nSteps, cnt = 1; end
                    if cnt < 1,      cnt = nSteps; end
                end
                Screen('DrawTexture', wptr, gratingTex(end, cnt), [], [0 0 width height]);
                Screen('DrawTexture', wptr, fixGreen, [], [X1 Y1 X2 Y2]);
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
