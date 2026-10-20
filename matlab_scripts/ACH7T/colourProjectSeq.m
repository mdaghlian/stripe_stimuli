function colourProjectSeq(name_subj, name_sess, name_run)

close all;
cfg_start;
fs = filesep;

% Set default values for subject, session, and run if not provided
if ~exist('name_subj','var'),  name_subj = 'TestSubj'; end
if ~exist('name_sess','var'),  name_sess = 'TestSess'; end
if ~exist('name_run','var'),   name_run  = 1;          end

% DIRECTORY
warning('off');
addpath(genpath(cfg.PTB_dir));
warning('on');

dir_base = cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end

% ADJUSTABLE PARAMETERS
screenid         = cfg.screenid;
width            = cfg.width;
height           = cfg.height;

BlockTime        = stim_cfg.BlockTime;   % duration of each half-block (forward OR reverse)
DelayTime        = stim_cfg.DelayTime;
FadingTime       = stim_cfg.FadingTime;   % seconds for fade in / fade out
if FadingTime <= 0 || FadingTime > BlockTime/2
    error('stim_cfg.FadingTime must be > 0 and <= BlockTime/2 (%g s).', BlockTime/2);
end
save_screen      = stim_cfg.save_screen;
nSteps           = stim_cfg.nPhaseSteps;
orientationList  = stim_cfg.thetaList;
colourCondLabels = stim_cfg.colourCondLabels;

% condition_list defines the order of stimulus types and rest periods.
% Each non-rest entry will be expanded into nOriPerStim * 2 consecutive
% half-blocks (forward then reverse) in the final expanded_list.
condition_list = stim_cfg.Bcondition_list;

% INITIALISE KEYS
escapeKey   = KbName('ESCAPE');
DetectKey   = KbName('1!');
TriggerSign = KbName('5%');

%==========================================================================
% LOGFILE
%==========================================================================
% Stimuli are shared with colourProject (<pathfile>/stimuli), but runs and
% logs are kept separate (SeqRun_<n>, *_colourSeq) so neither script
% overwrites the other's logfiles.
pathfile = [dir_base fs name_subj fs 'colour' fs name_sess];
runDir   = [pathfile fs 'SeqRun_' sprintf('%d', name_run)];
if ~isdir(runDir)
    status = mkdir(runDir);
    if ~status
        error('No such participant or session. Check inputs!');
    end
    mkdir([runDir fs 'logfiles']);
end

FileName = [runDir fs 'logfiles' fs ...
            name_subj '_' name_sess '_Run' sprintf('%d', name_run) '_colourSeq'];

% The stimuli on disk must have exactly nSteps frames per orientation
% (they are written by makeStimuli with stim_cfg.nPhaseSteps)
stimCheck=[pathfile fs 'stimuli' fs colourCondLabels{1} '_grating_' sprintf('%d',orientationList(1)) '_degrees' fs];
if exist([stimCheck sprintf('%d',nSteps) '.png'],'file')~=2 || exist([stimCheck sprintf('%d',nSteps+1) '.png'],'file')==2
    error('Stimuli in %s do not have stim_cfg.nPhaseSteps = %d frames. Regenerate them with makeStimuli.', stimCheck, nSteps);
end

%==========================================================================
% BUILD STIMULUS SEQUENCES
%
% For each non-rest condition in condition_list:
%   - Draw nOriPerStim orientations from the counterbalanced pool
%   - For each orientation, insert TWO consecutive half-blocks:
%       half-block 1: forward  (dirCode = +1)
%       half-block 2: reverse  (dirCode = -1)
%
% Rest entries pass through as a single block (no orientation assigned).
%
% Result: expanded_list, ori_seq, dir_seq — all length nBlocks.
%==========================================================================
nOr         = numel(orientationList);
nOriPerStim = stim_cfg.Bori_per_stim;

isRest     = strcmpi(condition_list, 'rest');
stimConds  = find(~isRest);
nStimConds = numel(stimConds);

