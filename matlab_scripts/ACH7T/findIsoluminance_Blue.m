function findIsoluminance_Blue(name_subj,name_sess,name_oldsess) 

close all;
cfg_start;
fs=filesep;
% DIRECTORY
dir_base=cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end
% CHECK INPUTS
if ~exist('name_subj','var')  
    name_subj='TestSubj';
end

if ~exist('name_sess','var')  
    name_sess='TestSess';
end

% initial luminance values  
% For the first session (name_oldsess does not exist), start luminance values are set.
% For all following sessions, the isoluminance values from the prior session are taken.
if ~exist('name_oldsess','var') 
    startPoint=findIso_cfg.startPointBlue;
else
    load([dir_base fs name_subj fs 'colour' fs name_oldsess fs 'stimuli/logfiles/bwFitData' isoFileTag(findIso_cfg) '.mat']);
    startPoint=bwValues2Use;
    clear bwParams bwValues2Use; 
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
KbName('UnifyKeyNames');
escapeKey=KbName('ESCAPE');
DarkKey=KbName('1!');
LightKey=KbName('2@');
DoneKey=KbName('3#');
keys=struct('dark',DarkKey,'light',LightKey,'done',DoneKey,'escape',escapeKey);

%%
%==========================================================================
% end of user specified settings (do not edit below)
%==========================================================================

% LOGFILE
% apparently, Octave doesnt support the creation of nested directories
if isdir([dir_base fs name_subj])==0
    mkdir(dir_base,name_subj); 
end

if isdir([dir_base fs name_subj fs 'colour'])==0
    mkdir([dir_base fs name_subj],'colour');
end

