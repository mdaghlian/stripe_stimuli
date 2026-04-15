function cheqProject(name_subj, name_sess, name_run)
% checkerProject  Present a flashing checkerboard and record responses.
%
%   checkerProject(name_subj, name_sess, name_run)
%
%   The checkerboard reverses at cheq_cfg.TF_hz Hz.
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
fixSize   = cheq_cfg.fixSize;
save_screen = cheq_cfg.save_screen;

if isfield(cheq_cfg,'initial_blank')
    initial_blank = cheq_cfg.initial_blank;
else
    initial_blank = 0;
end

if isfield(cheq_cfg,'end_blank')
    end_blank = cheq_cfg.end_blank;
else
    end_blank = 0;
end

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
pathfile = [dir_base fs name_subj fs 'cheq' fs name_sess];
stimPath = [pathfile fs 'stimuli' fs 'checkerboard_frames'];

runDir = [pathfile fs 'Run_' sprintf('%d', name_run)];
if ~isfolder(runDir)
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
% Fixation geometry
% -------------------------------------------------------------------------
X1 = width/2  - fixSize;  X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;  Y2 = height/2 + fixSize;

% -------------------------------------------------------------------------
% Fixation images (3×3 patches drawn to a small rect)
% -------------------------------------------------------------------------
FixationImage_White  = 255 * ones(3,3,3);
FixationImage_Green1 = 255 * ones(3,3,3); FixationImage_Green1(:,:,[1 3]) = 0;
FixationImage_Green2 = 180 * ones(3,3,3); FixationImage_Green2(:,:,[1 3]) = 0;
BGimage = uint8(128 * ones(height, width));   % grey background

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

    % --- Load checkerboard frames ---
    img0 = double(imread([stimPath fs 'frame0.png'])) / 65535;
    img1 = double(imread([stimPath fs 'frame1.png'])) / 65535;
    tex(1) = Screen('MakeTexture', wptr, img0, [], [], 1);  % phase 0
    tex(2) = Screen('MakeTexture', wptr, img1, [], [], 1);  % phase 1 (inverted)

    % --- Background & fixation textures ---
    bgTex    = Screen('MakeTexture', wptr, BGimage);
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
    StartTime     = toc;
    LastKeyCheck  = toc;
    LastResponseTime = toc;

    % Post-trigger flip (green fixation)
    Screen('DrawTexture', wptr, bgTex,    [], [0 0 width height]);
    Screen('DrawTexture', wptr, fixTex(1),[], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    % ---- Log structures ----
    LogData      = [];   % [t blockType frameShown]
    FixationData = [];   % [code t]  1=green1 2=green2 3=response
    rest_onset   = [];
    stim_onset   = [];
    TriggerTime  = [];
    img_count    = 0;

    % Fixation colour cycling
    FixCnt        = 0;
    FixRand       = randi(361) + 239;
    FixationColour = 0;
    FixIndex       = 1;   % index into fixTex

    % -----------------------------------------------------------------------
    % Main loop
    % -----------------------------------------------------------------------
    while true
        elapsed = toc - StartTime;
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
            % Log onset of next block on first frame it becomes current
        end

        % --- Determine which checkerboard phase (based on wall time) ---
        phaseIndex = mod(floor(elapsed / reversalPeriod), 2) + 1;
        % phaseIndex = 1 → frame0 (normal), 2 → frame1 (inverted)

        % --- Draw ---
        Screen('DrawTexture', wptr, bgTex, [], [0 0 width height]);

        if strcmp(currentBlock.type, 'on')
            Screen('DrawTexture', wptr, tex(phaseIndex), [], [0 0 width height]);
        end
        % In 'off' blocks: just grey background (already drawn)

        Screen('DrawTexture', wptr, fixTex(FixIndex), [], [X1 Y1 X2 Y2]);
        Screen('Flip', wptr);

        % --- Log ---
        isOn = strcmp(currentBlock.type,'on');
        tempLog = [elapsed, isOn, phaseIndex];
        LogData = cat(1, LogData, tempLog);

        % Track onset times (first frame of each block type)
        % Simple approach: log whenever block identity changes
        % (handled below via cumulative time comparison)

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

        % --- Fixation colour cycling ---
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
    Screen('Preference','VisualDebugLevel',   oldVDL);
    Screen('Preference','SuppressAllWarnings', oldSAW);

    % -----------------------------------------------------------------------
    % Compute onset/duration arrays for SPM-style saving
    % -----------------------------------------------------------------------
    rest_onset  = blockOnsets([BlockList.type] == 'o');   % 'off' blocks
    stim_onset  = blockOnsets([BlockList.type] == 'n');   % 'on'  blocks

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

    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', '-mat');
    fprintf('Run saved to: %s\n', FileName);

catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end