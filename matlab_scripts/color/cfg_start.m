% Computer Configuration
cfg = struct();

% Paths 
cfg.PTB_dir = '/Users/marcusdaghlian/programs/experiments/Psychtoolbox';
cfg.dir_base = '/Users/marcusdaghlian/programs/experiments/stripe_stimuli/matlab_scripts/color/logs';

% Screen settings
cfg.width = 1470; % 1920;
cfg.height = 956; %1080;
cfg.screenid = 0; % which screen

% findIso_cfg settings
findIso_cfg = struct();
findIso_cfg.nReps = 1;
findIso_cfg.JitterSize = 10;
findIso_cfg.nCond1 = 3; % eccentricity bands
findIso_cfg.fixSize = 2; % fixation dot size
findIso_cfg.startPointBlue = [60 70 80];
findIso_cfg.startPointRed = [180 200 220];

% settings
stim_cfg = struct();
% -> used in makeStim
stim_cfg.nPhaseSteps = 30; 
stim_cfg.lambda = 107; % in px
stim_cfg.thetaList = [0 45 90 135];
% -> used in colourProject
stim_cfg.nBlocks=8; % has to be int multiple of nConditions
stim_cfg.nConditions=8; 
stim_cfg.nRuns=10;
stim_cfg.BlockTime=10;%30;
stim_cfg.DelayTime=5;%15; 
stim_cfg.save_screen=0;
% 
stim_cfg.nSteps=30;
stim_cfg.colourCondLabels={'bw', 'colour'};
stim_cfg.fixSize=2;
stim_cfg.FadingTime=1; % 1s originally


% FOR SEQ
stim_cfg.Bcondition_list= {'rest', 'bw','bw', 'rest', 'colour', 'bw', 'colour','bw', 'rest'};
stim_cfg.Bori_per_stim = 2; % 2 orientations per stim
stim_cfg.Bdirection_per_ori = 2; % 2 directions per orientation 

