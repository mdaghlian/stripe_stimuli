function checkGamma(name_subj, name_sess)
% checkGamma  Psychophysical check of the display model's drive -> luminance
% curve (gamma), by matching a fine dither to a uniform field. Run in the
% scanner, with the display set up as for the experiment.
%
%   checkGamma(name_subj, name_sess)
%
%   A field of 1-pixel lines (or a checkerboard) alternating between drives
%   dLo and dHi of one channel has mean luminance (L(dLo) + L(dHi)) / 2,
%   whatever the display's gamma. At 113 cm the lines are ~50 cycles/deg,
%   too fine to see, so only that mean is visible. The observer adjusts the
%   drive of a uniform field of the same channel until it matches the
%   dither. The display model predicts the matching drive,
%   model.d(c, (L(dLo) + L(dHi)) / 2); the observer's setting tests it.
%   Both fields have the same chromaticity, so any observer can do it.
%
%   gcheck_cfg.mode (cfg_start.m):
%     'flicker'  dither and uniform field alternate (gcheck_cfg.flickerHz);
%                adjust until the flicker is minimal.
%     'static'   half of the annulus is dither, half uniform (side random);
%                adjust until the halves look equally bright. Use it to rule
%                out temporal artefacts of the flicker method (pixel rise and
%                fall times differ on LCD projectors).
%
%   Keys (one step = one drive level; holding 1/2 repeats):
%     1 darker, 2 brighter, 3 done (after at least one adjustment), ESC abort.
%
%   Results per condition (channel, [lo hi] as fractions of the channel's
%   maximum luminance):
%     m        = model luminance at the matched drive / predicted mean.
%                m = 1: the model is right at that level. m > 1: the observer
%                needed more drive than the model predicts, i.e. the display
%                is dimmer there than the model says.
%     gammaObs / gammaModel: the power-law gamma (L ~ (d/clip)^gamma) implied
%                by the observer's match and by the model's predicted match.
%   One drive level is the resolution of the match, so at low drives m can
%   only be judged to a few percent.
%
%   Settings: gcheck_cfg in cfg_start.m. The display model is
%   displayModel(cal_cfg).
%
%   Output: <dir_base>/<subj>/colour/<sess>/stimuli/logfiles/GammaCheck_<time>.mat
%
%   The dither must land on screen pixels 1:1. On a Retina Mac set
%   gcheck_cfg.useRetina = true (window at native resolution); if the
%   display still scales, gcheck_cfg.ditherPx = 2 makes 2-px lines/checks
%   (still invisible at the 7T viewing distance, ~25 cycles/deg).

close all;
cfg_start;
fs = filesep;
if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess = 'TestSess'; end