if isdir([dir_base fs name_subj fs 'colour' fs name_sess])==0
   mkdir([dir_base fs name_subj fs 'colour'],name_sess);
   mkdir([dir_base fs name_subj fs 'colour' fs name_sess],'stimuli'); 
   mkdir([dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli'],'logfiles'); 
end
pathfile=[dir_base fs name_subj fs 'colour' fs name_sess fs 'stimuli' fs 'logfiles'];
% file-name suffix for a non-default flicker rate (see isoFileTag)
isoTag=isoFileTag(findIso_cfg);

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
% The paradigm consists of nCond1 different conditions (eccentricities),
% which are nReps times repeated. Each condition occurs equally often.
% Conditions are shuffled with the restriction that the same eccentricity
% is not analysed twice in direct succession.
nTrials=length(expPar);
expPar=expPar(randperm(nTrials),:);%shuffle

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
keyState=struct('key',0,'t0',0,'tLast',0,'needRelease',true);%the start key must be released before the first step
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
    wptr=PsychImaging('OpenWindow',screenid);   
    ListenChar(2);%suppress any keypresses to Octave command window
    HideCursor;
    [offwptr,screenRect]=Screen('OpenOffscreenWindow',wptr,0);%open offscreen window into which we draw the "index colour image" which defines the appearance of the "colour wheel"
    flipinterval=Screen('GetFlipInterval',wptr); 
    ASSUMEDREFRESHRATE=1/flipinterval%assumed refresh rate
    % check refresh rate (flicker frequency = refresh/(2*framesPerField))
    if abs(ASSUMEDREFRESHRATE-findIso_cfg.expectedHz)>findIso_cfg.toleranceHz
        error('Measured refresh rate is %.1f Hz but %d Hz is expected (flicker = refresh/(2*framesPerField)). Change the display mode or findIso_cfg.expectedHz.', ...
            ASSUMEDREFRESHRATE, findIso_cfg.expectedHz);
    end
    fprintf('Flicker: %.1f Hz (%d frame(s) per field)\n',ASSUMEDREFRESHRATE/(2*findIso_cfg.framesPerField),findIso_cfg.framesPerField);
    
    % start screen (wait for key press)
    Screen('FillRect',wptr,[0 0 0],screenRect);
    Screen('Flip',wptr);%perform initial flip to set display to well defined initial display with background colour
    exitFlag=0;
    while ~exitFlag
        [~,~,KeyCode]=KbCheck(key_cfg.device);
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
        % the start luminance startLum is taken in the first trial from
        % startPoint overlaid with a jitter value. Each eccentricity has its
        % own startPoint value. Following trials use the preceding
        % startLum value as startPoint.
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
        lumInd=startLum+1;%since array indices are in the range [1,256]
        
        % black background
        % clut start entry is 0 (clut animation, i.e.,
        % colour lookup table itself is changed)
        Screen('FillRect',offwptr,[0 0 0],[0 0 width height]);
        
        % ring
        if eccCond==1
            imSize=findIso_cfg.cond_px_bands(1)*height; %edited from .1 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
        elseif eccCond==2
            imSize=findIso_cfg.cond_px_bands(2)*height; %edited from .25 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
            
            imSize=findIso_cfg.cond_px_bands(1)*height; %edited from .1 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[0 0 0],[X1 Y1 X2 Y2]);
        elseif eccCond==3
            imSize=findIso_cfg.cond_px_bands(3)*height; %edited from .5 using spatfreq.m values
            X1=width/2-imSize;
            X2=width/2+imSize;
            Y1=height/2-imSize;
            Y2=height/2+imSize;
            Screen('FillOval',offwptr,[1 1 1],[X1 Y1 X2 Y2]);
            
            imSize=findIso_cfg.cond_px_bands(2)*height; %edited from .25 using spatfreq.m values
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
                temp(2,:)=[0 0 lumSpectrum(256)];
            else
                temp(2,:)=[lumSpectrum(lumInd) lumSpectrum(lumInd) lumSpectrum(lumInd)];
            end
            testM(c,:,:)=temp;
        end
        
        % draw images
        counter=0;
        doneFlag=0;
        while doneFlag==0
            counter=counter+1;
            if counter<=2
                % Draw offscreen window with stimulus index image to framebuffer.
                % Set filterMode == 0 to disable any kind of interpolation.
                % We want the pixels exactly defined in the offscreen window, so
                % CLUT palette animation works:
                Screen('DrawTexture', wptr, offwptr, [], [], [], 0);
            end
            InvGammaTable(3,:)=[0 lumSpectrum(256) 0];%refresh green fixation spot
            
            % response: one step per press; holding dark/light repeats
            % (key_cfg, flickerKeys.m). Listens to all keyboards.
            [keyAction,keyState]=flickerKeys(keyState,keys,key_cfg);
            if ~isempty(keyAction)
                if strcmp(keyAction,'escape')
                    escapeFlag=1;
                    break
                elseif strcmp(keyAction,'dark')%make darker
                    lumInd=lumInd-1;
                    allowDone=1;
                    if lumInd<1
                        lumInd=1;
                        InvGammaTable(3,:)=[lumSpectrum(256) 0 0];
                    end
                elseif strcmp(keyAction,'light')%make brighter
                    lumInd=lumInd+1;
                    allowDone=1;
                    if lumInd>256
                        lumInd=256;
                        InvGammaTable(3,:)=[lumSpectrum(256) 0 0];
                    end
                elseif strcmp(keyAction,'done')%done
                    if allowDone==1
                        doneFlag=1;
                        allowDone=0;
                    end
                end

                testM=zeros(2,256,3); 
                for c=1:2
                    temp=InvGammaTable;
                    if c==1
                        temp(2,:)=[0 0 lumSpectrum(256)];
                    else
                         temp(2,:)=[lumSpectrum(lumInd) lumSpectrum(lumInd) lumSpectrum(lumInd)];
                    end
                    testM(c,:,:)=temp;                        
                end 
            end
            newCLUT=squeeze(testM(mod(floor(counter/findIso_cfg.framesPerField),2)+1,:,:));
            Screen('LoadNormalizedGammaTable',wptr,newCLUT,2);%update clut to be applied at the next flip
            flipTsum=flipTsum+toc(flipT);
            flipTCount=flipTCount+1;
            flipT=tic;
            
            Screen('Flip',wptr,[],2);%2=on next screen refresh, and don't clear the frame buffer
         end
         expPar(trial,3)=lumInd-1;%record selected isoluminance (minus one since index range [1,256] but luminance range [0,255])
         startPointMem(eccCond)=lumInd-1;%remember for next trial
    end
    
    % save the settings first, so nothing is lost at the end screen
    save([pathfile fs ['bwIsoLumData' isoTag '.mat']], 'expPar','-mat');
    if escapeFlag, endState='stopped early (Esc)'; else, endState='completed'; end

    % end screen (black, as the task surround), wait for Esc
    waitAtEnd(wptr,0,sprintf('Blue isoluminance %s and saved:\n  %s',endState,[pathfile fs ['bwIsoLumData' isoTag '.mat']]));

    RestoreCluts;%restore pre-session gammatable into graphics card
    ListenChar(0);
    Screen('CloseAll');
    ShowCursor;
    AvgRefreshT=flipTsum/flipTCount
    AvgRate=1/AvgRefreshT%note that the first tic is quite long and therefore deviation from 60Hz is expected
    % fit across eccentricities (saves the fit file and shows figures)
    analysis_BlueIsoLum(pathfile);

catch err
    RestoreCluts;
    ListenChar(0);
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);
end