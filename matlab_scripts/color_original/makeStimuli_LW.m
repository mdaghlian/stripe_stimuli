function makeStimuli(name_subj,name_sess)

close all
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
dir_base='/Users/ronim/CVL Dropbox/Roni Maimon/7TStudy/MRIStimuli';
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
% to reduce the calculation for generating and loading all image files,
% we halved the size of the images (1920/2x1080/2)
width=960;
height=540;
nPhaseSteps=30;
phaseStep=1/nPhaseSteps;
lambda=107;%in px
spatialFreq=1/lambda;
X=1:width;%X is a vector from 1 to width
Y=1:height;  
[Xm,Ym]=meshgrid(X,Y);%2D matrices
R=sqrt(((Xm-width/2).^2)+((Ym-height/2).^2));
R=log(R);
R(isinf(R))=0;%to discard log(0)

% CALCULATE WEIGHTINGS
fxn1=polyval(bwParams,R).*2;
fxn1(fxn1>255)=255;
fxn1(fxn1<0)=0;

fxn2=polyval(redParams,R);
fxn2(fxn2>255)=255;
fxn2(fxn2<0)=0;

% GRATING
thetaList=[0 45 90 135];
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