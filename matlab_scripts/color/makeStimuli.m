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
% warning ('off','Octave:language-extension');%suppress annoying warnings because of Matlab incompatibilities and missing semicolons
% warning('off','Octave:missing-semicolon');
% warning ('off','Octave:mixed-string-concat'); 
dir_base=cfg.dir_base;
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
lambda=stim_cfg.lambda;%in px
spatialFreq=1/lambda;

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
% Generate a filename (example uses a subject ID if available in cfg)
if isfield(cfg, 'subjectID')
    filename = sprintf('stim_meta_%s_%s.mat', cfg.subjectID, datestr(now, 'yyyy-mm-dd_HHMM'));
else
    filename = sprintf('stim_metadata_%s.mat', datestr(now, 'yyyy-mm-dd_HHMM'));
end
stim_params.note = "NOTE based on IMAGE FRAC";
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
R=log(R);
R(isinf(R))=0;%to discard log(0)

R = R * (1/cfg.image_frac); % Rescale because the fitting is done on full screen 

% CALCULATE WEIGHTINGS
fxn1=polyval(bwParams,R); 
fxn1(fxn1>255)=255;
fxn1(fxn1<0)=0;

fxn2=polyval(redParams,R);
fxn2(fxn2>255)=255;
fxn2(fxn2<0)=0;

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

        % apply weighting (achromatic)
        BWgrating=grating.*fxn1;
        
        % output
        outPicBW=[outFolderBW fs sprintf('%d',step) '.png'];
        imwrite(uint16((BWgrating/255)*65535),outPicBW,'PNG');
    
        % apply weighting (blue)    
        blueGrating=grating*255;      
        
        % apply phase step 
        phaseRad=(phaseStep*step+.5)*2*pi;
        grating=sin(Xp+phaseRad);%make 2D sinewave
        grating=(grating-min(grating(:)))/(max(grating(:))-min(grating(:)));%normalise to [0,1]
    
        % apply weighting (red)
        redGrating=grating.*fxn2;
    
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