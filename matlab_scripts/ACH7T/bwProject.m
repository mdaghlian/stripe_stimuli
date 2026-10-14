function bwProject(name_subj, name_sess, name_run)

close all;
cfg_start;
fs = filesep;

% Set default values
if ~exist('name_subj','var')
    name_subj = 'TestSubj';
end
if ~exist('name_sess','var')
    name_sess = 'TestSess';
end
if ~exist('name_run','var')
    name_run = 1;
end

warning('off');
warning('on');

dir_base = cfg.dir_base;

% ADJUSTABLE PARAMETERS
screenid    = cfg.screenid;
width       = cfg.width;
height      = cfg.height;
nBlocks     = stim_cfg.nBlocks;
nConditions = stim_cfg.nConditions / 2;  % BW only: half the original conditions
nRuns       = stim_cfg.nRuns;
BlockTime   = stim_cfg.BlockTime;
DelayTime   = stim_cfg.DelayTime;
save_screen = stim_cfg.save_screen;

nSteps          = stim_cfg.nSteps;
orientationList = stim_cfg.thetaList;
fixSize         = stim_cfg.fixSize;

% INITIALISE KEYS
escapeKey   = KbName('ESCAPE');
DetectKey   = KbName('1!');
TriggerSign = KbName('5%');

% LOGFILE
pathfile = [dir_base fs name_subj fs 'bw' fs name_sess];  % 'bw' subfolder instead of 'colour'
if isdir([pathfile fs 'Run_' sprintf('%d', name_run)]) == 0
    status = mkdir([pathfile fs 'Run_' sprintf('%d', name_run)]);
    if ~status
        error('No such participant or session. Check inputs!');
    else
        mkdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'logfiles']);
    end
end

FileName     = [pathfile fs 'Run_' sprintf('%d',name_run)     fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run)     '_bw'];
FileName_old = [pathfile fs 'Run_' sprintf('%d',name_run - 1) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run - 1) '_bw'];

% EXPERIMENTAL PARADIGM
% nConditions is now the number of BW orientations only.
% No colour/BW balance check is needed — every block is BW.
if name_run == 1
    redo = 1;
    while redo
        redo = 0;
        temp = [];
        for i = 1:nBlocks / nConditions
            temp = [temp 1:nConditions];
        end
        temp = temp(randperm(length(temp)));

        % Reject if any two consecutive blocks share the same condition
        for i = 1:length(temp) - 1
            if temp(i) == temp(i + 1)
                redo = 1;
                break
            end
        end
    end
    Sequence = 2 * temp;

else
    load([FileName_old '.mat']);
    clear FixationData LogData

    redo = 1;
    while redo
        redo = 0;
        temp = [];
        for i = 1:nBlocks / nConditions
            temp = [temp 1:nConditions];
        end
        temp = temp(randperm(length(temp)));

        for i = 1:length(temp) - 1
            if temp(i) == temp(i + 1)
                redo = 1;
                break
            end
        end
    end
    Sequence = 2 * temp;
end

disp('sequence'); disp(Sequence);

% Build Block list — identical structure to colourProject
Block = 0;
for i = 1:length(Sequence)
    Block = [Block Sequence(i) Sequence(i) - 1];
end
Block = [Block 0];

BlockSeq    = [];
BlockSeqDir = [];
for i = 1:length(Block)
    if Block(i) == 0
        BlockSeq    = [BlockSeq    zeros(1, DelayTime)];
        BlockSeqDir = [BlockSeqDir zeros(1, DelayTime)];
    else
        BlockSeq = [BlockSeq ones(1, BlockTime / 2) * Block(i)];
        if mod(Block(i), 2) == 0
            BlockSeqDir = [BlockSeqDir  ones(1, BlockTime/6)*Block(i) -ones(1, BlockTime/6)*Block(i)  ones(1, BlockTime/6)*Block(i)];
        else
            BlockSeqDir = [BlockSeqDir -ones(1, BlockTime/6)*Block(i)  ones(1, BlockTime/6)*Block(i) -ones(1, BlockTime/6)*Block(i)];
        end
    end
