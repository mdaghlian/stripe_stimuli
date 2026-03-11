function findIsoluminance_Red(name_subj,name_sess,name_oldsess) 

close all
cfg_start;
fs=filesep;

% DIRECTORY
warning('off');%suppress annoying warnings because of embedding psychtoolbox folders, Matlab incompatibilities and missing semicolons
addpath(genpath(cfg.PTB_dir));
warning('on');
% warning ('off','Octave:language-extension');
% warning('off','Octave:missing-semicolon');
% warning ('off','Octave:mixed-string-concat'); 
dir_base=cfg.dir_base;
% CHECK INPUTS
if ~exist('name_subj','var')  
    name_subj='TestSubj';
end

if ~exist('name_sess','var')  
    name_sess='TestSess';
end

if ~exist('name_oldsess','var')%set initial luminance values
    startPoint=findIso_cfg.startPointRed;
else
    load([dir_base fs name_subj fs 'colour' fs name_oldsess fs 'stimuli/logfiles/redFitData.mat']);
    startPoint=redValues2Use;
    clear redParams redValues2Use; 
end

% ADJUSTABLE PARAMETERS
screenid=cfg.screenid;%choose the screen for display
width=cfg.width;% screen size in px
height=cfg.height;
nReps=findIso_cfg.nReps; 
JitterSize=findIso_cfg.JitterSize;
nCond1=findIso_cfg.nCond1;%eccentricity
fixSize=findIso_cfg.fixSize;%size of fixation spot


% INITIALISE KEYS
escapeKey=KbName('ESCAPE');
%DarkKey=KbName('LEFT');
%LightKey=KbName('RIGHT');
%DoneKey=KbName('SPACE');
%escapeKey=KbName('4');%should not be activated
DarkKey=KbName('1!');
LightKey=KbName('2@');
DoneKey=KbName('3#');

%==========================================================================
% end of user specified settings (do not edit below)
%==========================================================================

