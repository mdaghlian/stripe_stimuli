function checkGrating(name_subj, name_sess)
% checkGrating  Flicker check of the colour grating as built by makeStimuli:
% are its red and blue stripes isoluminant for this observer? Run in the
% scanner after makeStimuli, with the participant who will see the stimuli.
%
%   checkGrating(name_subj, name_sess)
%
%   The colour grating's frame s (at each pixel blue g, red 1-g) alternates
%   with frame s + nPhaseSteps/2, the same grating half a cycle on, where
%   red and blue have swapped places. If red and blue are isoluminant for
%   the observer, the luminance does not change and the flicker vanishes
%   (at the isoluminance tasks' flicker rate the colour change itself is not
%   seen). If not, the stripes flicker. The observer scales the red
%   luminance of both frames by r (display model, in luminance) until the
%   flicker is minimal.
%     r = 1: the grating as built is isoluminant for this observer.
%     r > 1: red had to be raised, i.e. the red stripes are darker than the
%            blue stripes as built (r < 1: brighter).
%     Luminance contrast between the stripes as built: |r - 1| / (r + 1).
%   The grating is the one colourProject shows (PNG files and newest
%   stim_metadata of the session, same display model, drawn full screen on
%   the matched-grey background), shown in one findIso_cfg eccentricity band
%   at a time; orientation and phase are random per trial.
%
%   This tests the red and blue peaks against each other. The red + blue
%   mixtures in between are the same in both frames, so their additivity is
%   not tested here (checkAdditivityRB does that).
%
%   Keys (one step = grcheck_cfg.step of red luminance; holding 1/2 repeats):
%     1 darker, 2 brighter, 3 done (after at least one adjustment),
%     ESC stop (the trials done so far are saved).
%
%   Settings: grcheck_cfg in cfg_start.m.
%
%   Output: <dir_base>/<subj>/colour/<sess>/stimuli/logfiles/GratingCheck_<time>.mat

close all;
cfg_start;
fs = filesep;
if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess = 'TestSess'; end

