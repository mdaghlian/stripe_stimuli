function makeCheq(name_subj, name_sess)
% makeCheq  Pre-render the two checkerboard frames (normal + inverted)
%                   for the flashing checkerboard experiment.
%
%   makeCheckerboard(name_subj, name_sess)

close all
cfg_start;
fs = filesep;

if ~exist('name_subj','var'), name_subj = 'TestSubj'; end
if ~exist('name_sess', 'var'), name_sess  = 'TestSess';  end

% -------------------------------------------------------------------------
% Directories
% -------------------------------------------------------------------------
dir_base = cfg.dir_base;
pathfile = [dir_base fs name_subj fs 'cheq' fs name_sess fs 'stimuli'];
if ~isfolder(pathfile), mkdir(pathfile); end
outFolder = [pathfile fs 'checkerboard_frames'];
if ~isfolder(outFolder), mkdir(outFolder); end

% -------------------------------------------------------------------------
% Geometry
% -------------------------------------------------------------------------
width  = cfg.width;
height = cfg.height;

px_per_cm  = height / cfg.height_cm;
cm_per_deg = 2 * cfg.distance_cm * tan(deg2rad(0.5));
deg_per_px = 1 / (px_per_cm * cm_per_deg);  % degrees per pixel

% Radial SF: cheq_cfg.stim_cpd is cycles-per-degree in the radial direction.
% In log-polar space one "cycle" spans log(2π/stim_cpd) in log-r units.
% We express it as radial_cycles_per_log_unit below.
cpd       = cheq_cfg.stim_cpd;                     % cycles per degree (radial)
px_per_deg = 1 / deg_per_px;

% -------------------------------------------------------------------------
% Build the checkerboard mask in log-polar space
% -------------------------------------------------------------------------
[Xm, Ym] = meshgrid(1:width, 1:height);
cx = width  / 2;
cy = height / 2;

% Polar coordinates centred on screen
Xc = Xm - cx;
Yc = Ym - cy;

% Radial distance in degrees
R_px  = sqrt(Xc.^2 + Yc.^2);
R_deg = R_px * deg_per_px;          % eccentricity in degrees

% Angular coordinate
Theta = atan2(Yc, Xc);             % –π … π

% Number of angular wedges: chosen so that at 1° eccentricity, one wedge
% subtends roughly the same arc as one radial cycle.
%   arc_length at 1° ecc = ecc_deg * wedge_angle_rad
%   set arc ≈ 1/cpd  →  wedge_angle = (1/cpd) / ecc_deg = 1 at ecc=1°
% A good default is nWedges = round(2 * π * cpd) so the angular period
% matches the radial period near 1° eccentricity.
nWedges = cheq_cfg.nWedges;

% Radial grating (sign of sin): +1 or -1 per annulus
radialPart  = sin(2 * pi * cpd * R_deg);

% Angular grating: nWedges wedges around full circle
angularPart = sin(nWedges * Theta);

% Checkerboard = product of two orthogonal square waves (via sign)
checker = sign(radialPart) .* sign(angularPart);

% Clamp centre pixel (log(0) artefact)
checker(R_px < 1) = 0;

% Convert to [0, 1]: +1 → white, –1 → black, 0 → mid-grey (centre)
frame0 = (checker + 1) / 2;        % phase 0  (normal)
frame1 = (-checker + 1) / 2;       % phase 1  (inverted / reversed)

% -------------------------------------------------------------------------
% Save metadata
% -------------------------------------------------------------------------
stim_params_cheq.cfg              = cfg;
stim_params_cheq.cheq_cfg         = cheq_cfg;
stim_params_cheq.px_per_cm        = px_per_cm;
stim_params_cheq.deg_per_px       = deg_per_px;
stim_params_cheq.cpd              = cpd;
stim_params_cheq.timestamp        = datetime('now');
metafile = [pathfile fs 'logfiles'];
if ~isfolder(metafile), mkdir(metafile); end
save([metafile fs 'stim_metadata.mat'], 'stim_params_cheq');
fprintf('Metadata saved.\n');

% -------------------------------------------------------------------------
% Write the two frames as 16-bit PNGs
% -------------------------------------------------------------------------
imwrite(uint16(frame0 * 65535), [outFolder fs 'frame0.png'], 'PNG');
imwrite(uint16(frame1 * 65535), [outFolder fs 'frame1.png'], 'PNG');
fprintf('Checkerboard frames written to: %s\n', outFolder);