% LOGFILE
pathfile=[dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles'];

% GET VALUES FROM BLUE ISOLUMINANCE
file2Check=[pathfile fs 'bwFitData.mat'];
if ~exist(file2Check,'file')
    error('No such participant or session. Check inputs or make sure findIsoluminance_Blue has been run for this participant!');
else
    load(file2Check);
end
clear file2Check bwParams

% EXPERIMENTAL PARADIGM
expPar=[];
trialCount=zeros(1,nCond1);
startPointMem=zeros(1,nCond1);

for c1=1:nCond1
    for rep=1:nReps
        expPar=[expPar; c1 0 0];
    end
end

% PSEUDORANDOMISATION
nTrials=length(expPar);
expPar=expPar(randperm(nTrials),:);

redo=0;
i=0;
c1Old=0;
while i<nTrials
    i=i+1;
    c1=expPar(i,1);
    if c1==c1Old
        redo=1;
        break
    end
    c1Old=c1;   
end

while redo==1
    expPar=expPar(randperm(nTrials),:);%reshuffle
    redo=0;
    i=0;
    c1Old=0;
    while i<nTrials
        i=i+1;
        c1=expPar(i,1);
        if c1==c1Old
            redo=1;
            break
        end
        c1Old=c1;   
    end
end

% FIXED PARAMETERS
GTBLENGTH=256;
lumSpectrum=linspace(0,1,GTBLENGTH);
InvGammaTable=repmat(lumSpectrum',1,3);
%GAMMA=1.8;
%InvGammaTable=repmat((linspace(0,1,GTBLENGTH)'.^(1/GAMMA)), 1,3);%normalized entries, 0 to 1
flipT=tic;
flipTsum=0;
flipTCount=0;
KeyIsDown=0;
keyTime=tic;
trial=0;
escapeFlag=0;
allowDone=0;

% OPEN PSYCHTOOLBOX WINDOW
try
    % configuration
    BackupCluts(screenid);%backup current graphics card gammatable (so we can restore it at the end of the session)
    PsychImaging('PrepareConfiguration');%prepare setup of imaging pipeline for onscreen window
    PsychImaging('AddTask','AllViews','EnableCLUTMapping');%enable CLUT animation by CLUT mapping, using a 8bpc, 256 slot clut   
    Screen('LoadNormalizedGammaTable',screenid,InvGammaTable);%load InvGammaTable immediately into graphics card for gamma correction
    
    % open screen window with imaging pipeline setup
    Screen('Preference', 'SkipSyncTests', 1); %need to remove
    wptr=PsychImaging('OpenWindow',screenid);
    ListenChar(2)%suppress any keypresses to Octave command window
    HideCursor;   
    [offwptr,screenRect]=Screen('OpenOffscreenWindow',wptr,0);%open offscreen window into which we draw the "index colour image" which defines the appearance of the "colour wheel"
    flipinterval=Screen('GetFlipInterval',wptr); 
    ASSUMEDREFRESHRATE=1/flipinterval%assumed refresh rate
    
    % start screen (wait for key press)
    Screen('FillRect',wptr,[0 0 0],screenRect);
    Screen('Flip',wptr);%perform initial flip to set display to well defined initial display with background colour
    exitFlag=0;
    while ~exitFlag
        [~,~,KeyCode]=KbCheck; 
        if KeyCode(DarkKey) 
           exitFlag=1;
        end
    end    
    
    % trials
    while trial<nTrials && escapeFlag==0
        trial=trial+1;
        eccCond=expPar(trial,1);
        trialCount(eccCond)=trialCount(eccCond)+1;
        
        % adjustment of start luminance in the range [0,255]  
        if trialCount(eccCond)==1
            chooseAgain=0;
            startLum=startPoint(eccCond)+(randi(JitterSize))-JitterSize/2;
            if startLum<0 || startLum>255
                chooseAgain=1;
            end
            while chooseAgain==1
                chooseAgain=0;
                startLum=startPoint(eccCond)+(randi(JitterSize))-JitterSize/2;
                if startLum<0 || startLum>255
                    chooseAgain=1;
                end
            end
        else
            chooseAgain=0;
            startLum=startPointMem(eccCond)+(randi(JitterSize))-JitterSize/2;
            if startLum<0 || startLum>255
                chooseAgain=1;
            end
            while chooseAgain==1
                chooseAgain=0;
                startLum=startPointMem(eccCond)+(randi(JitterSize))-JitterSize/2;
                if startLum<0 || startLum>255
                    chooseAgain=1;
                end
            end
        end
        expPar(trial,2)=startLum;
        statLumInd=bwValues2Use(eccCond)+1;%grey luminance from blue isoluminance estimates
        lumInd=startLum+1;%since array indices are in the range [1,256]
        
        % black background
        Screen('FillRect',offwptr,[0 0 0],[0 0 width height]);
        
        % ring
        if eccCond==1
            imSize=.1350*height; %edited from .1 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
        elseif eccCond==2
            imSize=.3257*height; %edited from .25 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
            
            imSize=.1350*height; %edited from .1 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[0 0 0],[X1 Y1 X2 Y2]);
        elseif eccCond==3
            imSize=.6603*height; %edited from .5 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
            
            imSize=.3257*height; %edited from .25 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[0 0 0],[X1 Y1 X2 Y2]);
        end
        X1=width/2-fixSize;
        X2=width/2+fixSize;
        Y1=height/2-fixSize;
        Y2=height/2+fixSize;
        Screen('FillOval',offwptr,[2 2 2],[X1 Y1 X2 Y2]);

        % colour assignment
        testM=zeros(2,256,3);
        for c=1:2
             temp=InvGammaTable;
             temp(3,:)=[0 lumSpectrum(256) 0];
             if c==1
                 temp(2,:)=[lumSpectrum(lumInd) 0 0];
             else
                 temp(2,:)=[lumSpectrum(statLumInd) lumSpectrum(statLumInd) lumSpectrum(statLumInd)];
            end
            testM(c,:,:)=temp;
        end
        
        % draw images
        counter=0;
        doneFlag=0;
        while doneFlag==0
            counter=counter+1;
            if counter <= 2
				% Draw offscreen window with stimulus index image to framebuffer.
				% Set filterMode == 0 to disable any kind of interpolation.
				% We want the pixels exactly defined in the offscreen window, so
				% CLUT palette animation works:
				Screen('DrawTexture', wptr, offwptr, [], [], [], 0);
            end
            InvGammaTable(3,:)=[0 lumSpectrum(256) 0];%refresh green fixation spot
            
            % response
            [KeyIsDown,~,KeyCode]=KbCheck;
            if KeyIsDown==1 && toc(keyTime)>.1
                KeyIsDown=0;
                if KeyCode(escapeKey)%escape
                    escapeFlag=1;
                    break
                elseif KeyCode(DarkKey)%make darker 
                    keyTime=tic;
                    lumInd=lumInd-1;
                    allowDone=1;
                    if lumInd<1
						lumInd=1;
                        InvGammaTable(3,:)=[lumSpectrum(256) 0 0];
                    end
                elseif KeyCode(LightKey)%make brighter
                    keyTime=tic;
                    lumInd=lumInd+1;
                    allowDone=1;
                    if lumInd>256
                        lumInd=256;
                        InvGammaTable(3,:)=[lumSpectrum(256) 0 0];
                    end
                elseif KeyCode(DoneKey)%done
                    if allowDone==1
                        keyTime=tic;
                        doneFlag=1;
                        allowDone=0;
                    end
                end

                testM=zeros(2,256,3);
                for c=1:2
                    temp=InvGammaTable;
                    if c==1
                        temp(2,:)=[lumSpectrum(lumInd) 0 0];
                    else
                        temp(2,:)=[lumSpectrum(statLumInd) lumSpectrum(statLumInd) lumSpectrum(statLumInd)];
                    end
                    testM(c,:,:)=temp;
                end
            end
            newCLUT=squeeze(testM(mod(counter,2)+1,:,:));
            Screen('LoadNormalizedGammaTable',wptr,newCLUT,2);
            flipTsum=flipTsum+toc(flipT);
            flipTCount=flipTCount+1;
            flipT=tic;
            
            Screen('Flip',wptr,[],2);%2=on next screen refresh, and don't clear the frame buffer
        end
        expPar(trial,3)=lumInd-1;%record selected isoluminance (minus one since index range [1,256] but luminance range [0,255])
        startPointMem(eccCond)=lumInd-1;%remember for next trial
    end
    
    % end screen
    Screen('FillRect', wptr,[0 0 0],screenRect);
    Screen('Flip',wptr);
    exitFlag=0;
    while ~exitFlag
        [~,~,KeyCode]=KbCheck; 
        if KeyCode(escapeKey)
            exitFlag=1;
        end
    end
    
    % savings
    RestoreCluts;%restore pre-session gammatable into graphics card
    ListenChar(0);
    Screen('CloseAll');
    ShowCursor;
    AvgRefreshT=flipTsum/flipTCount
    AvgRate=1/AvgRefreshT%note that the first tic is quite long and therefore deviation from 60Hz is expected
    save([pathfile fs 'redIsoLumData.mat'], 'expPar','-mat');
    analysis_RedIsoLum(pathfile)

catch err
    RestoreCluts;
    ListenChar(0);
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end