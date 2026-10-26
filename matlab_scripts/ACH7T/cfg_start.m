% Move magic numbers & settings to one file
cfg = struct();

% Paths 
cfg.PTB_dir = '/Users/marcusdaghlian/programs/experiments/Psychtoolbox';
cfg.dir_base = '/Users/marcusdaghlian/programs/experiments/stripe_stimuli/matlab_scripts/ACH7T/logs';

% Display refresh rate: every run script and the isoluminance tasks abort
% unless the measured rate is expectedHz +/- toleranceHz (see checkRefreshRate.m).
cfg.expectedHz = 60;
cfg.toleranceHz = 1;

cfg.eye_track = 0;
cfg.eye_calib = 0;
% Screen settings
%{
From FIL pdf
7T projector

Resolution      Width       Height      Distance    Height (dva)
1920 x 1200     355         220         1130        11.1
1920 x 1080     355         200         1130        10.1 <<<< USE THIS ONE

%}
% mac = 1470, 956
% acer home = 2560, 1440

cfg.width = 1470; % 1920;
cfg.height = 956; % 1080;
cfg.screenid = 0; % 1 screenid
cfg.image_frac = 0.5; % For generating images downsample for speed / memory
% 

cfg.distance_cm = 113.0; % 
cfg.height_cm   = 20.0;

%% FIXATION TASK (FixationTask.m) - shared by all run scripts
% Vigilance task: the central marker changes every minInterval-maxInterval s
% and the participant presses 1 at each change.
fix_cfg = struct();
fix_cfg.style       = 'dot';      % 'dot' (central marker) or 'cross' (full-screen cross, corner to corner)
fix_cfg.size        = 10;         % dot half-width, px (circle/triangle are matched in area to this square)
fix_cfg.lineWidth   = 4;          % cross line width, px
fix_cfg.task        = 'shape';   % 'colour' (light <-> dark green) or 'shape' (shapeA <-> shapeB)
fix_cfg.dotShape    = 'square';   % marker shape in the colour task: 'square', 'circle' or 'triangle'
fix_cfg.shapeA      = 'triangle'; % shape task: the two shapes alternated between
fix_cfg.shapeB      = 'circle';
fix_cfg.colourIdle  = [255 255 255]; % before the trigger
fix_cfg.colourA     = [0 255 0];  % light green (also the cross colour in the shape task)
fix_cfg.colourB     = [0 180 0];  % dark green
fix_cfg.colourShape = [255 255 255];  % shape colour in the shape task
fix_cfg.minInterval = 4;          % time between changes is uniform in [minInterval, maxInterval] s
fix_cfg.maxInterval = 10;

% findIso_cfg settings
findIso_cfg = struct();
findIso_cfg.nReps = 3; % 3
findIso_cfg.JitterSize = 10;
findIso_cfg.nCond1 = 3; % eccentricity bands
% Band edges as a fraction of screen height (radius). LW's code had .3257
% for the middle edge (digits transposed?); which was intended is unclear.
% The outer edge (.6603 H) extends past the half-height on a 16:9 screen.
findIso_cfg.cond_px_bands = [.1350 .3527 .6603];
findIso_cfg.ecc_mean = [
    findIso_cfg.cond_px_bands(1)/2
    ((findIso_cfg.cond_px_bands(1)+findIso_cfg.cond_px_bands(2))/2)
    ((findIso_cfg.cond_px_bands(2)+findIso_cfg.cond_px_bands(3))/2)
    ];
findIso_cfg.fixSize = 4; % fixation dot size (pixels)
% Flicker frequency = refresh / (2*framesPerField): 1 = 30 Hz at 60 Hz, 2 = 15 Hz.
% With framesPerField ~= 1 the data and fits get a _<Hz>Hz suffix (isoFileTag),
% and the analysis, makeStimuli and backgroundLuminance use those files instead.
findIso_cfg.framesPerField = 1;
% Abort if the measured refresh rate is not the expected one.
findIso_cfg.expectedHz = cfg.expectedHz;
findIso_cfg.toleranceHz = cfg.toleranceHz;
% Per ecc band; what is the starting *luminance* of the channels being adjusted
% In blue -> applies to grey; in red -> applies to red
findIso_cfg.startPointBlue = [60 70 80];
findIso_cfg.startPointRed = [180 200 220];