dir_base = cfg.dir_base;
if exist(dir_base, 'dir') ~= 7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
stimdir = [dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli'];
logdir  = [stimdir fs 'logfiles'];

% The stimuli as made: newest stim_metadata of the session (as colourProject)
metaFiles = dir([logdir fs 'stim_metadata_*.mat']);
if isempty(metaFiles), error('checkGrating: no stim_metadata in %s. Run makeStimuli first.', logdir); end
[~, newest] = max([metaFiles.datenum]);
sp = load([logdir fs metaFiles(newest).name], 'stim_params'); sp = sp.stim_params;
if ~isfield(sp, 'background') || ~isfield(sp, 'displayModel')
    error('checkGrating: stimuli in %s were made before gamma correction. Regenerate them with makeStimuli.', stimdir);
end
model   = displayModel(sp.displayModel.spec);   % the model the stimuli were built with
bgDrive = round(sp.background.drive);
nPhase  = sp.stim_cfg.nPhaseSteps;
if mod(nPhase, 2), error('checkGrating: stim_cfg.nPhaseSteps must be even (half a cycle = nPhaseSteps/2 frames).'); end
thetaList = sp.stim_cfg.thetaList;
fprintf('Stimuli: %s\nDisplay model: %s\nBackground: W drive %d\n', metaFiles(newest).name, model.description, bgDrive);

gc = grcheck_cfg;
width  = cfg.width;
height = cfg.height;
cx = width / 2; cy = height / 2;
fixRect = [cx-findIso_cfg.fixSize cy-findIso_cfg.fixSize cx+findIso_cfg.fixSize cy+findIso_cfg.fixSize];

% Trial list: every band nReps times, shuffled
trials = repmat(gc.bands(:)', 1, gc.nReps);
trials = trials(randperm(numel(trials)));
% columns of results: [band, orientation, phase step, start r, final r, trial duration (s), number of steps]
results = nan(numel(trials), 7);

KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
darkKey   = KbName('1!');
lightKey  = KbName('2@');
doneKey   = KbName('3#');
keys = struct('dark', darkKey, 'light', lightKey, 'done', doneKey, 'escape', escapeKey);

try
    screenid = cfg.screenid;
    wptr = Screen('OpenWindow', screenid, bgDrive);
    ifi = checkRefreshRate(wptr, cfg);
    useIdentityGamma(wptr);
    Priority(MaxPriority(wptr));
    HideCursor;
    ListenChar(2);
    framesPerHalf = max(1, round(1 / (2 * gc.flickerHz * ifi)));
    fprintf('Flicker: %.1f Hz (%d frame(s) per field)\n', 1 / (2 * framesPerHalf * ifi), framesPerHalf);

    % instructions
    Screen('FillRect', wptr, bgDrive);
    DrawFormattedText(wptr, ['Look at the dot. Make the flicker disappear.\n\n' ...
        '1 = darker    2 = brighter    3 = done\n\nPress 1 to start'], 'center', 'center', 255);
    Screen('Flip', wptr);
    waitKey(darkKey, escapeKey, key_cfg.device);

    stopped = false;
    Rimg = [];
    for t = 1:numel(trials)
        b = trials(t);
        theta = thetaList(randi(numel(thetaList)));
        s = randi(nPhase / 2);
        folder = [stimdir fs 'colour_grating_' sprintf('%d', theta) '_degrees'];
        A = double(imread([folder fs sprintf('%d', s) '.png'])) / 65535 * 255;               % drive, 0-255
        B = double(imread([folder fs sprintf('%d', s + nPhase / 2) '.png'])) / 65535 * 255;  % half a cycle on

        % band mask, eccentricity in full-screen px as in makeStimuli
        if isempty(Rimg)
            [h, w, ~] = size(A);
            [Xm, Ym] = meshgrid(1:w, 1:h);
            Rimg = sqrt((Xm - w/2).^2 + (Ym - h/2).^2) / cfg.image_frac;
        end
        outerR = findIso_cfg.cond_px_bands(b) * height;
        innerR = 0;
        if b > 1, innerR = findIso_cfg.cond_px_bands(b - 1) * height; end
        mask = Rimg <= outerR & Rimg >= innerR;

        % red luminance of both frames in the band; r cannot take red past its maximum
        LRa = model.dL('R', A(:, :, 1)); LRa = LRa(mask);
        LRb = model.dL('R', B(:, :, 1)); LRb = LRb(mask);
        rMax = model.dLmax.R / max([LRa; LRb]);

        start = min(1 + gc.jitter * (2 * rand - 1), rMax);
        value = start;
        tex = makeFrames(A, B, LRa, LRb, mask, value, bgDrive, model, wptr, []);
        adjusted = false;
        ks = struct('key', 0, 't0', 0, 'tLast', 0, 'needRelease', true);
        frame = 0;
        nSteps = 0;
        tStart = GetSecs;
        while true
            showA = mod(floor(frame / framesPerHalf), 2) == 0;
            Screen('DrawTexture', wptr, tex(2 - showA), [], [0 0 width height]);
            Screen('FillOval', wptr, [0 255 0], fixRect);
            Screen('Flip', wptr);
            frame = frame + 1;

            % one step per press; holding 1/2 repeats (key_cfg, flickerKeys.m)
            [action, ks] = flickerKeys(ks, keys, key_cfg);
            switch action
                case 'escape'
                    stopped = true;
                    break
                case 'dark'
                    value = value / (1 + gc.step); adjusted = true; nSteps = nSteps + 1;
                    tex = makeFrames(A, B, LRa, LRb, mask, value, bgDrive, model, wptr, tex);
                case 'light'
                    value = min(value * (1 + gc.step), rMax); adjusted = true; nSteps = nSteps + 1;
                    tex = makeFrames(A, B, LRa, LRb, mask, value, bgDrive, model, wptr, tex);
                case 'done'
                    if adjusted, break; end
            end
        end
        Screen('Close', tex);
        if stopped, break; end
        results(t, :) = [b, theta, s, start, value, GetSecs - tStart, nSteps];
        fprintf('band %d, %d deg: r = %.3f\n', b, theta, value);
        % short blank between trials
        Screen('FillRect', wptr, bgDrive);
        Screen('FillOval', wptr, [0 255 0], fixRect);
        Screen('Flip', wptr);
        WaitSecs(0.5);
    end

    % Summary per band (completed trials only)
    bands = gc.bands(:)';
    r_mean = nan(size(bands)); r_sd = r_mean; nDone = zeros(size(bands));
    for i = 1:numel(bands)
        v = results(results(:, 1) == bands(i), 5);
        nDone(i) = numel(v);
        r_mean(i) = mean(v); r_sd(i) = std(v);
    end
    contrast = abs(r_mean - 1) ./ (r_mean + 1);
    fprintf('\n--- Colour grating check (%s) ---\n', metaFiles(newest).name);
    for i = 1:numel(bands)
        fprintf('band %d: r = %.3f (SD %.3f, %d reps)  stripe contrast as built %.1f%%\n', ...
            bands(i), r_mean(i), r_sd(i), nDone(i), 100 * contrast(i));
    end
    if stopped
        fprintf('Stopped early (Esc): not every band was tested; no verdict.\n');
    elseif all(abs(r_mean - 1) <= gc.tolerance)
        fprintf('All r within +/-%.0f%% of 1: the grating is isoluminant for this observer.\n', 100 * gc.tolerance);
    else
        fprintf('Some r differ from 1 by more than %.0f%%: the red and blue stripes do not match for this observer (r > 1: red too dark).\n', 100 * gc.tolerance);
    end

    GratingCheck = struct('trials', results, ...
        'columns', {{'band', 'orientation', 'phaseStep', 'start', 'final', 'duration_s', 'nSteps'}}, ...
        'complete', ~stopped, 'bands', bands, 'r', r_mean, 'r_sd', r_sd, 'nDone', nDone, ...
        'stripeContrast', contrast, 'stim_metadata', metaFiles(newest).name, ...
        'grcheck_cfg', gc, 'key_cfg', key_cfg, 'model', model.description, 'bgDrive', bgDrive, ...
        'display', struct('refreshHz', 1 / ifi, 'framesPerHalf', framesPerHalf, ...
            'flickerHz', 1 / (2 * framesPerHalf * ifi), 'screenid', screenid), ...
        'timestamp', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    outFile = [logdir fs 'GratingCheck_' GratingCheck.timestamp '.mat'];
    save(outFile, 'GratingCheck');
    if stopped, endState = 'stopped early (Esc); trials so far'; else, endState = 'completed and'; end

    % end screen (background), wait for Esc
    waitAtEnd(wptr, bgDrive * [1 1 1], sprintf('Grating check %s saved:\n  %s', endState, outFile));

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


function tex = makeFrames(A, B, LRa, LRb, mask, r, bgDrive, model, wptr, oldTex)
% The two flicker frames as textures: the grating frames A and B inside the
% band, with their red luminance scaled by r, and the background outside.
% Float textures drawn full screen, as in colourProject.
if ~isempty(oldTex), Screen('Close', oldTex); end
frames = {A, B};
LR = {LRa, LRb};
tex = zeros(1, 2);
for f = 1:2
    img = bgDrive * ones(size(A));
    for p = 1:3
        plane = img(:, :, p);
        src = frames{f}(:, :, p);
        if p == 1
            plane(mask) = model.d('R', r * LR{f});
        else
            plane(mask) = src(mask);
        end
        img(:, :, p) = plane;
    end
    tex(f) = Screen('MakeTexture', wptr, img / 255, [], [], 1);
end
end


function waitKey(key, escapeKey, device)
% Wait for a key press on any keyboard in device (after all keys are released).
KbReleaseWait(device);
while true
    [down, ~, kc] = KbCheck(device);
    if down && kc(escapeKey), error('checkGrating: aborted with Escape.'); end
    if down && kc(key), break; end
end
KbReleaseWait(device);
end
