function makeStimuli(name_subj,name_sess)

close all
% Load computer config
cfg_start; 
fs=filesep;

if ~exist('name_subj','var')  
    name_subj='TestSubj';
end

if ~exist('name_sess','var')  
    name_sess='TestSess';
end

% DIRECTORY
dir_base=cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
pathfile=[dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli'];
% GET VALUES FROM BLUE ISOLUMINANCE
file2Check=[pathfile fs 'logfiles' fs 'bwFitData.mat'];
if ~exist(file2Check,'file')
    error('No such participant or session. Check inputs or make sure findIsoluminance_Blue has been run for this participant!');
else
    load(file2Check);
end
clear file2Check bwValues2Use

% GET VALUES FROM RED ISOLUMINANCE
file2Check=[pathfile fs 'logfiles' fs 'redFitData.mat'];
if ~exist(file2Check,'file')
    error('No such participant or session. Check inputs or make sure findIsoluminance_Red has been run for this participant!');
else
    load(file2Check);
end
clear file2Check redValues2Use

% SHOW ISOLUMINANCE PARAMETERS IN COMMAND WINDOW
bwParams
redParams

% PARAMETERS
stim_params = struct();
% to reduce the calculation for generating and loading all image files,
% we halved the size of the images (1920/2x1080/2)
width=cfg.width * cfg.image_frac;
height=cfg.height * cfg.image_frac;

% -------------------------------
% -------------------------------
% -> drop in to run with cpd <- 
px_per_cm = height / cfg.height_cm;  % accounts for downsampling
cm_per_deg = 2 * cfg.distance_cm * tan(deg2rad(0.5));
deg_per_px = 1/(px_per_cm * cm_per_deg);
spatialFreq = stim_cfg.stim_cpd * deg_per_px; % 
stim_params.px_per_cm = px_per_cm;
stim_params.deg_per_px = deg_per_px;

% Make a struct to save stim_cfg, findIso_cfg, cfg, and px_per_cm etc
% Create a structure to consolidate all experimental parameters

stim_params.stim_cfg = stim_cfg;
stim_params.findIso_cfg = findIso_cfg;
stim_params.cfg = cfg;
stim_params.spatialFreq_cpp = spatialFreq; % cycles per pixel
stim_params.timestamp = datetime('now');
stim_params.bwParams = bwParams;
stim_params.redParams = redParams;
stim_params.eccClamp_px = findIso_cfg.ecc_mean([1 end])*cfg.height; % full-screen px; weights constant outside
% Generate a filename
filename = sprintf('stim_metadata_%s.mat', datestr(now, 'yyyy-mm-dd_HHMM'));
stim_params.note = 'NOTE based on IMAGE FRAC';
% Save the struct to a mat file
stim_file=[pathfile fs 'logfiles' fs filename];
save(stim_file, 'stim_params');

fprintf('Stimulus parameters saved successfully to: %s\n', filename);
% ^^^ drop in to run with cpd ^^^ 
% -------------------------------
% -------------------------------

nPhaseSteps=stim_cfg.nPhaseSteps;
thetaList=stim_cfg.thetaList;

phaseStep=1/nPhaseSteps;

X=1:width;%X is a vector from 1 to width
Y=1:height;  
[Xm,Ym]=meshgrid(X,Y);%2D matrices
R=sqrt(((Xm-width/2).^2)+((Ym-height/2).^2));
R=R/cfg.image_frac;% rescale to full-screen px (fitting is done on full screen)
% Clamp to the calibrated range before taking the log. The fits are
% linear in log(R) through the band centres; evaluating them towards
% R = 1 px drives the weights down (dark spot at the centre), and beyond
% the outer band they are extrapolated too. Inside the innermost and
% outside the outermost band centre the weights are held constant.
R_min=findIso_cfg.ecc_mean(1)*cfg.height;
R_max=findIso_cfg.ecc_mean(end)*cfg.height;
R=log(min(max(R,R_min),R_max));

% DISPLAY MODEL (cal_cfg in cfg_start): drive <-> luminance per channel
model=displayModel(cal_cfg);
fprintf('Display model: %s\n', model.description);

% FLICKER MATCHES -> LUMINANCE
% The isoluminance tasks give drive values (per pixel, via the fits):
%   greyMatch: grey (R=G=B) drive that matched blue at full drive
%   redMatch:  red drive that matched that grey
% Converted to luminance with the display model, the stimuli are then built
% in linear luminance and converted back to drive per channel, so that the
% observer's match holds at every phase of the grating, not only at the
% peaks. With cal_cfg.type = 'linear' this reduces to the old drive-unit
% stimuli.
greyMatch=polyval(bwParams,R);
greyMatch=min(max(greyMatch,0),255);
redMatch=polyval(redParams,R);
redMatch=min(max(redMatch,0),255);

LB=model.dL('B',255);           % blue reference: full drive (on its plateau beyond the clip)
LR=model.dL('R',redMatch);      % red peak luminance, isoluminant with LB for this observer
Lgrey=model.dL('W',greyMatch);  % grey luminance isoluminant with LB for this observer

% BW grating: 0 to 2 x Lgrey, sinusoidal in LUMINANCE, so its mean
% luminance equals the matched grey, i.e. the colour grating's luminance
% for this observer (the x2 of Nasr's/LW's generators, applied in
% luminance rather than in drive).
if any(2*Lgrey(:) > model.dLmax.W)
    warning('makeStimuli: BW peak (2 x matched grey) exceeds the W maximum at %.1f%% of pixels; clipped there.', ...
        100*mean(2*Lgrey(:) > model.dLmax.W));
end

% OPTIONAL R + B ADDITIVITY CORRECTION (checkAdditivityRB.m)
% m(p) is the factor by which the observer had to scale a red + blue
% mixture with blue fraction p (predicted isoluminant if R and B add) to
% null its flicker against pure blue; m(0) = m(1) = 1 by definition. With
% the correction, the colour grating's luminance at blue fraction g is
% multiplied by m(g).
rbm=@(g) ones(size(g));
stim_params.rbCorrection=[];
if isfield(cal_cfg,'rbCorrection') && cal_cfg.rbCorrection
    rbFiles=dir([pathfile fs 'logfiles' fs 'RBadditivity_*.mat']);
    if isempty(rbFiles)
        error('makeStimuli: cal_cfg.rbCorrection is true but no RBadditivity_*.mat in %s. Run checkAdditivityRB first.', [pathfile fs 'logfiles']);
    end
    [~,newest]=max([rbFiles.datenum]);
    rb=load([pathfile fs 'logfiles' fs rbFiles(newest).name]); rb=rb.RBadditivity;
    [pp,order]=sort(rb.blueFractions(:)');
    rbm=@(g) interp1([0 pp 1],[1 rb.m(order) 1],g,'linear');
    stim_params.rbCorrection=struct('file',rbFiles(newest).name,'blueFractions',pp,'m',rb.m(order));
    fprintf('R+B additivity correction from %s: m = %s at blue fractions %s\n', rbFiles(newest).name, mat2str(rb.m(order),3), mat2str(pp,3));
end

% Record the model and luminance summary with the stimulus parameters
modelInfo=rmfield(model,intersect(fieldnames(model),{'dL','d','L'}));
stim_params.displayModel=modelInfo;
stim_params.LB=LB;
stim_params.Lgrey_range=[min(Lgrey(:)) max(Lgrey(:))];
stim_params.LR_range=[min(LR(:)) max(LR(:))];
stim_params.background=backgroundLuminance(name_subj,name_sess);   % background/rest level used by colourProject
save(stim_file, 'stim_params');

% GRATING
counter=1;
for t=1:length(thetaList)
    theta=thetaList(t);%grating orientation
    
    % output folder
    outFolderColour=[pathfile fs 'colour_grating_' sprintf('%d',theta) '_degrees'];
    if isdir(outFolderColour)==0
        mkdir(outFolderColour);
    end
    outFolderBW=[pathfile fs 'bw_grating_' sprintf('%d',theta) '_degrees'];
    if isdir(outFolderBW)==0
        mkdir(outFolderBW);
    end

    % orientation
    thetaRad=(theta/360)*2*pi;%convert theta (orientation) to radians
    Xt=Xm*cos(thetaRad)+Ym*sin(thetaRad);%rotation of the coordinate system
    Xp=Xt*spatialFreq*2*pi;%phase of single pixels      

    for step=1:nPhaseSteps

        % calculate single phase images
        phaseRad=phaseStep*step*2*pi;
        grating=sin(Xp+phaseRad);%make 2D sinewave
        grating=(grating-min(grating(:)))/(max(grating(:))-min(grating(:)));%normalise to [0,1]

        % achromatic: luminance 2*Lgrey*g -> drive
        BWgrating=model.d('W',2*Lgrey.*grating);
        
        % output
        outPicBW=[outFolderBW fs sprintf('%d',step) '.png'];
        imwrite(uint16((BWgrating/255)*65535),outPicBW,'PNG');
    
        % blue: luminance LB*g -> drive (peaks at blue's clip point, not 255)
        gBlue=grating;
        blueGrating=model.d('B',LB*gBlue.*rbm(gBlue));
        
        % apply phase step 
        phaseRad=(phaseStep*step+.5)*2*pi;
        grating=sin(Xp+phaseRad);%make 2D sinewave
        grating=(grating-min(grating(:)))/(max(grating(:))-min(grating(:)));%normalise to [0,1]
    
        % red (antiphase): luminance LR*(1-g) -> drive
        redGrating=model.d('R',LR.*grating.*rbm(gBlue));
    
        % define colour grating
        colourGrating=zeros(height,width,3);
        colourGrating(:,:,1)=redGrating;
        colourGrating(:,:,3)=blueGrating;

        % output
        outPicColour=[outFolderColour fs sprintf('%d',step) '.png'];
        imwrite(uint16((colourGrating/255)*65535),outPicColour,'PNG');
        
        % show loading progress in command window
        percentDone=100*counter/(nPhaseSteps*size(thetaList,2));
        counter=counter+1;
        if ~mod(percentDone,10)
           disp(['Loading: ' num2str(percentDone) '%']);
           drawnow('limitrate')
        end
        
    end
end
