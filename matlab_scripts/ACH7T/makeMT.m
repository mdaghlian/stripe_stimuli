function makeMT(name_subj, name_sess)
% makeMT  Pre-render the ring frames for the MT localiser (mtLocalizer).
%
%   makeMT(name_subj, name_sess)
%
%   Writes one full ring period (mt_cfg.nPhaseSteps frames) as 16-bit PNGs to
%     <dir_base>/<subj>/mt/<sess>/stimuli/ring_frames/<step>.png
%   plus stimuli/logfiles/stim_metadata.mat (read back by mtLocalizer).
%   The radial offset of each frame is (step-1)/nPhaseSteps of a period,
%   so higher step = rings further out.

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
pathfile = [dir_base fs name_subj fs 'mt' fs name_sess fs 'stimuli'];
if exist(pathfile,'dir')~=7, mkdir(pathfile); end
outFolder = [pathfile fs 'ring_frames'];
if exist(outFolder,'dir')~=7, mkdir(outFolder); end

% -------------------------------------------------------------------------
% Geometry (images downsampled by image_frac for speed / memory)
% -------------------------------------------------------------------------
gw = round(cfg.width  * cfg.image_frac);
gh = round(cfg.height * cfg.image_frac);

px_per_cm  = gh / cfg.height_cm;                    % accounts for downsampling
cm_per_deg = 2 * cfg.distance_cm * tan(deg2rad(0.5));
px_per_deg = px_per_cm * cm_per_deg;               % in image px (half resolution), not screen px

nPhaseSteps = mt_cfg.nPhaseSteps;
period_px   = mt_cfg.ringPeriod_deg * px_per_deg;
ringW_px    = mt_cfg.ringWidth_deg  * px_per_deg;
aperture_px = mt_cfg.apertureFrac   * gh;
ringLum     = mt_cfg.ringLum;
bgLum       = mt_cfg.bgLum;

% -------------------------------------------------------------------------
% Thin dark rings on grey inside a circular aperture
% -------------------------------------------------------------------------
[Xm, Ym] = meshgrid(1:gw, 1:gh);
R = sqrt((Xm - (gw+1)/2).^2 + (Ym - (gh+1)/2).^2);

for step = 1:nPhaseSteps
    offset_px = (step - 1) / nPhaseSteps * period_px;
    % distance (px) from the centre line of the nearest ring
    e = abs(mod(R - offset_px + period_px/2, period_px) - period_px/2);
    % ring coverage with a 1-px linear edge (anti-aliasing)
    cover = min(max(ringW_px/2 - e + 0.5, 0), 1);
    % soft aperture edge
    cover = cover .* min(max(aperture_px - R + 0.5, 0), 1);
    imwrite(uint16(((bgLum + (ringLum - bgLum) * cover) / 255) * 65535), ...
            [outFolder fs sprintf('%d', step) '.png'], 'PNG');
end
fprintf('MT ring frames written to: %s\n', outFolder);

% -------------------------------------------------------------------------
% Save metadata (last, so its presence means the frames are complete)
% -------------------------------------------------------------------------
stim_params_mt.cfg            = cfg;
stim_params_mt.mt_cfg         = mt_cfg;
stim_params_mt.ringPeriod_deg = mt_cfg.ringPeriod_deg;
stim_params_mt.nPhaseSteps    = nPhaseSteps;
stim_params_mt.bgLum          = bgLum;
stim_params_mt.px_per_cm      = px_per_cm;
stim_params_mt.px_per_deg     = px_per_deg;        % image px (kept under this name for older sessions)
stim_params_mt.px_per_deg_screen = px_per_deg / cfg.image_frac;
stim_params_mt.timestamp      = datetime('now');
metafile = [pathfile fs 'logfiles'];
if exist(metafile,'dir')~=7, mkdir(metafile); end
save([metafile fs 'stim_metadata.mat'], 'stim_params_mt');
fprintf('Metadata saved.\n');
