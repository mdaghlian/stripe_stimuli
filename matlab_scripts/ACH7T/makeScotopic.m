function makeScotopic(name_subj, name_sess)
% makeScotopic  Pre-render the achromatic drifting-grating frames for
%               bwNasrScotopic.
%
%   makeScotopic(name_subj, name_sess)
%
%   Writes one full grating cycle (scot_cfg.nPhaseSteps frames) for each
%   orientation in scot_cfg.baseOriList, as 16-bit PNGs, to
%     <dir_base>/<subj>/bwNasrScotopic/<sess>/stimuli/bw_grating_<ori>_degrees/<step>.png
%   plus stimuli/logfiles/stim_metadata.mat (read back by bwNasrScotopic).

close all
cfg_start;
fs = filesep;

if ~exist('name_subj','var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess  = 'TestSess';  end

% -------------------------------------------------------------------------
% Directories
% -------------------------------------------------------------------------
dir_base = cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
pathfile = [dir_base fs name_subj fs 'bwNasrScotopic' fs name_sess fs 'stimuli'];
if exist(pathfile,'dir')~=7, mkdir(pathfile); end

% -------------------------------------------------------------------------
% Geometry (images downsampled by image_frac for speed / memory)
% -------------------------------------------------------------------------
gw = round(cfg.width  * cfg.image_frac);
gh = round(cfg.height * cfg.image_frac);

px_per_cm   = gh / cfg.height_cm;                       % accounts for downsampling
cm_per_deg  = 2 * cfg.distance_cm * tan(deg2rad(0.5));
deg_per_px  = 1 / (px_per_cm * cm_per_deg);
px_per_deg  = 1 / deg_per_px;                           % in image px (half resolution), not screen px

stim_cpd        = scot_cfg.stim_cpd;
nPhaseSteps     = scot_cfg.nPhaseSteps;
baseOriList     = scot_cfg.baseOriList;
spatialFreq_cpp = stim_cpd * deg_per_px;                % cycles per pixel

% Luminance: full-contrast sinusoid around the matched background,
% 0 to 2 x background in LUMINANCE (display model), so the grating's mean
% equals the background and rest. The ND filters scale everything alike.
model = displayModel(cal_cfg);
bg    = backgroundLuminance(name_subj, name_sess);

% -------------------------------------------------------------------------
% Full-contrast achromatic gratings (in luminance), one folder per orientation
% -------------------------------------------------------------------------
[Xm, Ym] = meshgrid(1:gw, 1:gh);
phaseStep = 1 / nPhaseSteps;
for o = 1:length(baseOriList)
    outFolder = [pathfile fs 'bw_grating_' sprintf('%d', baseOriList(o)) '_degrees'];
    if exist(outFolder,'dir')~=7, mkdir(outFolder); end

    thetaRad = deg2rad(baseOriList(o));
    Xt = Xm * cos(thetaRad) + Ym * sin(thetaRad);
    Xp = Xt * spatialFreq_cpp * 2 * pi;
    for step = 1:nPhaseSteps
        phaseRad = phaseStep * step * 2 * pi;
        grating  = sin(Xp + phaseRad);                      % [-1, 1]
        drive    = model.d('W', bg.L * (1 + grating));     % luminance 0 .. 2 x background -> drive
        imwrite(uint16(drive / 255 * 65535), ...            % 16-bit
                [outFolder fs sprintf('%d', step) '.png'], 'PNG');
    end
    fprintf('Orientation %d deg written (%d/%d)\n', baseOriList(o), o, length(baseOriList));
end
fprintf('Scotopic grating frames written to: %s\n', pathfile);

% -------------------------------------------------------------------------
% Save metadata (last, so its presence means the frames are complete)
% -------------------------------------------------------------------------
stim_params_scot.cfg             = cfg;
stim_params_scot.scot_cfg        = scot_cfg;
stim_params_scot.stim_cpd        = stim_cpd;
stim_params_scot.nPhaseSteps     = nPhaseSteps;
stim_params_scot.baseOriList     = baseOriList;
stim_params_scot.px_per_cm       = px_per_cm;
stim_params_scot.deg_per_px      = deg_per_px;
stim_params_scot.px_per_deg      = px_per_deg;                 % image px (kept under this name for older sessions)
stim_params_scot.px_per_deg_screen = px_per_deg / cfg.image_frac;
stim_params_scot.spatialFreq_cpp = spatialFreq_cpp;
stim_params_scot.background      = bg;                         % rest level (bg.drive) and its source
stim_params_scot.displayModel    = model.description;
stim_params_scot.timestamp       = datetime('now');
metafile = [pathfile fs 'logfiles'];
if exist(metafile,'dir')~=7, mkdir(metafile); end
save([metafile fs 'stim_metadata.mat'], 'stim_params_scot');
fprintf('Metadata saved.\n');
