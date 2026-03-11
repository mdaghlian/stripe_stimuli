function colourProjectSeq(name_subj,name_sess,name_run)

close all;
cfg_start;
fs=filesep;

% Set default values for subject, session, and run if not provided
if ~exist('name_subj','var')  
    name_subj='TestSubj';
end

if ~exist('name_sess','var')  
    name_sess='TestSess';
end

if ~exist('name_run','var')  
    name_run=1;
end

% DIRECTORY
warning('off');
addpath(genpath(cfg.PTB_dir));
warning('on');

dir_base=cfg.dir_base;

% ADJUSTABLE PARAMETERS
screenid=cfg.screenid;   
width=cfg.width;
height=cfg.height;

BlockTime=stim_cfg.BlockTime;
DelayTime=stim_cfg.DelayTime;
save_screen=stim_cfg.save_screen;
nSteps=stim_cfg.nSteps;
orientationList=stim_cfg.thetaList;
colourCondLabels=stim_cfg.colourCondLabels;
fixSize=stim_cfg.fixSize;

% *** 
condition_list = stim_cfg.Bcondition_list; 
nBlocks = length(condition_list);
nTypes = length(colourCondLabels);
% *** 


% INITIALISE KEYS
escapeKey=KbName('ESCAPE');
DetectKey=KbName('1!');
TriggerSign=KbName('5%');

%==========================================================================
% end of user specified settings (do not edit below)
%==========================================================================

% LOGFILE
pathfile=[dir_base fs name_subj fs 'colour' fs name_sess];
if isdir([pathfile fs 'Run_' sprintf('%d',name_run)])==0
    status=mkdir([pathfile fs 'Run_' sprintf('%d',name_run)]);
    if ~status
        error('No such participant or session. Check inputs!');
    else
        mkdir([pathfile fs 'Run_' sprintf('%d',name_run) fs 'logfiles']);    
    end
end

FileName=[pathfile fs 'Run_' sprintf('%d',name_run) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run) '_colour'];

% EXPERIMENTAL PARADIGM
nOrientations = length(orientationList);
stim_list = condition_list(~strcmp(condition_list, 'rest'));
nStim = length(stim_list);
nOriStim = nStim * stim_cfg.Bori_per_stim;
nOriStimDir = nStim * stim_cfg.Bori_per_stim * stim_cfg.Bdirection_per_ori;

stim_cnt = 1;
ori_cnt = 1;
dir_cnt = 1;
% --- Inputs you already have ---
% condition_list (cellstr), orientationList (numeric)
% stim_cfg.Bori_per_stim, stim_cfg.Bdirection_per_ori

% --- Separate stim conditions from rest ---
isRest = strcmpi(condition_list, 'rest');
stimConds = find(~isRest);         % indices into condition_list for active stims
restConds = find(isRest);

nStimConds = numel(stimConds);
nOr = numel(orientationList);
nOriPerStim = stim_cfg.Bori_per_stim;
nDirPerOri  = stim_cfg.Bdirection_per_ori;

% Total number of (stim,ori,dir) trials (excluding rest blocks)
nOriStimDir = nStimConds * nOriPerStim * nDirPerOri;

stim_seq = zeros(1, nOriStimDir);
ori_seq  = zeros(1, nOriStimDir);
dir_seq  = zeros(1, nOriStimDir);

% -----------------------------
% 1) Build globally counterbalanced orientation pool
% -----------------------------
nOriDrawsTotal = nStimConds * nOriPerStim;

% Repeat orientations enough times to cover all draws
nRepeats = ceil(nOriDrawsTotal / nOr);
oriPool = repmat(orientationList(:).', 1, nRepeats);

% Trim to exact length needed
oriPool = oriPool(1:nOriDrawsTotal);

% Shuffle once -> global balance still holds
oriPool = oriPool(randperm(numel(oriPool)));

% -----------------------------
% 2) Build direction list for each orientation
% -----------------------------
% If 2 directions, use +1/-1 alternating (nice counterbalance)
if nDirPerOri == 2
    dirPerOri = [ +1, -1 ];
% else ... to implement
%     % Generic: 1..nDirPerOri (you can map these to whatever you use later)
%     dirPerOri = 1:nDirPerOri;
end

% -----------------------------
% 3) Fill sequences
% -----------------------------
iT = 1;
poolPtr = 1;

