function colourProject(name_subj,name_sess,name_run)

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
% Suppress warnings from PsychToolbox path embedding and Matlab incompatibilities
warning('off');
addpath(genpath(cfg.PTB_dir));
warning('on');

dir_base=cfg.dir_base;

% ADJUSTABLE PARAMETERS
screenid=cfg.screenid;   
width=cfg.width;        % screen width in pixels
height=cfg.height;      % screen height in pixels
nBlocks=stim_cfg.nBlocks;           % total number of blocks (must be an integral multiple of nConditions)
nConditions=stim_cfg.nConditions;   % number of experimental conditions
nRuns=stim_cfg.nRuns;
BlockTime=stim_cfg.BlockTime;
DelayTime=stim_cfg.DelayTime;
save_screen=stim_cfg.save_screen;   % set to 1 to save screenshots

nSteps=stim_cfg.nSteps;
orientationList=stim_cfg.thetaList;
colourCondLabels=stim_cfg.colourCondLabels;
fixSize=stim_cfg.fixSize;

% INITIALISE KEYS
escapeKey=KbName('ESCAPE');
DetectKey=KbName('1!');
TriggerSign=KbName('5%');

%==========================================================================
% end of user specified settings (do not edit below)
%==========================================================================

% LOGFILE
% Build the path for this subject/session/run and create directories if needed
pathfile=[dir_base fs name_subj fs 'colour' fs name_sess];
if isdir([pathfile fs 'Run_' sprintf('%d',name_run)])==0
    status=mkdir([pathfile fs 'Run_' sprintf('%d',name_run)]);
    if ~status
        error('No such participant or session. Check inputs!');
    else
        mkdir([pathfile fs 'Run_' sprintf('%d',name_run) fs 'logfiles']);    
    end
end

% Define logfile paths for the current and previous run
FileName=[pathfile fs 'Run_' sprintf('%d',name_run) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run) '_colour'];
FileName_old=[pathfile fs 'Run_' sprintf('%d',name_run-1) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run-1) '_colour'];

% EXPERIMENTAL PARADIGM
if name_run == 1
    % --- First run: generate a fresh pseudorandom block sequence ---
    redo=1;
    while redo
        redo=0;

        % Build a sequence containing each condition index once per repetition cycle,
        % then shuffle the full list randomly
        temp=[];
        for i=1:nBlocks/nConditions
            temp=[temp 1:nConditions];
        end
        temp=temp(randperm(length(temp)));

        % Reject the sequence if any two consecutive blocks are the same condition
        for i=1:length(temp)-1
            if temp(i)==temp(i+1)
               redo=1;
               disp('2');
               break
            end
        end

        % Reject the sequence if three consecutive blocks all belong to the same
        % half of the conditions (i.e. either all colour or all black-and-white),
        % to prevent long runs of one stimulus type
        for i=1:length(temp)-2    
            if (temp(i)<=nConditions/2 && temp(i+1)<=nConditions/2 && temp(i+2)<=nConditions/2)
                redo=1;
                disp('3');
                break
            elseif (temp(i)>nConditions/2 && temp(i+1)>nConditions/2 && temp(i+2)>nConditions/2)
                redo=1;
                disp('4');
                break
            end
        end
    end

    % Scale condition indices (multiply by 2 to match the full block ID scheme)
    Sequence=2*temp;
    
    % Record whether each block is colour (1) or black-and-white (0),
    % based on whether the condition index is in the upper or lower half
    pseudorandomisation = temp;
    pseudorandomisation(pseudorandomisation > nBlocks/2) = 10;  % mark colour blocks
    pseudorandomisation(pseudorandomisation ~= 10) = 0;          % zero out non-colour
    pseudorandomisation(pseudorandomisation ~= 0) = 1;           % set colour blocks to 1