% settings
stim_cfg = struct();
% -> used in makeStim
stim_cfg.nPhaseSteps = 30; % frames per grating cycle; makeStimuli writes them, colourProject/stimViewer load them
stim_cfg.TF_hz = 2;        % drift temporal frequency, Hz
%{
Drift: the run scripts take the grating phase from the flip timestamps,
so the speed is TF_hz / stim_cpd whatever the refresh rate:
    2 Hz / 0.4 cpd = 5 deg/s
For smooth motion each frame should advance a whole number of phase steps:
    TF_hz * nPhaseSteps / cfg.expectedHz = 2 * 30 / 60 = 1 step per frame
%}
stim_cfg.stim_cpd = 0.4;  % Stim cycles per degree
stim_cfg.thetaList = [0 45 90 135];
% -> used in colourProject
stim_cfg.nBlocks=8; % has to be int multiple of nConditions
stim_cfg.nConditions=8; 
stim_cfg.nRuns=10;
stim_cfg.BlockTime=30;%30;
stim_cfg.DelayTime=15;%15; 
stim_cfg.save_screen=0;
% 
stim_cfg.colourCondLabels={'bw', 'colour'};
stim_cfg.FadingTime=1; % duration of each fade in / fade out, s (1 s originally); must be <= BlockTime/2


%% DISPLAY MODEL (displayModel.m) - makeStimuli builds the colour and BW
% gratings in linear luminance with this model, then converts to drive.
% See ACH7T_calibration_plan.md, Section 5 (step 1a / step 3, option A).
cal_cfg = struct();
cal_cfg.type   = 'FIL7T';      % 'FIL7T' (measured tables), 'table', 'gamma' or 'linear'
cal_cfg.filter = 'noFilter';   % FIL7T: 'noFilter', '1xNDFilter', '2xNDFilter', '3xNDFilter'
% Alternatives (set by hand):
%   cal_cfg.type = 'table';  cal_cfg.file = '/path/to/table.csv';   % columns drive,R,G,B,W
%   cal_cfg.type = 'gamma';  cal_cfg.gamma = 2.26;                  % or [R G B W]
%                            cal_cfg.clip  = [255 206 222 255];     % drive where each channel stops rising (R G B W)
%                            cal_cfg.Lmax  = [111.9 830 26.5 952];  % luminance at the clip (relative units are fine)
%   cal_cfg.type = 'linear';                                        % no gamma correction (stimuli in drive units)
cal_cfg.background = 'matched';  % background/rest luminance of ALL paradigms (backgroundLuminance.m):
                                 % 'matched' = grey matched to the colour grating (colour-session flicker fits),
                                 % or a number = fixed luminance in display-model units (cd/m^2 for FIL7T)
cal_cfg.rbCorrection = false;  % true: makeStimuli scales the colour grating by the measured
                               % R+B additivity m(g) (latest RBadditivity_*.mat of the session)