end

% PRINT RUN DURATION
totalFrames = length(BlockSeq) - FadingTime;
totalSecs   = totalFrames;  % BlockSeq is built in seconds (one entry per second)
totalMins   = floor(totalSecs / 60);
remainSecs  = mod(totalSecs, 60);
fprintf('\n--- Run %d of %d ---\n', name_run, nRuns);
fprintf('Duration: %d min %d sec\n', totalMins, remainSecs);
fprintf('Blocks:   %d active + delay periods\n', nBlocks);
fprintf('Sequence: '); fprintf('%d ', Sequence); fprintf('\n\n');

% FIXED PARAMETERS
X1 = width/2  - fixSize;
X2 = width/2  + fixSize;
Y1 = height/2 - fixSize;
Y2 = height/2 + fixSize;

% FIXATION COLOUR DEFINITION
FixationImage_White  = 255 * ones(3,3,3);
FixationImage_Green1 = 255 * ones(3,3,3); FixationImage_Green1(:,:,[1 3]) = 0;
FixationImage_Green2 = 180 * ones(3,3,3); FixationImage_Green2(:,:,[1 3]) = 0;
Image = uint8(128 * ones(height, width));  % grey background

% OPEN PSYCHTOOLBOX WINDOW
try
    oldVisualDebugLevel    = Screen('Preference','VisualDebugLevel', 3);
    oldSuppressAllWarnings = Screen('Preference','SuppressAllWarnings', 1);
    wptr = Screen('OpenWindow', screenid);
    HideCursor;
    Screen('BlendFunction', wptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % Load BW stimuli only
    for or = 1:length(orientationList)
        for s = 1:nSteps
            imName = [pathfile fs 'stimuli' fs 'bw_grating_' sprintf('%d', orientationList(or)) '_degrees' fs sprintf('%d', s) '.png'];
            image  = (double(imread(imName)) / 65535);
            gratingTexture(or, s) = Screen('MakeTexture', wptr, image, [], [], 1);
        end
    end

    % Load background and fixation textures
    textureIndex(1) = Screen('MakeTexture', wptr, Image);
    textureIndex(2) = Screen('MakeTexture', wptr, FixationImage_Green1);
    textureIndex(3) = Screen('MakeTexture', wptr, FixationImage_Green2);
    textureIndex(4) = Screen('MakeTexture', wptr, FixationImage_White);

    % Show start screen, wait for trigger
    Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
    Screen('DrawTexture', wptr, textureIndex(4), [], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    [~,~,KeyCode] = KbCheck;
    while ~KeyCode(TriggerSign)
        [~,~,KeyCode] = KbCheck;
    end

    tic;
    Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
    Screen('DrawTexture', wptr, textureIndex(2), [], [X1 Y1 X2 Y2]);
    Screen('Flip', wptr);

    StartTime     = toc;
    LastResponseTime = toc;
    LastKeyCheck  = toc;

    cnt           = 1;
    FixationColour = 0;
    FixIndex      = 3;
    FixCnt        = 0;
    FixRand       = 0;
    FadingTime    = 1;
    FadeNeg       = 0;
    FadePos       = 0;
    OnsetPos      = 0;
    alphaImg      = 0;
    KeyIsDown     = 0;
    rest_onset    = [];
    bw_onset      = [];       % only BW onsets recorded (no colour_onset)
    LogData       = [];
    FixationData  = [];
    TriggerTime   = [];
    img_count     = 0;

    BlockSeq    = [BlockSeq    zeros(1, FadingTime)];
    BlockSeqDir = [BlockSeqDir zeros(1, FadingTime)];

    while toc - StartTime < length(BlockSeq) - FadingTime
        t = floor(toc - StartTime + 1);

        if BlockSeq(t) == 0
            Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
            Screen('DrawTexture', wptr, textureIndex(FixIndex), [], [X1 Y1 X2 Y2]);
            if OnsetPos == 0
                OnsetPos  = 1;
                rest_onset = [rest_onset toc - StartTime];
            end
        else
            OnsetPos = 0;

            if (mod(BlockSeq(t), 2) == 1 && mod(BlockSeq(min(t + FadingTime, length(BlockSeq))), 2) == 0)
                % Fading out
                if FadeNeg == 0
                    fadeStart = toc - StartTime;
                    FadeNeg   = 1;
                    FadePos   = 0;
                end
                alphaImg = 1 - ((toc - StartTime) - fadeStart);
                if alphaImg < 0, alphaImg = 0; end
            else
                % Fading in
                if FadePos == 0
                    bw_onset = [bw_onset toc - StartTime];
                    fadeStart = toc - StartTime;
                    FadeNeg   = 0;
                    FadePos   = 1;
                end
                alphaImg = (toc - StartTime) - fadeStart;
                if alphaImg > 1, alphaImg = 1; end
            end

            % imgIndex maps block ID to orientation: ceil(blockID / 2)
            imgIndex = ceil(BlockSeq(t) / 2);

            if BlockSeqDir(t) > 0
                cnt = cnt - 1;
                if cnt < 1, cnt = nSteps; end
            else
                cnt = cnt + 1;
                if cnt > nSteps, cnt = 1; end
            end

            Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
            Screen('DrawTexture', wptr, gratingTexture(imgIndex, cnt), [], [0 0 width height], [], [], alphaImg);
            Screen('DrawTexture', wptr, textureIndex(FixIndex), [], [X1 Y1 X2 Y2]);
        end

        tempLog = [toc - StartTime BlockSeq(t) cnt alphaImg];
        LogData = cat(1, LogData, tempLog);
        Screen('Flip', wptr);

        % Key checks
        if toc - LastKeyCheck > 0.2
            LastKeyCheck = toc;
            [KeyIsDown,~,KeyCode] = KbCheck;
            if KeyIsDown
                KeyIsDown = 0;
                if KeyCode(escapeKey)
                    break
                elseif (KeyCode(DetectKey) && toc - LastResponseTime > 0.3)
                    FixationData     = cat(1, FixationData, [3 toc - StartTime]);
                    LastResponseTime = toc;
                elseif KeyCode(TriggerSign)
                    TriggerTime = [TriggerTime toc - StartTime];
                end
            end
        end

        % Randomise fixation colour
        if FixCnt == FixRand
            FixCnt  = 0;
            FixRand = randi(361) + 239;
            if FixationColour == 1
                FixationColour = 0;
                FixIndex       = 2;
                FixationData   = cat(1, FixationData, [2 toc - StartTime]);
            else
                FixationColour = 1;
                FixIndex       = 3;
                FixationData   = cat(1, FixationData, [1 toc - StartTime]);
            end
        end
        FixCnt = FixCnt + 1;

        % Save screenshots
        if save_screen ~= 0
            if isdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']) == 0
                mkdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']);
            end
            imageArray = Screen('GetImage', wptr, [0 0 width height]);
            imwrite(imageArray, [pathfile fs 'Run_' sprintf('%d', name_run) fs 'img' fs 'img_' num2str(img_count) '.png']);
            img_count = img_count + 1;
        end
    end

    % End screen
    Screen('FillRect', wptr, [0 0 0], [0 0 width height]);
    Screen('Flip', wptr);
    exitFlag = 0;
    while ~exitFlag
        [~,~,KeyCode] = KbCheck;
        if KeyCode(escapeKey), exitFlag = 1; end
    end

    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',    oldVisualDebugLevel);
    Screen('Preference','SuppressAllWarnings', oldSuppressAllWarnings);

    % Save results — two conditions only: rest and bw
    names     = {'rest', 'bw'};
    onsets    = {rest_onset, bw_onset};
    durations = {DelayTime,  BlockTime};

    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'], 'FixationData', 'LogData', 'TriggerTime', '-mat');
    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end