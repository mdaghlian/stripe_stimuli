function checkAdditivityRB(name_subj, name_sess)
% checkAdditivityRB  Flicker-photometry check of whether red + blue add on
% the display (calibration plan, Section 5, step 1b). Run in the scanner.
%
%   checkAdditivityRB(name_subj, name_sess)
%
%   Flicker photometry is additive (Abney's law holds for it), so a
%   flicker match can test whether the DISPLAY adds red and blue. Any
%   observer can do it, including the experimenter.
%
%   Stage 1 - red vs blue: blue at full drive (luminance LB) alternates with
%     red at luminance k*LB (display model units); the observer adjusts red
%     until the flicker is minimal. k is that observer's red weight.
%   Stage 2 - mixture vs blue: for each blue fraction p, the mixture the
%     model predicts to be isoluminant with LB (blue p*LB + red (1-p)*k*LB)
%     is scaled by m and alternates with pure blue at LB; the observer
%     adjusts m until the flicker is minimal.
%     m = 1: red and blue add as the model assumes.
%     m > 1: the mixture is dimmer than the sum (it had to be raised).
%
%   Keys (one step per press; release before pressing again):
%     1 darker, 2 brighter, 3 done (after at least one adjustment), ESC abort.
%
%   Settings: rbcheck_cfg in cfg_start.m (band, blue fractions, repetitions,
%   flicker frequency, step size, surround). The display model is
%   displayModel(cal_cfg).
%
%   Output: <dir_base>/<subj>/colour/<sess>/stimuli/logfiles/RBadditivity_<time>.mat
%   with the trials, k, m(p) (mean and SD) and the settings. makeStimuli
%   can apply m(p) as a correction (cal_cfg.rbCorrection = true).

close all;
cfg_start;
fs = filesep;
if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess = 'TestSess'; end

dir_base = cfg.dir_base;
if exist(dir_base, 'dir') ~= 7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
logdir = [dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles'];
if exist(logdir, 'dir') ~= 7, mkdir(logdir); end

rc     = rbcheck_cfg;
model  = displayModel(cal_cfg);
LB     = model.dLmax.B;                       % blue at full drive (its plateau)
width  = cfg.width;
height = cfg.height;
fprintf('Display model: %s\nBlue reference LB = %.3g (model units)\n', model.description, LB);

% Geometry: the annulus of eccentricity band rc.band (findIso_cfg bands)
outerR = findIso_cfg.cond_px_bands(rc.band) * height;
innerR = 0;
if rc.band > 1, innerR = findIso_cfg.cond_px_bands(rc.band - 1) * height; end
cx = width / 2; cy = height / 2;
outerRect = [cx-outerR cy-outerR cx+outerR cy+outerR];
innerRect = [cx-innerR cy-innerR cx+innerR cy+innerR];
fixRect   = [cx-findIso_cfg.fixSize cy-findIso_cfg.fixSize cx+findIso_cfg.fixSize cy+findIso_cfg.fixSize];

switch rc.surround
    case 'matched', surroundDrive = model.d('W', LB);   % grey with the same model luminance as blue
    case 'black',   surroundDrive = 0;
    otherwise, error('checkAdditivityRB: rbcheck_cfg.surround must be ''matched'' or ''black''.');
end

% Trial list: stage 1 (red vs blue) then stage 2 (mixtures, shuffled)
p_list = rc.blueFractions(:)';
mixTrials = repmat(p_list, 1, rc.nRepsMix);
mixTrials = mixTrials(randperm(numel(mixTrials)));
trials = [ones(rc.nRepsMatch, 1), nan(rc.nRepsMatch, 1); 2 * ones(numel(mixTrials), 1), mixTrials(:)];
% columns of results: [stage, p, start value, final value]
results = nan(size(trials, 1), 4);

KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
darkKey   = KbName('1!');
lightKey  = KbName('2@');
doneKey   = KbName('3#');

try
    screenid = cfg.screenid;
    wptr = Screen('OpenWindow', screenid, 0);
    ifi = checkRefreshRate(wptr, cfg);
    useIdentityGamma(wptr);
    Priority(MaxPriority(wptr));
    HideCursor;
    ListenChar(2);
    framesPerHalf = max(1, round(1 / (2 * rc.flickerHz * ifi)));
    fprintf('Flicker: %.1f Hz (%d frame(s) per field)\n', 1 / (2 * framesPerHalf * ifi), framesPerHalf);

    % instructions
    Screen('FillRect', wptr, surroundDrive);
    DrawFormattedText(wptr, ['Look at the dot. Make the flicker disappear.\n\n' ...
        '1 = darker    2 = brighter    3 = done\n\nPress 1 to start'], 'center', 'center', 255);
    Screen('Flip', wptr);
    waitKey(darkKey, escapeKey);

    kMean = 1;
    for t = 1:size(trials, 1)
        stage = trials(t, 1);
        p     = trials(t, 2);
        start = 1 + rc.jitter * (2 * rand - 1);
        value = start;
        % field B as a function of the adjusted value
        if stage == 1
            maxValue = model.dLmax.R / LB;                       % red cannot go brighter
        else
            maxValue = min([1 / max(p, eps), model.dLmax.R / (LB * kMean * max(1 - p, eps))]);
        end
        blueA = model.d('B', LB);                                % field A: pure blue at LB
        adjusted = false;
        released = false;
        frame = 0;
        while true
            if stage == 1
                fieldB = [model.d('R', LB * value), 0, 0];
            else
                [rD, bD] = rbMixtureDrives(model, LB, kMean, p, value);
                fieldB = [rD, 0, bD];
            end
            showA = mod(floor(frame / framesPerHalf), 2) == 0;
            Screen('FillRect', wptr, surroundDrive);
            if showA, col = [0 0 blueA]; else, col = fieldB; end
            Screen('FillOval', wptr, col, outerRect);
            if innerR > 0, Screen('FillOval', wptr, surroundDrive, innerRect); end
            Screen('FillOval', wptr, [0 255 0], fixRect);
            Screen('Flip', wptr);
            frame = frame + 1;

            [down, ~, kc] = KbCheck;
            if ~down
                released = true;
            elseif released
                released = false;
                if kc(escapeKey)
                    error('checkAdditivityRB: aborted with Escape.');
                elseif kc(darkKey)
                    value = value / (1 + rc.step); adjusted = true;
                elseif kc(lightKey)
                    value = min(value * (1 + rc.step), maxValue); adjusted = true;
                elseif kc(doneKey) && adjusted
                    break
                end
            end
        end
        results(t, :) = [stage, p, start, value];
        if stage == 1
            fprintf('red vs blue, rep %d: k = %.3f\n', t, value);
            if t == rc.nRepsMatch
                kMean = mean(results(1:rc.nRepsMatch, 4));
                fprintf('k (mean of %d) = %.3f\n', rc.nRepsMatch, kMean);
            end
        else
            fprintf('mixture, blue fraction %.2f: m = %.3f\n', p, value);
        end
        % short blank between trials
        Screen('FillRect', wptr, surroundDrive);
        Screen('FillOval', wptr, [0 255 0], fixRect);
        Screen('Flip', wptr);
        WaitSecs(0.5);
    end

    % Summary
    k_reps = results(results(:, 1) == 1, 4);
    m_mean = nan(size(p_list)); m_sd = m_mean;
    for i = 1:numel(p_list)
        v = results(results(:, 1) == 2 & results(:, 2) == p_list(i), 4);
        m_mean(i) = mean(v); m_sd(i) = std(v);
    end
    fprintf('\n--- R + B additivity (%s) ---\n', model.description);
    fprintf('k = %.3f (SD %.3f, %d reps)\n', mean(k_reps), std(k_reps), numel(k_reps));
    for i = 1:numel(p_list)
        fprintf('blue fraction %.2f: m = %.3f (SD %.3f)\n', p_list(i), m_mean(i), m_sd(i));
    end
    if all(abs(m_mean - 1) <= rc.tolerance)
        fprintf('All m within +/-%.0f%% of 1: red + blue add as the model assumes.\n', 100 * rc.tolerance);
    else
        fprintf('Some m differ from 1 by more than %.0f%%: consider cal_cfg.rbCorrection = true in makeStimuli.\n', 100 * rc.tolerance);
    end

    RBadditivity = struct('trials', results, 'columns', {{'stage', 'blueFraction', 'start', 'final'}}, ...
        'k_reps', k_reps, 'k', mean(k_reps), 'blueFractions', p_list, 'm', m_mean, 'm_sd', m_sd, ...
        'rbcheck_cfg', rc, 'cal_cfg', cal_cfg, 'model', model.description, 'LB', LB, ...
        'timestamp', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    outFile = [logdir fs 'RBadditivity_' RBadditivity.timestamp '.mat'];
    save(outFile, 'RBadditivity');

    % end screen (surround), wait for Esc
    waitAtEnd(wptr, surroundDrive*[1 1 1], sprintf('R+B additivity check completed and saved:\n  %s', outFile));

    ListenChar(0);
    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
catch err
    ListenChar(0);
    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end

end


function waitKey(key, escapeKey)
% Wait for a key press (after all keys are released).
KbReleaseWait;
while true
    [down, ~, kc] = KbCheck;
    if down && kc(escapeKey), error('checkAdditivityRB: aborted with Escape.'); end
    if down && kc(key), break; end
end
KbReleaseWait;
end
