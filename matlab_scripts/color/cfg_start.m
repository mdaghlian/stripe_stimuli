% Move magic numbers & settings to one file
cfg = struct();

% Paths 
cfg.PTB_dir = '/Users/marcusdaghlian/programs/experiments/Psychtoolbox';
cfg.dir_base = '/Users/marcusdaghlian/programs/experiments/stripe_stimuli/matlab_scripts/color/logs';

% Screen settings
%{
From FIL pdf
7T projector

Resolution      Width       Height      Distance    Height (dva)
1920 x 1200     355         220         1130        11.1
1920 x 1080     355         200         1130        10.1

%}

cfg.width = 1470; % 1920;
cfg.height = 956; % 1080;
cfg.screenid = 0; % 1 screenid
cfg.image_frac = 0.5; % For generating images downsample for speed / memory
% 

cfg.distance_cm = 113.0; % 
cfg.height_cm   = 20.0;
px_per_cm = cfg.height / cfg.height_cm;
cm_per_deg = 2 * cfg.distance_cm * tan(deg2rad(0.5));
cfg.px_per_deg = px_per_cm * cm_per_deg;

% findIso_cfg settings
findIso_cfg = struct();
findIso_cfg.nReps = 1; % 3
findIso_cfg.JitterSize = 10;
findIso_cfg.nCond1 = 3; % eccentricity bands
findIso_cfg.cond_px_bands = [.1350 .3527 .6603];
findIso_cfg.ecc_mean = [
    findIso_cfg.cond_px_bands(1)/2
    ((findIso_cfg.cond_px_bands(1)+findIso_cfg.cond_px_bands(2))/2)
    ((findIso_cfg.cond_px_bands(2)+findIso_cfg.cond_px_bands(3))/2)
    ];
findIso_cfg.fixSize = 4; % fixation dot size (pixels)
% Per ecc band; what is the starting *luminance* of the channels being adjusted
% In blue -> applies to grey; in red -> applies to red
findIso_cfg.startPointBlue = [60 70 80];
findIso_cfg.startPointRed = [180 200 220];


% settings
stim_cfg = struct();
% -> used in makeStim
stim_cfg.nPhaseSteps = 30; 
%{
Drift speed is determined by three parameters:

    speed (deg/s) = (monitor_hz / nPhaseSteps) / stim_cpd

Where:
    monitor_hz  = assumed 60 Hz 
    nPhaseSteps = 30  (frames per full grating cycle, set in makeStimuli)
    stim_cpd    = 0.4 (cycles per degree, baked into images at generation time)

    -> temporal frequency = 60 / 30 = 2 Hz
    -> drift speed        = 2 / 0.4 = 5 deg/s
%}
stim_cfg.lambda = 107; % in px
stim_cfg.stim_cpd = 0.4;  % Stim cycles per degree - in competition with weird hard coded 107
stim_cfg.thetaList = [0 45 90 135];
% -> used in colourProject
stim_cfg.nBlocks=8; % has to be int multiple of nConditions
stim_cfg.nConditions=8; 
stim_cfg.nRuns=10;
stim_cfg.BlockTime=30;%30;
stim_cfg.DelayTime=15;%15; 
stim_cfg.save_screen=0;
% 
stim_cfg.nSteps=30;
stim_cfg.colourCondLabels={'bw', 'colour'};
stim_cfg.fixSize=10;
stim_cfg.FadingTime=1; % 1s originally


% FOR SEQ
stim_cfg.Bcondition_list= {'bw', 'bw','rest', 'bw', 'bw', 'rest','bw', 'bw', };
stim_cfg.Bori_per_stim = 2; % 2 orientations per stim
stim_cfg.Bdirection_per_ori = 2; % 2 directions per orientation 



%% CHEQ
% --- Spatial frequency ---
cheq_cfg.stim_cpd = 0.4;      % Radial spatial frequency in cycles per degree
cheq_cfg.nWedges = 8;      % Radial spatial frequency in cycles per degree
% --- Temporal frequency ---
cheq_cfg.TF_hz = 4;           % Temporal frequency in Hz (checkerboard reversals per second)
                               % Each "reversal" flips black<->white, so
                               % at 8 Hz the pattern inverts 8 times/sec.
% --- Block timing ---
cheq_cfg.nBlocks   = 4;      % Total number of ON blocks
cheq_cfg.BlockTime = 20;      % Duration of each ON (stimulus) block in seconds
cheq_cfg.OffTime   = 45;      % Duration of each OFF (rest/fixation) block in seconds
cheq_cfg.initial_blank=5;
cheq_cfg.end_blank=5;

% --- Fixation ---
cheq_cfg.fixSize = 4;        % Fixation dot half-size in pixels

% --- Misc display ---
cheq_cfg.save_screen = 0;     % Set to 1 to save screenshots each frame