% Counterbalanced orientation pool sized to stim blocks only
nOriDrawsTotal = nStimConds * nOriPerStim;
nRepeats       = ceil(nOriDrawsTotal / nOr);
oriPool        = repmat(orientationList(:).', 1, nRepeats);
oriPool        = oriPool(1:nOriDrawsTotal);
oriPool        = oriPool(randperm(numel(oriPool)));

% Expand condition_list into the full half-block schedule
expanded_list = {};
ori_seq       = [];
dir_seq       = [];

poolPtr = 1;
for k = 1:numel(condition_list)
    label = condition_list{k};
    if strcmpi(label, 'rest')
        % Rest passes through as one block, no orientation
        expanded_list{end+1} = label;
        ori_seq(end+1)       = NaN;
        dir_seq(end+1)       = NaN;
    else
        % Stim: one forward + one reverse half-block per orientation
        thisOri = oriPool(poolPtr : poolPtr + nOriPerStim - 1);
        poolPtr = poolPtr + nOriPerStim;
        for iO = 1:nOriPerStim
            expanded_list{end+1} = label;   % forward half-block
            ori_seq(end+1)       = thisOri(iO);
            dir_seq(end+1)       = +1;

            expanded_list{end+1} = label;   % reverse half-block
            ori_seq(end+1)       = thisOri(iO);
            dir_seq(end+1)       = -1;
        end
    end
end

nBlocks = numel(expanded_list);

%==========================================================================
% FIXED PARAMETERS
%==========================================================================
% Fixation task (fix_cfg in cfg_start)
fixTask = FixationTask(fix_cfg, width, height);
Image = uint8(128 * ones(height, width));  % grey background

%==========================================================================
% OPEN PSYCHTOOLBOX WINDOW
%==========================================================================
try
    oldVisualDebugLevel    = Screen('Preference','VisualDebugLevel', 3);
    oldSuppressAllWarnings = Screen('Preference','SuppressAllWarnings', 1);
    wptr = Screen('OpenWindow', screenid);
    HideCursor;
    Screen('BlendFunction', wptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    %----------------------------------------------------------------------
    % LOAD STIMULI
    % idx.(condLabel).(orientationDegrees) -> row index into gratingTexture
    %----------------------------------------------------------------------
    idx = struct;
    for c = 1:length(colourCondLabels)
        cName       = colourCondLabels{c};
        idx.(cName) = struct;
        for or = 1:nOr
            oriVal = orientationList(or);
            oName  = "d" + num2str(oriVal);
            index  = (c-1)*nOr + or;
            idx.(cName).(oName) = index;

            for s = 1:nSteps
                imName = [pathfile fs 'stimuli' fs cName ...
                    '_grating_' sprintf('%d', oriVal) '_degrees' fs ...
                    sprintf('%d', s) '.png'];
                image = double(imread(imName)) / 65535;
                gratingTexture(index, s) = Screen('MakeTexture', wptr, image, [], [], 1);
            end
        end
    end

    % Load background texture
    textureIndex(1) = Screen('MakeTexture', wptr, Image);

    %----------------------------------------------------------------------
    % PRE-TRIGGER SCREEN (idle fixation)
    %----------------------------------------------------------------------
    Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
    fixTask.draw(wptr);
    Screen('Flip', wptr);

    % Key queue: logs every trigger and response with its own GetSecs time
    % (see ScannerKeys.m). t0 = first trigger = time zero of the run.
    keys = ScannerKeys(TriggerSign, DetectKey, escapeKey);
    t0   = keys.waitForTrigger();

    fixTask.start();
    Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
    fixTask.draw(wptr);
    Screen('Flip', wptr);

    StartTime        = t0;   % all run times are GetSecs - StartTime (s since trigger 1)

    %----------------------------------------------------------------------
    % INITIALISE LOG / STATE VARIABLES
    %----------------------------------------------------------------------
    allCondLabels = unique(condition_list, 'stable');
    onsets        = cell(1, numel(allCondLabels));

    % Frame log, preallocated for up to 240 Hz (+10 s margin) and trimmed after the loop.
    % columns: [t block imgIndex phaseStep alpha direction flipOnset], flipOnset = Screen('Flip') StimulusOnsetTime - t0 (PTB GetSecs clock, s)
    isRestEntry = strcmpi(expanded_list, 'rest');
    runDur      = sum(isRestEntry)*DelayTime + sum(~isRestEntry)*BlockTime;
    LogData     = nan(ceil((runDur + 10) * 240), 7);
    nLog        = 0;

    img_count      = 0;
    cnt            = 1;   % current grating frame step (persists across half-blocks)
    escapePressed  = false;

    %----------------------------------------------------------------------
    % MAIN BLOCK LOOP — iterates over expanded_list
    % Stim entries appear as pairs: [forward half-block, reverse half-block]
    % cnt is NOT reset between the two, so the grating phase is continuous,
    % but each half-block fades out and back in, so the reversal passes
    % through the grey background (it is not seamless)
    %----------------------------------------------------------------------
    for b = 1:nBlocks

        blockLabel  = expanded_list{b};
        isRestBlock = strcmpi(blockLabel, 'rest');

        blockDur = BlockTime;
        if isRestBlock, blockDur = DelayTime; end

        blockStart = GetSecs - StartTime;

        % Log onset on rest blocks and on the forward half of each stim pair
        if isRestBlock || (~isnan(dir_seq(b)) && dir_seq(b) == +1)
            condIdx = find(strcmpi(allCondLabels, blockLabel), 1);
            if ~isempty(condIdx)
                onsets{condIdx} = [onsets{condIdx}, blockStart];
            end
        end

        % Resolve grating index for stim blocks
        if ~isRestBlock
            oriVal   = ori_seq(b);
            dirCode  = dir_seq(b);
            oName    = "d" + num2str(oriVal);
            imgIndex = idx.(blockLabel).(oName);
            % cnt intentionally NOT reset here — the reverse half-block
            % picks up the phase where the forward half-block left off
            % (after fading out and back in)
        else
            imgIndex = 0;
            dirCode  = 0;
        end

        % Per-block fading state
        alphaImg  = 0;
        fadingIn  = true;
        fadingOut = false;
        fadeStart = blockStart;

        %------------------------------------------------------------------
        % INNER FRAME LOOP
        %------------------------------------------------------------------
        while (GetSecs - StartTime) - blockStart < blockDur

            tNow     = GetSecs - StartTime;
            tInBlock = tNow - blockStart;

            fixTask.update(tNow);

            if isRestBlock
                Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
                fixTask.draw(wptr);
                alphaImg = 0;

            else
                % Fade in / sustain / fade out
                fadeOutStart = blockDur - FadingTime;
                if fadingIn
                    alphaImg = tInBlock / FadingTime;
                    if alphaImg >= 1
                        alphaImg = 1;
                        fadingIn = false;
                    end
                elseif tInBlock >= fadeOutStart
                    if ~fadingOut
                        fadingOut = true;
                        fadeStart = tNow;
                    end
                    alphaImg = 1 - (tNow - fadeStart) / FadingTime;
                    if alphaImg < 0, alphaImg = 0; end
                end

                % Advance grating frame in the current direction
                if dirCode > 0
                    cnt = cnt - 1; if cnt < 1,      cnt = nSteps; end
                else
                    cnt = cnt + 1; if cnt > nSteps, cnt = 1;      end
                end

                Screen('DrawTexture', wptr, textureIndex(1), [], [0 0 width height]);
                Screen('DrawTexture', wptr, gratingTexture(imgIndex, cnt), [], [0 0 width height], [], [], alphaImg);
                fixTask.draw(wptr);
            end

            [~, onsetT] = Screen('Flip', wptr);
            nLog = nLog + 1;
            LogData(nLog, :) = [tNow, b, imgIndex, cnt, alphaImg, dirCode*(~isRestBlock), onsetT - t0];

            % Key presses since the last frame (triggers are stored in keys)
            [respTimes, escapePressed] = keys.poll(t0);
            for r = respTimes
                fixTask.respond(r);
            end
            if escapePressed
                break;
            end

            % Optional screenshot saving
            if save_screen ~= 0
                imgDir = [runDir fs 'img'];
                if ~isdir(imgDir), mkdir(imgDir); end
                imageArray = Screen('GetImage', wptr, [0 0 width height]);
                imwrite(imageArray, [imgDir fs 'img_' num2str(img_count) '.png']);
                img_count = img_count + 1;
            end

        end  % end inner frame loop

        if escapePressed, break; end

    end  % end block loop
    LogData = LogData(1:nLog, :);
    keys.release();
    TriggerTime = keys.triggerTimes(t0);   % s since the first trigger (first = 0)
    keys.report(t0, runDur);

    %----------------------------------------------------------------------
    % END SCREEN
    %----------------------------------------------------------------------
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

    %----------------------------------------------------------------------
    % SAVE
    % durations reflect the full forward+reverse pair (2 * BlockTime)
    %----------------------------------------------------------------------
    names     = allCondLabels;
    durations = cell(1, numel(allCondLabels));
    for i = 1:numel(allCondLabels)
        if strcmpi(allCondLabels{i}, 'rest')
            durations{i} = DelayTime;
        else
            durations{i} = BlockTime * 2;  % forward + reverse = full block
        end
    end

    FixationData = fixTask.data;   % [code, t]  1=A->B 2=B->A 3=response
    save([FileName '_Cond.mat'], 'names', 'onsets', 'durations', '-mat');
    save([FileName '.mat'],      'FixationData', 'LogData', 'expanded_list', ...
                                  'ori_seq', 'dir_seq', 'TriggerTime', 'fix_cfg', '-mat');
    analysis_Stability(FileName);
    analysis_Fixation(FileName);

catch err
    if exist('keys','var'), try, keys.release(); catch, end, end
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end