for k = 1:nStimConds
    iC = stimConds(k);  % condition_list index for this stim condition

    % Take this stim's orientations from the pool
    thisOri = oriPool(poolPtr : poolPtr + nOriPerStim - 1);
    poolPtr = poolPtr + nOriPerStim;

    for iO = 1:nOriPerStim
        for iD = 1:nDirPerOri
            stim_seq(iT) = iC;              % store condition index
            ori_seq(iT)  = thisOri(iO);     % store actual degrees
            dir_seq(iT)  = dirPerOri(iD);   % store direction code
            iT = iT + 1;
        end
    end
end

% **************************************************
% UPDATE THE REST FROM HERE
% **************************************************
% FIXED PARAMETERS
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

% OPEN PSYCHTOOLBOX WINDOW
try
    % configuration
     
    oldVisualDebugLevel=Screen('Preference','VisualDebugLevel',3);%control visual alerts
    oldSuppressAllWarnings=Screen('Preference','SuppressAllWarnings',1);%suppresses the printout of warnings
    wptr=Screen('OpenWindow',screenid);
    HideCursor;
    Screen('BlendFunction',wptr,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); 
        
    % load stimuli into memory + build lookup table
    idx = struct;
    nOr = length(orientationList);
    for c = 1:length(colourCondLabels)
        cName = colourCondLabels{c};
        idx.(cName) = struct;
        for or = 1:nOr
            oName = num2str(orientationList(or));            
            % your original linear index (same as before)
            index = ((c-1)*nOr) + or;
            % store lookup (only needs doing once per c/or)
            idx.(cName).(oName) = index;
            
            % load all steps for this condition/orientation
            for s = 1:nSteps
                imName = [pathfile fs 'stimuli' fs colourCondLabels{c} ...
                    '_grating_' sprintf('%d',oriVal) '_degrees' fs sprintf('%d',s) '.png'];
                
                image = double(imread(imName)) / 65535;
                gratingTexture(index, s) = Screen('MakeTexture', wptr, image, [], [], 1);
            end
        end
    end
    % load background and fixation spot
    textureIndex(1)=Screen('MakeTexture',wptr,Image);
    textureIndex(2)=Screen('MakeTexture',wptr,FixationImage_Green1);
    textureIndex(3)=Screen('MakeTexture',wptr,FixationImage_Green2);
    textureIndex(4)=Screen('MakeTexture',wptr,FixationImage_White);
    
    % flip start screen before trigger (white fixation spot)
    Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
    Screen('DrawTexture',wptr,textureIndex(4),[],[X1 Y1 X2 Y2]);  
    Screen('Flip',wptr);
    
    % wait for trigger command
    [~,~,KeyCode]=KbCheck; 
    while ~KeyCode(TriggerSign)