dir_base = cfg.dir_base;
if exist(dir_base, 'dir') ~= 7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
logdir = [dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles'];
if exist(logdir, 'dir') ~= 7, mkdir(logdir); end

gc    = gcheck_cfg;
model = displayModel(cal_cfg);
fprintf('Display model: %s\n', model.description);
if ~any(strcmp(gc.mode, {'flicker', 'static'})), error('checkGamma: gcheck_cfg.mode must be ''flicker'' or ''static''.'); end
if ~any(strcmp(gc.pattern, {'rows', 'checker'})), error('checkGamma: gcheck_cfg.pattern must be ''rows'' or ''checker''.'); end
if ~any(strcmp(gc.surround, {'black', 'mean'})), error('checkGamma: gcheck_cfg.surround must be ''black'' or ''mean''.'); end

% Conditions: every channel x every [lo hi] pair, with the drives rounded
% to what the display can show and the prediction made from those drives.
nPairs = size(gc.pairs, 1);
cond = struct('chan', {}, 'lo', {}, 'hi', {}, 'dLo', {}, 'dHi', {}, 'Lpred', {}, 'dPred', {});
for ic = 1:numel(gc.channels)
    c = gc.channels{ic};
    for ip = 1:nPairs
        dLo = round(model.d(c, gc.pairs(ip, 1) * model.dLmax.(c)));
        dHi = round(model.d(c, gc.pairs(ip, 2) * model.dLmax.(c)));
        Lpred = (model.dL(c, dLo) + model.dL(c, dHi)) / 2;
        cond(end+1) = struct('chan', c, 'lo', gc.pairs(ip, 1), 'hi', gc.pairs(ip, 2), ...
            'dLo', dLo, 'dHi', dHi, 'Lpred', Lpred, 'dPred', model.d(c, Lpred)); %#ok<AGROW>
    end
end
trials = repmat(1:numel(cond), 1, gc.nReps);
trials = trials(randperm(numel(trials)));
% columns of results: [condition, side (static: 1 dither left, 2 right), start drive, final drive,
%                      trial duration (s), number of steps]
results = nan(numel(trials), 6);

KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
darkKey   = KbName('1!');
lightKey  = KbName('2@');
doneKey   = KbName('3#');
keys = struct('dark', darkKey, 'light', lightKey, 'done', doneKey, 'escape', escapeKey);

try
    screenid = cfg.screenid;
    if isfield(gc, 'useRetina') && gc.useRetina
        % Retina Mac: native resolution, so the dither is not rescaled by macOS
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask', 'General', 'UseRetinaResolution');
        wptr = PsychImaging('OpenWindow', screenid, 0);
    else
        wptr = Screen('OpenWindow', screenid, 0);
    end
    ifi = checkRefreshRate(wptr, cfg);
    useIdentityGamma(wptr);
    Priority(MaxPriority(wptr));
    HideCursor;
    ListenChar(2);
    Screen('BlendFunction', wptr, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    framesPerHalf = max(1, round(1 / (2 * gc.flickerHz * ifi)));
    if strcmp(gc.mode, 'flicker')
        fprintf('Flicker: %.1f Hz (%d frame(s) per field)\n', 1 / (2 * framesPerHalf * ifi), framesPerHalf);
    end

    % Geometry: the annulus of eccentricity band gc.band (findIso_cfg
    % bands), on whole pixels so the dither maps 1:1 onto the screen.
    [width, height] = Screen('WindowSize', wptr);
    outerR = round(findIso_cfg.cond_px_bands(gc.band) * height);
    innerR = 0;
    if gc.band > 1, innerR = round(findIso_cfg.cond_px_bands(gc.band - 1) * height); end
    cx = round(width / 2); cy = round(height / 2);
    outerRect = [cx-outerR cy-outerR cx+outerR cy+outerR];
    innerRect = [cx-innerR cy-innerR cx+innerR cy+innerR];
    fixRect   = [cx-findIso_cfg.fixSize cy-findIso_cfg.fixSize cx+findIso_cfg.fixSize cy+findIso_cfg.fixSize];

    % instructions
    if strcmp(gc.mode, 'flicker')
        msg = 'Look at the dot. Make the flicker disappear.';
    else
        msg = 'Look at the dot. Make the left and right halves equally bright.';
    end
    Screen('FillRect', wptr, 0);
    DrawFormattedText(wptr, [msg '\n\n1 = darker    2 = brighter    3 = done\n\nPress 1 to start'], 'center', 'center', 255);
    Screen('Flip', wptr);
    waitKey(darkKey, escapeKey, key_cfg.device);

    for t = 1:numel(trials)
        k = cond(trials(t));
        side = randi(2);
        tex = Screen('MakeTexture', wptr, ditherPatch(k, outerRect, innerR, gc, side));
        switch gc.surround
            case 'black', surround = [0 0 0];
            case 'mean',  surround = chanColour(k.chan, round(k.dPred));
        end
        start = min(max(round(k.dPred + gc.jitter * (2 * rand - 1)), 0), 255);
        value = start;
        adjusted = false;
        ks = struct('key', 0, 't0', 0, 'tLast', 0, 'needRelease', true);
        frame = 0;
        nSteps = 0;
        tStart = GetSecs;
        while true
            showDither = strcmp(gc.mode, 'static') || mod(floor(frame / framesPerHalf), 2) == 0;
            Screen('FillRect', wptr, surround);
            Screen('FillOval', wptr, chanColour(k.chan, value), outerRect);
            if innerR > 0, Screen('FillOval', wptr, surround, innerRect); end
            if showDither, Screen('DrawTexture', wptr, tex, [], outerRect, [], 0); end
            Screen('FillOval', wptr, [0 255 0], fixRect);
            Screen('Flip', wptr);
            frame = frame + 1;

            [action, ks] = flickerKeys(ks, keys, key_cfg);
            switch action
                case 'escape'
                    error('checkGamma: aborted with Escape.');
                case 'dark'
                    value = max(value - 1, 0); adjusted = true; nSteps = nSteps + 1;
                case 'light'
                    value = min(value + 1, 255); adjusted = true; nSteps = nSteps + 1;
                case 'done'
                    if adjusted, break; end
            end
        end
        Screen('Close', tex);
        results(t, :) = [trials(t), side, start, value, GetSecs - tStart, nSteps];
        fprintf('%s [%.2f %.2f] (drives %d/%d): predicted %.1f, matched %d\n', ...
            k.chan, k.lo, k.hi, k.dLo, k.dHi, k.dPred, value);
        % short blank between trials
        Screen('FillRect', wptr, surround);
        Screen('FillOval', wptr, [0 255 0], fixRect);
        Screen('Flip', wptr);
        WaitSecs(0.5);
    end

    % Summary per condition
    nC = numel(cond);
    dMatch = nan(1, nC); dMatch_sd = dMatch; m = dMatch; gammaObs = dMatch; gammaModel = dMatch;
    fprintf('\n--- Gamma check (%s; %s, %s) ---\n', model.description, gc.mode, gc.pattern);
    fprintf('chan  [lo   hi]   dLo/dHi   predicted  matched (SD)   m      gamma obs/model\n');
    for i = 1:nC
        k = cond(i);
        v = results(results(:, 1) == i, 4);
        dMatch(i) = mean(v); dMatch_sd(i) = std(v);
        m(i) = model.dL(k.chan, dMatch(i)) / k.Lpred;
        gammaObs(i)   = impliedGamma(k.dLo, k.dHi, dMatch(i), model.clip.(k.chan));
        gammaModel(i) = impliedGamma(k.dLo, k.dHi, k.dPred, model.clip.(k.chan));
        fprintf('%-4s  [%.2f %.2f]  %3d/%3d   %6.1f    %6.1f (%.1f)   %.3f  %.2f / %.2f\n', ...
            k.chan, k.lo, k.hi, k.dLo, k.dHi, k.dPred, dMatch(i), dMatch_sd(i), m(i), gammaObs(i), gammaModel(i));
    end
    if all(abs(m - 1) <= gc.tolerance)
        fprintf('All m within +/-%.0f%% of 1: the display model matches what the observer sees.\n', 100 * gc.tolerance);
    else
        fprintf('Some m differ from 1 by more than %.0f%%: the display model may be off at those levels.\n', 100 * gc.tolerance);
    end

    % per-repetition m, and the luminance step of one drive level at each predicted match
    mRep = nan(size(results, 1), 1);
    for r = 1:size(results, 1)
        k = cond(results(r, 1));
        mRep(r) = model.dL(k.chan, results(r, 4)) / k.Lpred;
    end
    levelStep = nan(1, nC);
    for i = 1:nC
        k = cond(i);
        levelStep(i) = (model.dL(k.chan, k.dPred + 0.5) - model.dL(k.chan, k.dPred - 0.5)) / k.Lpred;
    end
    modelInfo = rmfield(model, intersect(fieldnames(model), {'dL', 'd', 'L'}));   % tables, clip points, maxima

    GammaCheck = struct('trials', results, ...
        'columns', {{'condition', 'side', 'start', 'final', 'duration_s', 'nSteps'}}, ...
        'mRep', mRep, 'cond', cond, 'dMatch', dMatch, 'dMatch_sd', dMatch_sd, 'm', m, ...
        'levelStep', levelStep, 'gammaObs', gammaObs, 'gammaModel', gammaModel, ...
        'gcheck_cfg', gc, 'cal_cfg', cal_cfg, 'key_cfg', key_cfg, ...
        'model', model.description, 'modelInfo', modelInfo, ...
        'display', struct('refreshHz', 1 / ifi, 'framesPerHalf', framesPerHalf, ...
            'flickerHz', 1 / (2 * framesPerHalf * ifi), 'windowSize', [width height], ...
            'outerR_px', outerR, 'innerR_px', innerR, 'screenid', screenid), ...
        'timestamp', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    outFile = [logdir fs 'GammaCheck_' GammaCheck.timestamp '.mat'];
    save(outFile, 'GammaCheck');

    % end screen (black), wait for Esc
    waitAtEnd(wptr, [0 0 0], sprintf('Gamma check completed and saved:\n  %s', outFile));

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

plotGammaCheck(GammaCheck, model, strrep(outFile, '.mat', '.png'));
end


function img = ditherPatch(k, rect, innerR, gc, side)
% RGBA texture covering rect: the dither inside the annulus (one half of it
% in static mode, side 1 = left, 2 = right), transparent elsewhere. Pixel
% parity is taken from screen coordinates.
w = rect(3) - rect(1); h = rect(4) - rect(2);
[xs, ys] = meshgrid(rect(1) + (0:w-1), rect(2) + (0:h-1));
x = xs + 0.5 - (rect(1) + rect(3)) / 2;
y = ys + 0.5 - (rect(2) + rect(4)) / 2;
r = hypot(x, y);
mask = r <= w / 2 & r >= innerR;
if strcmp(gc.mode, 'static')
    if side == 1, mask = mask & x < 0; else, mask = mask & x >= 0; end
end
px = 1; if isfield(gc, 'ditherPx'), px = gc.ditherPx; end   % dither element size, pixels
if strcmp(gc.pattern, 'rows'), hiPix = mod(floor(ys / px), 2) == 1; else, hiPix = mod(floor(xs / px) + floor(ys / px), 2) == 1; end
d = k.dLo * ones(h, w);
d(hiPix) = k.dHi;
col = chanColour(k.chan, 1);
img = zeros(h, w, 4, 'uint8');
for p = 1:3, img(:, :, p) = uint8(col(p) * d); end
img(:, :, 4) = uint8(255 * mask);
end


function col = chanColour(c, d)
% Colour of drive d in channel c ('W' = all three guns).
switch c
    case 'W', col = [d d d];
    case 'R', col = [d 0 0];
    case 'G', col = [0 d 0];
    case 'B', col = [0 0 d];
    otherwise, error('checkGamma: unknown channel ''%s'' (R, G, B or W).', c);
end
end


function g = impliedGamma(dLo, dHi, dm, clip)
% Power-law gamma for which drive dm matches the mean of dLo and dHi:
% ((dLo/clip)^g + (dHi/clip)^g) / 2 = (dm/clip)^g. NaN if there is none.
f = @(g) ((dLo / clip)^g + (dHi / clip)^g) / 2 - (dm / clip)^g;
g = NaN;
if ~(dm > dLo && dm < dHi), return; end
if sign(f(0.2)) ~= sign(f(8)), g = fzero(f, [0.2 8]); end
end


function plotGammaCheck(G, model, pngFile)
% m (model luminance at the match / predicted dither mean) per condition:
% each repetition (dots), mean +/- SD, the +/- tolerance band, and the
% luminance step of one drive level at that match (grey bar). Saved as PNG.
chans = unique({G.cond.chan}, 'stable');
tol = G.gcheck_cfg.tolerance;
yr = max(2.6 * tol, max(abs(G.mRep - 1)) + 0.01);   % y range: tolerance band and every repetition
fig = figure('Name', 'Gamma check', 'Color', 'w', 'Position', [100 100 360 * numel(chans) 380]);
for ic = 1:numel(chans)
    c = chans{ic};
    idx = find(strcmp({G.cond.chan}, c));
    [~, order] = sort([G.cond(idx).Lpred]); idx = idx(order);   % left to right, so labels alternate in height
    subplot(1, numel(chans), ic); hold on;
    fill([0 1 1 0], 1 + tol * [-1 -1 1 1], [0.9 0.95 0.9], 'EdgeColor', 'none');
    plot([0 1], [1 1], 'k:');
    for j = 1:numel(idx)
        i = idx(j);
        x = G.cond(i).Lpred / model.dLmax.(c);
        plot([x x], 1 + G.levelStep(i) * [-0.5 0.5], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 6);
        reps = G.mRep(G.trials(:, 1) == i);
        plot(x + 0.012 * (1:numel(reps)) - 0.006 * (numel(reps) + 1), reps, '.', 'Color', [0.3 0.3 0.8], 'MarkerSize', 12);
        errorbar(x, G.m(i), std(reps), 'ko', 'MarkerFaceColor', 'k', 'LineWidth', 1.2);
        text(x, 1 - yr * (0.82 + 0.1 * mod(j, 2)), sprintf('[%.2g %.2g]', G.cond(i).lo, G.cond(i).hi), ...
            'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    xlim([0 1]); ylim(1 + yr * [-1 1]); box on;
    xlabel('predicted luminance (fraction of max)'); ylabel('m = matched / predicted');
    title(sprintf('%s   (green: \\pm%.0f%%, grey: 1 drive level)', c, 100 * tol));
end
try
    exportgraphics(fig, pngFile, 'Resolution', 120);
catch
    saveas(fig, pngFile);   % older MATLAB
end
fprintf('Figure saved: %s\n', pngFile);
end


function waitKey(key, escapeKey, device)
% Wait for a key press on any keyboard in device (after all keys are released).
KbReleaseWait(device);
while true
    [down, ~, kc] = KbCheck(device);
    if down && kc(escapeKey), error('checkGamma: aborted with Escape.'); end
    if down && kc(key), break; end
end
KbReleaseWait(device);
end