else
    % --- Subsequent runs: load the colour/BW pattern from the previous run
    %     and generate a new sequence that preserves the same pattern ---
    load([FileName_old '.mat']);
    clear FixationData LogData
    
    redo=1;
    while redo
        redo=0;

        % Build and shuffle a new candidate sequence, as above
        temp=[];
        for i=1:nBlocks/nConditions
            temp=[temp 1:nConditions];
        end
        temp=temp(randperm(length(temp)));

        % Reject if any two consecutive blocks share the same condition
        for i=1:length(temp)-1
            if temp(i)==temp(i+1)
               redo=1;
               break
            end
        end

        % Reject if three consecutive blocks are all from the same stimulus half
        for i=1:length(temp)-2    
            if (temp(i)<=nConditions/2 && temp(i+1)<=nConditions/2 && temp(i+2)<=nConditions/2)
                redo=1;
                break
            elseif (temp(i)>nConditions/2 && temp(i+1)>nConditions/2 && temp(i+2)>nConditions/2)
                redo=1;
                break
            end
        end
        
        % Convert candidate sequence to colour/BW binary pattern
        temp_check = temp;
        temp_check(temp_check > nBlocks/2) = 10;
        temp_check(temp_check ~= 10) = 0;
        temp_check(temp_check ~= 0) = 1;

        % Reject if the colour/BW pattern differs from the previous run's pattern,
        % ensuring consistent counterbalancing across runs
        if sum(abs(temp_check-pseudorandomisation)) > 0
            redo=1;
        else
            pseudorandomisation=temp_check;
        end
        
    end
    Sequence=2*temp;
end
disp('sequence')
disp(Sequence)
disp('heloo')
% Expand the Sequence into a full Block list by interleaving paired block IDs.
% Each condition entry N becomes two consecutive blocks: N (even) and N-1 (odd),
% representing the two halves of each condition block. Delay periods (0) flank each pair.
Block=0;
for i=1:length(Sequence)
    Block=[Block Sequence(i) Sequence(i)-1];
end
Block=[Block 0];
disp(Block)
blurs
% Build frame-by-frame sequences for block identity (BlockSeq) and direction (BlockSeqDir).
% Delay periods are filled with zeros. Active blocks are subdivided into thirds,
% with direction alternating sign each third — starting positive for odd block IDs
% and negative for even block IDs.
BlockSeq=[]; 
BlockSeqDir=[];
for i=1:length(Block)
    if Block(i)==0
        % Delay period: fill with zeros for the full delay duration
        BlockSeq=[BlockSeq zeros(1,DelayTime)];
        BlockSeqDir=[BlockSeqDir zeros(1,DelayTime)];
    else
        % Active block: fill BlockSeq with the block ID for its full duration
        BlockSeq=[BlockSeq ones(1,BlockTime/2)*Block(i)];

        % Alternate direction in three equal thirds of the block.
        % Even block IDs start with a positive direction; odd block IDs start negative.
        if mod(Block(i),2) == 0
            BlockSeqDir=[BlockSeqDir ones(1,BlockTime/6)*Block(i) -ones(1,BlockTime/6)*Block(i) ones(1,BlockTime/6)*Block(i)];
        else
            BlockSeqDir=[BlockSeqDir -ones(1,BlockTime/6)*Block(i) ones(1,BlockTime/6)*Block(i) -ones(1,BlockTime/6)*Block(i)];
        end
    end
end

disp(BlockSeqDir)
disp(BlockSeq)
blurp
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
    
    % load stimuli into memory
    for c=1:length(colourCondLabels)
        for or=1:length(orientationList)
            for s=1:nSteps
                imName=[pathfile fs 'stimuli' fs colourCondLabels{c} '_grating_' sprintf('%d',orientationList(or)) '_degrees' fs sprintf('%d',s) '.png']; 
                image=(double(imread(imName))/65535);
                index=((c-1)*length(orientationList))+or;
                gratingTexture(index,s)=Screen('MakeTexture',wptr,image,[],[],1);
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