%         display(find(KeyCode))
%         display(TriggerSign)
        [~,~,KeyCode]=KbCheck;
    end
    
    % start time measurement (in seconds)
    tic;
    
    % flip start screen after trigger (green fixation spot)
    Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
    Screen('DrawTexture',wptr,textureIndex(2),[],[X1 Y1 X2 Y2]);  
    Screen('Flip',wptr);
    
    % first time query
    StartTime=toc;
    LastResponseTime=toc;
    LastKeyCheck=toc;
    
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
    rest_onset=[];
    bw_onset=[];
    colour_onset=[];
    LogData=[];    
    FixationData=[];
    BlockSeq=[BlockSeq zeros(1,FadingTime)];%append zeros to fade out at the end of the run even if DelayTime is set to 0.
    BlockSeqDir=[BlockSeqDir zeros(1,FadingTime)];
    TriggerTime=[];
    img_count=0;
    while toc-StartTime<length(BlockSeq)-FadingTime%because of the appended zeros, we subtract the FadingTime here                                 
        if (BlockSeq(floor(toc-StartTime+1))==0) 
            Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
            Screen('DrawTexture',wptr,textureIndex(FixIndex),[],[X1 Y1 X2 Y2]);
            if OnsetPos==0
                OnsetPos=1;
                rest_onset=[rest_onset toc-StartTime];
            end
        else            
            OnsetPos=0;            
            if (mod(BlockSeq(floor(toc-StartTime+1)),2)==1 && mod(BlockSeq(floor(toc-StartTime+1+FadingTime)),2)==0)
                if FadeNeg==0
                    fadeStart=toc-StartTime;
                    FadeNeg=1;
                    FadePos=0;
                end
                alphaImg=1-((toc-StartTime)-fadeStart);
                if alphaImg<0
                    alphaImg=0;
                end         
            else 
                if FadePos==0
                    if BlockSeq(floor(toc-StartTime+1))<=8%save onset times
                        bw_onset=[bw_onset toc-StartTime];
                    else
                        colour_onset=[colour_onset toc-StartTime];
                    end
                    fadeStart=toc-StartTime;
                    FadeNeg=0;
                    FadePos=1;
                end 
                alphaImg=((toc-StartTime)-fadeStart);
                if alphaImg>1
                   alphaImg=1;
                end
            end
            imgIndex=ceil(BlockSeq(floor(toc-StartTime+1))/2);
            if BlockSeqDir(floor(toc-StartTime+1))>0   
                cnt=cnt-1;
                if cnt<1
                    cnt=nSteps;
                end
            else
                cnt=cnt+1;
                if cnt>nSteps
                    cnt=1;
                end
            end
            Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);%set underlying grey image as target for fading
            Screen('DrawTexture',wptr,gratingTexture(imgIndex,cnt),[],[0 0 width height],[],[],alphaImg);
            Screen('DrawTexture',wptr,textureIndex(FixIndex),[],[X1 Y1 X2 Y2]);
        end
        tempLog=[toc-StartTime BlockSeq(floor(toc-StartTime)+1) cnt alphaImg];
        LogData=cat(1,LogData,tempLog);
        Screen('Flip',wptr);
        
        % check key presses
        if toc-LastKeyCheck>0.2
            LastKeyCheck=toc;
            [KeyIsDown,~,KeyCode]=KbCheck;
            if KeyIsDown==1
                KeyIsDown=0;
                if KeyCode(escapeKey)
                    break
                elseif (KeyCode(DetectKey) && toc-LastResponseTime>0.3)
                    FixationData=cat(1,FixationData,[3 toc-StartTime]);
                    LastResponseTime=toc;
                elseif KeyCode(TriggerSign)
                    TriggerTime=[TriggerTime toc-StartTime];
                end
            end
        end
        
        % randomise colour of fixation spot
        % colour is changed each 240-600 frames, i.e., between 4-10 seconds at a frame rate of 60 Hz
        if FixCnt == FixRand 
            FixCnt=0;
            FixRand=randi(361)+239;
            if FixationColour==1
                FixationColour=0;
                FixIndex=2;
                FixationData=cat(1,FixationData,[2 toc-StartTime]);
            else
                FixationColour=1;
                FixIndex=3;
                FixationData=cat(1,FixationData,[1 toc-StartTime]);
            end
        end
        FixCnt=FixCnt+1;
        
        % save screen shots
        if save_screen ~=0
            % save screen into subfolder
            if isdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']) == 0
                mkdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']);
            end
                
            % get stimulus image into array
            imageArray = Screen('GetImage', wptr, [0 0 width height]);
                
            % write screen shot to image
            imwrite(imageArray, [pathfile fs 'Run_' sprintf('%d', name_run) fs 'img' fs 'img_' num2str(img_count) '.png']);
                
            img_count = img_count + 1;
        end
    end
    
    % end screen
    Screen('FillRect',wptr,[0 0 0],[0 0 width height]);
    % if name_run~=nRuns
    %     Screen('TextSize',wptr,70);
    %     DrawFormattedText(wptr,'Please close your eyes','center','center',255);    
    % else
    %     Screen('TextSize',wptr,70);
    %     DrawFormattedText(wptr,'Thankyou for participating!','center','center',255);
    % end
    Screen('Flip',wptr);
    exitFlag=0;
    while ~exitFlag
        [~,~,KeyCode]=KbCheck; 
        if KeyCode(escapeKey)
            exitFlag=1;
        end
    end
     
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',oldVisualDebugLevel);
    Screen('Preference','SuppressAllWarnings',oldSuppressAllWarnings);
    
    % savings
    names=cell(1,3);
    names{1}='rest';
    names{2}='bw';
    names{3}='colour';
    onsets=cell(1,3);
    onsets{1}=rest_onset;
    onsets{2}=bw_onset;
    onsets{3}=colour_onset;
    durations=cell(1,3);
    durations{1}=DelayTime;
    durations{2}=BlockTime;
    durations{3}=BlockTime;

    save([FileName '_Cond.mat'],'names','onsets','durations','-mat');
    save([FileName '.mat'],'FixationData','LogData','pseudorandomisation','TriggerTime','-mat');
    analysis_Stability(FileName);
    analysis_Fixation(FileName);
    
catch err
    Screen('CloseAll');
    ShowCursor;
    rethrow(err);  
end
