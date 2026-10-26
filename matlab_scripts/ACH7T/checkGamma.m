function checkGamma(name_subj, name_sess)
% checkGamma  Visual check of the display model's drive -> luminance curve
% (gamma), as in FrACT's gamma check (M. Bach, GammaView): a fine
% checkerboard of two drives inside a uniform field set to the drive the
% model predicts for the checkerboard's mean. Run with the display set up
% as for the experiment.
%
%   checkGamma(name_subj, name_sess)
%
%   A checkerboard of drives dLo and dHi (gcheck_cfg.ditherPx-pixel checks,
%   too fine to resolve at the viewing distance) has mean luminance
%   (L(dLo) + L(dHi)) / 2, whatever the gamma. The model predicts the drive
%   of a uniform field with that luminance, model.d(c, mean). If the model
%   is right, the checkerboard disappears into a surround at that drive:
%     square brighter than its surround: the display is dimmer at the
%       surround's drive than the model predicts;
%     square darker: the display is brighter there than predicted.
%
%   One screen per channel (gcheck_cfg.channels), one square per [lo hi]
%   pair (gcheck_cfg.pairs, fractions of the channel's maximum luminance).
%
%   gcheck_cfg.adjust = false: look only. Each surround is at the predicted
%     drive (rounded; the rounding is printed and is ~1% at most).
%     Keys: 1 previous screen, 2 next screen, Esc end. Nothing is saved.
%   gcheck_cfg.adjust = true: match each square in turn (outlined). Its
%     surround starts at the predicted drive +/- up to gcheck_cfg.jitter
%     levels; the observer sets it until the square disappears.
%     Keys: 1 darker, 2 brighter (hold to repeat), 3 accept and go to the
%     next square, Esc stop (the squares done so far are saved).
%     Result per square: m = model luminance at the matched drive /
%     predicted mean. m = 1: the model is right at that level; m > 1: the
%     display is dimmer there than the model says. One drive level is the
%     resolution of the match ('1 level', a few % at the lowest pair).
%     Output: <dir_base>/<subj>/colour/<sess>/stimuli/logfiles/GammaCheck_<time>.mat

close all;
cfg_start;
fs = filesep;
if ~exist('name_subj', 'var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess = 'TestSess'; end

gc    = gcheck_cfg;
model = displayModel(cal_cfg);
px    = gc.ditherPx;
fprintf('Gamma check (%s %s)\nDisplay model: %s\n', name_subj, name_sess, model.description);
if gc.adjust
    dir_base = cfg.dir_base;
    if exist(dir_base, 'dir') ~= 7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
    logdir = [dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles'];
    if exist(logdir, 'dir') ~= 7, mkdir(logdir); end
end

KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
darkKey   = KbName('1!');
lightKey  = KbName('2@');
doneKey   = KbName('3#');
keys = struct('dark', darkKey, 'light', lightKey, 'done', doneKey, 'escape', escapeKey);

try
    screenid = cfg.screenid;
    wptr = Screen('OpenWindow', screenid, 0);
    useIdentityGamma(wptr);
    HideCursor;
    ListenChar(2);
    [width, height] = Screen('WindowSize', wptr);

    % Layout: the pairs side by side, each a uniform tile with the
    % checkerboard in its middle half; whole pixels so the checks map 1:1
    nT   = size(gc.pairs, 1);
    tile = floor(min(width / (nT + 1), height / 2));
    gap  = floor((width - nT * tile) / (nT + 1));
    y0   = round((height - tile) / 2);
    inset = round(tile / 4);

    % Squares: one row per channel x pair
    nC = numel(gc.channels);
    sq = struct('chan', {}, 'lo', {}, 'hi', {}, 'dLo', {}, 'dHi', {}, 'Lpred', {}, 'dPred', {}, ...
        'levelStep', {}, 'page', {}, 'outer', {}, 'inner', {}, 'tex', {}, 'label', {});
    for ic = 1:nC
        c = gc.channels{ic};
        for ip = 1:nT
            dLo   = round(model.d(c, gc.pairs(ip, 1) * model.dLmax.(c)));
            dHi   = round(model.d(c, gc.pairs(ip, 2) * model.dLmax.(c)));
            Lpred = (model.dL(c, dLo) + model.dL(c, dHi)) / 2;
            dPred = model.d(c, Lpred);
            x0 = gap + (ip - 1) * (tile + gap);
            outer = [x0, y0, x0 + tile, y0 + tile];
            inner = outer + [inset, inset, -inset, -inset];
            % checkerboard, parity from screen coordinates
            [xs, ys] = meshgrid(inner(1):inner(3)-1, inner(2):inner(4)-1);
            d = dLo * ones(size(xs));
            d(mod(floor(xs / px) + floor(ys / px), 2) == 1) = dHi;
            col = chanColour(c, 1);
            img = zeros([size(d), 3], 'uint8');
            for p = 1:3, img(:, :, p) = uint8(col(p) * d); end
            sq(end+1) = struct('chan', c, 'lo', gc.pairs(ip, 1), 'hi', gc.pairs(ip, 2), ...
                'dLo', dLo, 'dHi', dHi, 'Lpred', Lpred, 'dPred', dPred, ...
                'levelStep', (model.dL(c, dPred + 0.5) - model.dL(c, dPred - 0.5)) / Lpred, ...
                'page', ic, 'outer', outer, 'inner', inner, ...
                'tex', Screen('MakeTexture', wptr, img), ...
                'label', sprintf('[%.2g %.2g]', gc.pairs(ip, 1), gc.pairs(ip, 2))); %#ok<AGROW>
        end
    end
    nS = numel(sq);
    surround = round([sq.dPred]);   % surround drive of every square

    if ~gc.adjust
        % LOOK ONLY: surrounds at the predicted drive; page through the channels
        fprintf('\nchan  [lo   hi]   dLo/dHi   predicted  surround  rounding  1 level\n');
        for i = 1:nS
            fprintf('%-4s  [%.2f %.2f]  %3d/%3d   %6.1f    %4d     %+5.1f%%   %4.1f%%\n', sq(i).chan, ...
                sq(i).lo, sq(i).hi, sq(i).dLo, sq(i).dHi, sq(i).dPred, surround(i), ...
                100 * (model.dL(sq(i).chan, surround(i)) / sq(i).Lpred - 1), 100 * sq(i).levelStep);
        end
        fprintf(['\nLook at each screen: a square that stands out from its surround means the model\n' ...
            'is off at that level. 1 = previous, 2 = next, Esc = end.\n']);
        page = 1;
        while true
            drawPage(wptr, sq, surround, page, 0, nC, y0);
            KbReleaseWait(key_cfg.device);
            while true
                [down, ~, kc] = KbCheck(key_cfg.device);
                if down && (kc(escapeKey) || kc(darkKey) || kc(lightKey)), break; end
            end
            if kc(escapeKey), break; end
            if kc(lightKey), page = mod(page, nC) + 1; else, page = mod(page - 2, nC) + 1; end
        end
    else
        % ADJUST: match each square in turn, in a random order within each screen
        DrawFormattedText(wptr, ['Make each outlined square disappear into its surround.\n\n' ...
            '1 = darker    2 = brighter    3 = done\n\nPress 1 to start'], 'center', 'center', 255);
        Screen('Flip', wptr);
        waitKey(darkKey, escapeKey, key_cfg.device);

        order = [];
        for ic = 1:nC
            onPage = find([sq.page] == ic);
            order = [order, onPage(randperm(numel(onPage)))]; %#ok<AGROW>
        end
        % columns of results: [start drive, matched drive, trial duration (s), number of steps]
        results = nan(nS, 4);
        stopped = false;
        for k = 1:nS
            i = order(k);
            start = min(max(round(sq(i).dPred + gc.jitter * (2 * rand - 1)), 0), 255);
            surround(i) = start;
            ks = struct('key', 0, 't0', 0, 'tLast', 0, 'needRelease', true);
            nSteps = 0;
            tStart = GetSecs;
            while true
                drawPage(wptr, sq, surround, sq(i).page, i, nC, y0);
                [action, ks] = flickerKeys(ks, keys, key_cfg);
                switch action
                    case 'escape'
                        stopped = true;
                        break
                    case 'dark'
                        surround(i) = max(surround(i) - 1, 0); nSteps = nSteps + 1;
                    case 'light'
                        surround(i) = min(surround(i) + 1, 255); nSteps = nSteps + 1;
                    case 'done'
                        break
                end
            end
            if stopped, break; end
            results(i, :) = [start, surround(i), GetSecs - tStart, nSteps];
        end

        % Summary per square (in channel x pair order)
        m = nan(1, nS);
        for i = 1:nS
            if ~isnan(results(i, 2)), m(i) = model.dL(sq(i).chan, results(i, 2)) / sq(i).Lpred; end
        end
        fprintf('\n--- Gamma check (%s) ---\n', model.description);
        fprintf('chan  [lo   hi]   dLo/dHi   predicted  matched   m      1 level\n');
        for i = 1:nS
            fprintf('%-4s  [%.2f %.2f]  %3d/%3d   %6.1f    %4g     %.3f  %4.1f%%\n', sq(i).chan, ...
                sq(i).lo, sq(i).hi, sq(i).dLo, sq(i).dHi, sq(i).dPred, results(i, 2), m(i), 100 * sq(i).levelStep);
        end
        if stopped
            fprintf('Stopped early (Esc): not every square was matched.\n');
        end
        off = abs(m - 1) > gc.tolerance;
        if any(off)
            fprintf('m differs from 1 by more than %.0f%% at: %s. The display model may be off there.\n', ...
                100 * gc.tolerance, strjoin(arrayfun(@(i) sprintf('%s %s', sq(i).chan, sq(i).label), find(off), 'UniformOutput', false), ', '));
        elseif ~stopped
            fprintf('All m within +/-%.0f%% of 1: the display model matches what the observer sees.\n', 100 * gc.tolerance);
        end

        GammaCheck = struct('squares', rmfield(sq, {'tex', 'outer', 'inner', 'page'}), ...
            'results', results, 'columns', {{'start', 'matched', 'duration_s', 'nSteps'}}, ...
            'm', m, 'order', order, 'complete', ~stopped, ...
            'gcheck_cfg', gc, 'cal_cfg', cal_cfg, 'key_cfg', key_cfg, 'model', model.description, ...
            'windowSize', [width height], 'screenid', screenid, ...
            'timestamp', datestr(now, 'yyyy-mm-dd_HHMMSS'));
        outFile = [logdir fs 'GammaCheck_' GammaCheck.timestamp '.mat'];
        save(outFile, 'GammaCheck');
        if stopped, endState = 'stopped early (Esc); squares so far'; else, endState = 'completed and'; end
        waitAtEnd(wptr, [0 0 0], sprintf('Gamma check %s saved:\n  %s', endState, outFile));
    end

    ListenChar(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
catch err
    ListenChar(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end

end


function drawPage(wptr, sq, surround, page, active, nC, y0)
% One channel's screen: every square of that page with its surround; the
% active square (adjust mode) outlined just outside its tile.
Screen('FillRect', wptr, 0);
for i = find([sq.page] == page)
    Screen('FillRect', wptr, chanColour(sq(i).chan, surround(i)), sq(i).outer);
    Screen('DrawTexture', wptr, sq(i).tex, [], sq(i).inner, [], 0);
    DrawFormattedText(wptr, sq(i).label, sq(i).outer(1), sq(i).outer(4) + 30, 128);
    if i == active, Screen('FrameRect', wptr, 128, sq(i).outer + [-6 -6 6 6], 2); end
end
DrawFormattedText(wptr, sprintf('%s   (%d/%d)', sq(find([sq.page] == page, 1)).chan, page, nC), 'center', y0 - 40, 128);
Screen('Flip', wptr);
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