% R + B additivity check (checkAdditivityRB.m; calibration plan step 1b)
rbcheck_cfg = struct();
rbcheck_cfg.band          = 2;                 % findIso_cfg eccentricity band used as the test field
rbcheck_cfg.blueFractions = [0.25 0.5 0.75];   % blue fraction p of the tested mixtures
rbcheck_cfg.nRepsMatch    = 3;                 % red vs blue matches (observer's k)
rbcheck_cfg.nRepsMix      = 3;                 % repetitions per mixture
rbcheck_cfg.flickerHz     = 15;                % full-cycle flicker rate (alternation = 2x); 30 = every frame at 60 Hz
rbcheck_cfg.step          = 0.015;             % luminance step per key press (fraction)
rbcheck_cfg.jitter        = 0.10;              % start value 1 +/- jitter
rbcheck_cfg.surround      = 'matched';         % 'matched' (grey at blue's luminance) or 'black'
rbcheck_cfg.tolerance     = 0.03;              % |m - 1| treated as additive

% Responses in the flicker tasks (findIsoluminance_Red/_Blue, checkAdditivityRB; flickerKeys.m)
key_cfg = struct();
key_cfg.device         = -3;    % KbCheck device: -3 = all keyboards and keypads (incl. button boxes)
key_cfg.holdDelay      = 0.4;   % s a key must be held before it auto-repeats
key_cfg.repeatInterval = 0.06;  % s between repeated steps while held (~16 steps/s)




%% CHEQ
% --- Spatial frequency ---
cheq_cfg.stim_cpd = 0.4;      % Radial spatial frequency in cycles per degree
cheq_cfg.nWedges = 8;      % Angular frequency: sin(nWedges*theta) -> 2*nWedges sectors (16)
% --- Temporal frequency ---
cheq_cfg.TF_hz = 4;           % Contrast reversals per second (not full cycles):
                               % each reversal flips black<->white, so 4
                               % reversals/s = 2 Hz full contrast cycle.
% --- Block timing ---
cheq_cfg.nBlocks   = 4;      % Total number of ON blocks
cheq_cfg.BlockTime = 20;      % Duration of each ON (stimulus) block in seconds
cheq_cfg.OffTime   = 45;      % Duration of each OFF (rest/fixation) block in seconds
cheq_cfg.initial_blank=5;
cheq_cfg.end_blank=5;

% --- Misc display ---
cheq_cfg.save_screen = 0;     % Set to 1 to save screenshots each frame


%% SCOTOPIC (makeScotopic.m -> bwNasrScotopic.m)
% Achromatic drifting grating, Nasr scotopic paradigm.
% Timing: 16 + 7 x (16 s stim + 16 s blank) = 240 s
scot_cfg = struct();
% --- Stimulus (baked into images by makeScotopic) ---
scot_cfg.stim_cpd      = 0.2;   % spatial frequency, cycles/degree
scot_cfg.nPhaseSteps   = 75;    % phase steps per cycle: speed*cpd*75/60 = 4*0.2*75/60 = 1 step per frame at 60 Hz
scot_cfg.baseOriList   = [0 45 90 135]; % rendered orientations (gratings repeat every 180 deg)
% --- Motion ---
scot_cfg.speed_dps     = 4;     % drift speed, deg/s
scot_cfg.reversalTime  = 6;     % motion direction reverses every reversalTime s
% --- Block timing ---
scot_cfg.oriStep       = 45;    % orientation step between blocks, deg
scot_cfg.nBlocks       = 7;     % number of stimulation blocks
scot_cfg.BlockTime     = 16;    % stimulation block, s
scot_cfg.BlankTime     = 16;    % blank after each block, s
scot_cfg.initial_blank = 16;    % blank at run start, s
% --- Misc ---
scot_cfg.save_screen   = 0;     % set to 1 to save a screenshot every frame


%% MT LOCALISER (makeMT.m -> mtLocalizer.m)
% Based on NasrOriginal/Motion/My_MT_localizer_HighRes.m. Default values
% are measured from Nasr's pre-rendered ring images (MyStimuli/1_*.tif),
% converted to degrees with the 38.4 px/deg that Nasr's code assumes.
mt_cfg = struct();
% --- Stimulus: thin dark rings on grey, expanding/contracting ---
mt_cfg.ringPeriod_deg  = 2.0;   % centre-to-centre ring spacing (Nasr: 76.7 px)
mt_cfg.ringWidth_deg   = 0.42;  % ring thickness (Nasr: 16 px)
mt_cfg.speed_dps       = 5;     % radial speed, deg/s (Nasr: 3.2 px/frame at 60 Hz)
mt_cfg.apertureFrac    = Inf;   % aperture radius as a fraction of screen height; Inf = rings fill the whole screen (Nasr: a 768-px disc)
mt_cfg.ringLum         = 101;   % ring grey level (Nasr: 101)
mt_cfg.bgLum           = 127;   % background grey level (Nasr: 127)
mt_cfg.nPhaseSteps     = 48;    % phase steps per ring period: (5/2)*48/60 = 2 steps per frame at 60 Hz
% --- Block timing (Nasr: 12 s + 5 x (24 s static + 24 s moving) + 12 s = 264 s) ---
mt_cfg.initial_blank   = 12;    % rest at run start, s
mt_cfg.end_blank       = 12;    % rest at run end, s
mt_cfg.StaticTime      = 24;    % static block, s
mt_cfg.MovingTime      = 24;    % moving block, s
mt_cfg.nCycles         = 5;     % number of static+moving pairs
mt_cfg.reversalTime    = 2;     % moving blocks reverse direction every reversalTime s
mt_cfg.startDir        = -1;    % first direction in each moving block: -1 contract, +1 expand (Nasr: contract)
% --- Misc ---
mt_cfg.save_screen     = 0;     % set to 1 to save a screenshot every frame
