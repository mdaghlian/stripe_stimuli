% ORIGINAL PARAMETERS: (in LW code)
% -> Screen:
% width=1920
% height=1080
% screenid=1; 
% -> All stim
% fixSize = 2; % fixation dot size

% -> findIso
% Per ecc band; what is the starting *luminance* of the channels being adjusted
% In blue -> applies to grey; in red -> applies to red
% startPointBlue = [60 70 80]; % per ecc, initial start point (for greys)
% startPointRed = [180 200 220];
% nReps = 4;
% JitterSize = 10;
% nCond1 = 3; % eccentricity bands
% -> circles
% .1350*height; .3527*height; .6603*height (in notes is says edited from .1, .25, .5)...
% -> Analysis 
% eccList=[19.2 67.2 144];%middle of the annuli - new mean since we halve the generated images (512x384)
% fitX=linspace(log(12.2),log(244.7),100);%line for (512x384)


% MAKE STIMULI
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
thetaList=[0 45 90 135];


% COLOUR PROJECT
width=1920;% screen size in px
height=1080;
nBlocks=8;%has to be an integral multiple of nConditions
nConditions=8;
nRuns=10;
BlockTime=30;
DelayTime=15;
save_screen=0; % set to 1 for saving screenshots
nSteps=30;
orientationList=[0 45 90 135];
colourCondLabels={'bw','colour'};
fixSize=2;
X1=width/2-fixSize;
X2=width/2+fixSize;
Y1=height/2-fixSize;
Y2=height/2+fixSize;

% FIXATION COLOUR DEFINITION
FixationImage_White=255*ones(3,3,3);
FixationImage_Green1=255*ones(3,3,3); 
FixationImage_Green1(:,:,[1 3])=0;
FixationImage_Green2=180*ones(3,3,3); 
FixationImage_Green2(:,:,[1 3])=0;
Image=uint8(128*ones(height,width));%grey background

    
% experiment 
cnt=1;
FixationColour=0; 
FixIndex=3;  
FixCnt=0;
FixRand=0;
FadingTime=1;
FadeNeg=0;
FadePos=0;
OnsetPos=0;
alphaImg=0;
KeyIsDown=0;


% GTBLENGTH=256;
% lumSpectrum=linspace(0,1,GTBLENGTH);
% InvGammaTable=repmat(lumSpectrum',1,3);

