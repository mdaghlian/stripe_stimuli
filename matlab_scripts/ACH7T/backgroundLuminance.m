function bg = backgroundLuminance(name_subj, name_sess)
% backgroundLuminance  Background / rest luminance shared by all paradigms:
% the grey matched to the colour grating for this observer.
%
%   bg = backgroundLuminance(name_subj, name_sess)
%
%   Default (cal_cfg.background = 'matched'): the subject's colour-session
%   flicker fits (<dir_base>/<subj>/colour/<sess>/stimuli/logfiles/bwFitData<tag>.mat, tag from isoFileTag)
%   give, per eccentricity, the grey drive that matched blue at full drive.
%   Converted to luminance with displayModel(cal_cfg), its median over the
%   screen is the background: the luminance of the colour grating, of the
%   BW grating's mean, and of rest. The eccentricity mapping is the one
%   makeStimuli uses (full-screen px, clamped to the calibrated bands).
%
%   If that session has no flicker fits, the background falls back to the
%   standard-observer prediction: the grey with the same model luminance
%   as blue at full drive (a warning is printed).
%
%   cal_cfg.background can also be a number: a fixed luminance (display
%   model units, cd/m^2 for the FIL 7T tables).
%
%   Returns bg.L (luminance above black), bg.drive (W drive, not rounded),
%   bg.source (text) and bg.model (model description).
%
%   With ND filters in the light path the model's luminances are scaled
%   down by the filters, but the drive values (and so the stimuli) are the
%   same: the filters do not change the transfer curve.

cfg_start;
fs = filesep;
model = displayModel(cal_cfg);
setting = 'matched';
if isfield(cal_cfg, 'background') && ~isempty(cal_cfg.background), setting = cal_cfg.background; end

if isnumeric(setting)
    bg.L = setting;
    bg.source = sprintf('fixed (cal_cfg.background = %g)', setting);
else
    fitFile = [cfg.dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles' fs 'bwFitData' isoFileTag(findIso_cfg) '.mat'];
    if exist(fitFile, 'file') == 2
        s = load(fitFile, 'bwParams');
        % eccentricity map as in makeStimuli (image grid, full-screen px, clamped)
        width  = cfg.width * cfg.image_frac;
        height = cfg.height * cfg.image_frac;
        [Xm, Ym] = meshgrid(1:width, 1:height);
        R = sqrt((Xm - width/2).^2 + (Ym - height/2).^2) / cfg.image_frac;
        R = log(min(max(R, findIso_cfg.ecc_mean(1) * cfg.height), findIso_cfg.ecc_mean(end) * cfg.height));
        greyMatch = min(max(polyval(s.bwParams, R), 0), 255);
        bg.L = median(reshape(model.dL('W', greyMatch), [], 1));
        bg.source = sprintf('matched grey from %s', fitFile);
    else
        bg.L = model.dLmax.B;
        bg.source = 'standard observer: grey isoluminant with blue at full drive (no flicker fits found)';
        warning('backgroundLuminance: no flicker fits in %s; using the standard-observer grey. Run findIsoluminance_Blue for this subject/session for a matched background.', fitFile);
    end
end
bg.drive = model.d('W', bg.L);
bg.model = model.description;
fprintf('Background: %.3g (model units) = W drive %.1f [%s]\n', bg.L, bg.drive, bg.source);
end
