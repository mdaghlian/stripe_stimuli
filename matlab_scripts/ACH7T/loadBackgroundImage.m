function [bgImg, desc] = loadBackgroundImage(stimdir, sp, sz)
% loadBackgroundImage  Background / rest image of the colour paradigm, in
% drive units (0-255, not rounded), as made by makeStimuli.
%
%   [bgImg, desc] = loadBackgroundImage(stimdir, sp, sz)
%
%   stimdir  the session's stimuli folder (<dir_base>/<subj>/colour/<sess>/stimuli)
%   sp       stim_params from the stim_metadata the stimuli were made with
%   sz       [height width] of the uniform image returned when there is no
%            radial background
%
%   Radial background (sp.radialBackground, stim_cfg.radialBackground when
%   the stimuli were made): stimuli/background.png, the matched grey at each
%   eccentricity, at the stimuli's image size (draw it full screen, as the
%   gratings). Otherwise a uniform image at round(sp.background.drive).

fs = filesep;
if isfield(sp, 'radialBackground') && sp.radialBackground
    f = [stimdir fs sp.backgroundImage];
    if exist(f, 'file') ~= 2
        error('loadBackgroundImage: %s not found. Regenerate the stimuli with makeStimuli.', f);
    end
    bgImg = double(imread(f)) / 65535 * 255;
    desc = sprintf('radial matched grey, W drive %.1f-%.1f (%s)', min(bgImg(:)), max(bgImg(:)), sp.backgroundImage);
else
    bgImg = round(sp.background.drive) * ones(sz);
    desc = sprintf('uniform W drive %d (%s)', round(sp.background.drive), sp.background.source);
end
end
