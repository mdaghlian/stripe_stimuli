function tag = isoFileTag(findIso_cfg)
% isoFileTag  File-name suffix for the isoluminance data and fits.
%
%   tag = isoFileTag(findIso_cfg)
%
%   '' at the default flicker (framesPerField = 1, refresh/2), otherwise
%   '_<Hz>Hz' (e.g. '_15Hz'). Used for redIsoLumData, bwIsoLumData,
%   redFitData and bwFitData, so the findIsoluminance scripts, their
%   analysis, makeStimuli and backgroundLuminance all read and write the
%   files for the flicker rate set in cfg_start.

tag = '';
if findIso_cfg.framesPerField ~= 1
    tag = sprintf('_%gHz', findIso_cfg.expectedHz / (2 * findIso_cfg.framesPerField));
end
