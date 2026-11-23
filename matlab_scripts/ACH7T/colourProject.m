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
dir_base=cfg.dir_base;
if exist(dir_base,'dir')~=7, error('cfg.dir_base does not exist: %s. Set it in cfg_start.m for this computer.', dir_base); end

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

nSteps=stim_cfg.nPhaseSteps;
orientationList=stim_cfg.thetaList;
colourCondLabels=stim_cfg.colourCondLabels;
FadingTime=stim_cfg.FadingTime;% duration of each fade in / fade out, s
if FadingTime<=0 || FadingTime>BlockTime/2
    error('stim_cfg.FadingTime must be > 0 and <= BlockTime/2 (%g s).', BlockTime/2);
end

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

% Define logfile path for the current run
FileName=[pathfile fs 'Run_' sprintf('%d',name_run) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',name_run) '_colour'];

% The stimuli on disk must have exactly nSteps frames per orientation
% (they are written by makeStimuli with stim_cfg.nPhaseSteps)
stimCheck=[pathfile fs 'stimuli' fs colourCondLabels{1} '_grating_' sprintf('%d',orientationList(1)) '_degrees' fs];
if exist([stimCheck sprintf('%d',nSteps) '.png'],'file')~=2 || exist([stimCheck sprintf('%d',nSteps+1) '.png'],'file')==2
    error('Stimuli in %s do not have stim_cfg.nPhaseSteps = %d frames. Regenerate them with makeStimuli.', stimCheck, nSteps);
end

% EXPERIMENTAL PARADIGM
% MATLAB starts every session with the same random seed, so without this
% the block order would repeat whenever MATLAB is restarted (saved as rngState).
rng('shuffle');
rngState=rng;
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
               break
            end
        end

        % Reject the sequence if three consecutive blocks all belong to the same
        % half of the conditions (i.e. either all colour or all black-and-white),
        % to prevent long runs of one stimulus type
        for i=1:length(temp)-2    
            if (temp(i)<=nConditions/2 && temp(i+1)<=nConditions/2 && temp(i+2)<=nConditions/2)
                redo=1;
                break
            elseif (temp(i)>nConditions/2 && temp(i+1)>nConditions/2 && temp(i+2)>nConditions/2)
                redo=1;
                break
            end
        end
    end

    % Scale condition indices (multiply by 2 to match the full block ID scheme)
    Sequence=2*temp;
    
    % Record whether each block is colour (1) or black-and-white (0),
    % based on whether the condition index is in the upper or lower half
    pseudorandomisation = temp;
    pseudorandomisation(pseudorandomisation > nConditions/2) = 10;  % mark colour blocks
    pseudorandomisation(pseudorandomisation ~= 10) = 0;          % zero out non-colour
    pseudorandomisation(pseudorandomisation ~= 0) = 1;           % set colour blocks to 1

else
    % --- Subsequent runs: odd runs use run 1's colour/BW pattern, even runs
    %     its complement (colour <-> BW), so the colour - BW regressor flips
    %     sign between odd and even runs and anything time-locked to the
    %     block order cancels across runs (stripes_review C1). The pattern
    %     is taken from the most recent earlier run that has a log (so an
    %     aborted or skipped run doesn't block the next one) and flipped if
    %     that run's parity differs from this one's ---
    FileName_old='';
    rFound=0;
    for r=name_run-1:-1:1
        candidate=[pathfile fs 'Run_' sprintf('%d',r) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d',r) '_colour.mat'];
        if exist(candidate,'file')==2 && ~isempty(whos('-file',candidate,'pseudorandomisation'))
            FileName_old=candidate;
            rFound=r;
            break
        end
    end
    if isempty(FileName_old)
        error('Run %d: no earlier run log with a bw/colour pattern in %s. Run 1 first (or set name_run=1).', name_run, pathfile);
    end
    load(FileName_old, 'pseudorandomisation');
    if mod(name_run-rFound,2)==1
        pseudorandomisation=1-pseudorandomisation;
        fprintf('Using the COMPLEMENT of the bw/colour pattern from %s\n', FileName_old);
    else
        fprintf('Using the same bw/colour pattern as %s\n', FileName_old);
    end

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
        temp_check(temp_check > nConditions/2) = 10;
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
% Expand the Sequence into a full Block list by interleaving paired block IDs.
% Each condition entry N becomes two consecutive blocks: N (even) and N-1 (odd),
% representing the two halves of each condition block. Delay periods (0) flank each pair.
Block=0;
for i=1:length(Sequence)
    Block=[Block Sequence(i) Sequence(i)-1];
end
Block=[Block 0];
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


% Block table, one row per rest period or condition block (both halves of
% a condition = one block of BlockTime): used for the measured onsets and
% durations in _Cond.mat / _events.tsv. Condition c (1..nConditions):
% colour label colourCondLabels{ceil(c/nOri)}, orientation
% orientationList(mod(c-1,nOri)+1), the same mapping as the textures.
nOri=length(orientationList);
blkCond=[]; blkDur=[];
for i=1:length(Block)
    if Block(i)==0
        if DelayTime>0, blkCond(end+1)=0; blkDur(end+1)=DelayTime; end %#ok<AGROW>
    elseif mod(Block(i),2)==0%first half of a condition (code 2c)
        blkCond(end+1)=Block(i)/2; blkDur(end+1)=BlockTime; %#ok<AGROW>
    end
end
blockOnsets=[0 cumsum(blkDur(1:end-1))];%planned, s since trigger 1
blkType=repmat({'rest'},1,numel(blkCond));
blkColour=repmat({'n/a'},1,numel(blkCond));
blkOri=nan(1,numel(blkCond));
for b=find(blkCond>0)
    blkColour{b}=colourCondLabels{ceil(blkCond(b)/nOri)};
    blkType{b}=blkColour{b};
    blkOri(b)=orientationList(mod(blkCond(b)-1,nOri)+1);
end

totalFrames = length(BlockSeq);
totalMins   = floor(totalFrames / 60);
remainSecs  = mod(totalFrames, 60);
fprintf('\n--- Run %d of %d ---\n', name_run, nRuns);
fprintf('Duration: %d min %d sec\n', totalMins, remainSecs);
fprintf('Blocks:   %d active + delay periods\n', nBlocks);


% BACKGROUND / REST LEVEL: the matched grey saved with the stimuli (makeStimuli)
metaFiles=dir([pathfile fs 'stimuli' fs 'logfiles' fs 'stim_metadata_*.mat']);
if isempty(metaFiles), error('No stim_metadata in %s. Run makeStimuli first.', [pathfile fs 'stimuli' fs 'logfiles']); end
[~,newest]=max([metaFiles.datenum]);
sp=load([pathfile fs 'stimuli' fs 'logfiles' fs metaFiles(newest).name],'stim_params'); sp=sp.stim_params;
if ~isfield(sp,'background')
    error('Stimuli in %s were made before gamma correction (no background in %s). Regenerate them with makeStimuli.', [pathfile fs 'stimuli'], metaFiles(newest).name);
end
bgDrive=round(sp.background.drive);   % uniform grey (end screen; background if not radial)
[bgImage,bgDesc]=loadBackgroundImage([pathfile fs 'stimuli'],sp,[height width]);   % matched grey background, drive 0-255
fprintf('Background / rest: %s\n', bgDesc);

% FIXATION TASK (fix_cfg in cfg_start)
fixTask=FixationTask(fix_cfg,width,height);

% OPEN PSYCHTOOLBOX WINDOW
try
    % configuration
     
    oldVisualDebugLevel=Screen('Preference','VisualDebugLevel',3);%control visual alerts
    oldSuppressAllWarnings=Screen('Preference','SuppressAllWarnings',1);%suppresses the printout of warnings
    wptr=Screen('OpenWindow',screenid);
    HideCursor;
    Screen('BlendFunction',wptr,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); 
    ifi=checkRefreshRate(wptr,cfg);%flip interval; aborts unless cfg.expectedHz
    gammaInfo=useIdentityGamma(wptr);%identity gamma table, as in the calibration (RestoreCluts on exit); read back and saved
    Priority(MaxPriority(wptr));
    
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

    % load background
    textureIndex(1)=Screen('MakeTexture',wptr,bgImage/255,[],[],1);   % float texture, as the gratings
    
    % flip start screen before trigger (idle fixation)
    Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
    fixTask.draw(wptr);
    Screen('Flip',wptr);

    % EYE TRACKING INITIALISATION
    if cfg.eye_track
        EyelinkInit(0, 1);
        el = EyelinkInitDefaults(wptr);
        el.backgroundcolour = GrayIndex(wptr);
        el.foregroundcolour = BlackIndex(wptr);
        el.calibrationtargetcolour = BlackIndex(wptr);
        EyelinkUpdateDefaults(el);
        Eyelink('Openfile', 'etdata.edf');
        if cfg.eye_calib
            EyelinkDoTrackerSetup(el);
        end
        Eyelink('StartRecording');
    end
    
    % wait for trigger command (key queue: logs every trigger and response
    % with its own GetSecs time; see ScannerKeys.m)
    keys=ScannerKeys(TriggerSign,DetectKey,escapeKey);
    t0=keys.waitForTrigger();%GetSecs time of the first trigger = time zero of the run
    if cfg.eye_track
        % EDF sync: the message is time-stamped by the tracker when sent;
        % its text gives the run time (s since trigger 1) at that moment
        Eyelink('Message','SYNC_TRIGGER1 t=%.4f',GetSecs-t0);
    end

    % flip start screen after trigger (fixation task starts)
    fixTask.start();
    Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
    fixTask.draw(wptr);
    vbl=Screen('Flip',wptr);
    
    % all run times are GetSecs-StartTime, i.e. s since the first trigger
    StartTime=t0;
    
    % experiment 
    cnt=1;
    FadeNeg=0;
    FadePos=0;
    OnsetPos=0;
    alphaImg=0;
    rest_onset=[];
    bw_onset=[];
    colour_onset=[];
    EyelinkData=[];
    names3={'rest','bw','colour'};%newOnset codes 1..3 (eye tracker messages)
    nPad=ceil(FadingTime);
    BlockSeq=[BlockSeq zeros(1,nPad)];%append zeros to fade out at the end of the run even if DelayTime is set to 0.
    BlockSeqDir=[BlockSeqDir zeros(1,nPad)];
    %Frame log, preallocated for up to 240 Hz (+10 s margin) and trimmed after the loop.
    %columns: [t blockCode phaseStep alpha flipOnset], flipOnset = Screen('Flip') StimulusOnsetTime - t0 (PTB GetSecs clock, s)
    LogData=nan(ceil((length(BlockSeq)+10)*240),5);
    frameMissed=nan(size(LogData,1),1);%Screen('Flip') missed flag per frame (>0: deadline missed)
    frameFix=nan(size(LogData,1),1);%fixation state shown on each frame (1 A, 2 B): changes on screen = flipOnset where it switches
    nLog=0;
    img_count=0;
    
    % Frame timing: each frame's stimulus is computed for tF, its predicted
    % onset (previous flip + one refresh interval, s since trigger 1). Drift
    % phase accumulates stepsPerSec*dtF and is rounded to a step: a whole
    % number of steps per frame at the expected refresh rate (smooth), and
    % after a dropped frame it skips ahead, so speed and phase stay right.
    stepsPerSec=stim_cfg.TF_hz*nSteps;%phase steps per second
    stepPos=0;
    tPrev=vbl+ifi-StartTime;
    while true
        tF=vbl+ifi-StartTime;%predicted onset of this frame
        if tF>=length(BlockSeq)-nPad, break; end%because of the appended zeros, we subtract nPad here
        dtF=tF-tPrev;
        tPrev=tF;
        newOnset=0;%1 rest, 2 bw, 3 colour: this frame starts a block (onset = its flip time, logged after the flip)
        fixTask.update(tF);
        if (BlockSeq(floor(tF+1))==0)
            Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);
            fixTask.draw(wptr);
            if OnsetPos==0
                OnsetPos=1;
                newOnset=1;
            end
        else            
            OnsetPos=0;            
            % fade out once the block ends within FadingTime (second half of a block, next block or rest starts at t+FadingTime)
            if (mod(BlockSeq(floor(tF+1)),2)==1 && mod(BlockSeq(floor(tF+1+FadingTime)),2)==0)
                if FadeNeg==0
                    fadeStart=tF;
                    FadeNeg=1;
                    FadePos=0;
                end
                alphaImg=1-((tF)-fadeStart)/FadingTime;
                if alphaImg<0
                    alphaImg=0;
                end         
            else 
                if FadePos==0
                    if BlockSeq(floor(tF+1))<=nConditions%save onset times (BW conditions 1..nConditions/2 have codes 2..nConditions)
                        newOnset=2;
                    else
                        newOnset=3;
                    end
                    fadeStart=tF;
                    FadeNeg=0;
                    FadePos=1;
                end 
                alphaImg=((tF)-fadeStart)/FadingTime;
                if alphaImg>1
                   alphaImg=1;
                end
            end
            imgIndex=ceil(BlockSeq(floor(tF+1))/2);
            % BlockSeqDir>0 steps the frames backwards, <0 forwards
            stepPos=stepPos-sign(BlockSeqDir(floor(tF+1)))*stepsPerSec*dtF;
            cnt=mod(round(stepPos),nSteps)+1;
            Screen('DrawTexture',wptr,textureIndex(1),[],[0 0 width height]);%set underlying grey image as target for fading
            Screen('DrawTexture',wptr,gratingTexture(imgIndex,cnt),[],[0 0 width height],[],[],alphaImg);
            fixTask.draw(wptr);
        end
        tempLog=[tF BlockSeq(floor(tF)+1) cnt alphaImg];
        [vbl,onsetT,~,missedF]=Screen('Flip',wptr);
        nLog=nLog+1;
        LogData(nLog,:)=[tempLog onsetT-t0];
        frameMissed(nLog)=missedF;
        frameFix(nLog)=fixTask.state;
        if cfg.eye_track && newOnset>0
            Eyelink('Message','BLOCK_ONSET %s t=%.4f',names3{newOnset},onsetT-t0);
        end
        % block onsets are when the block's first frame actually appeared,
        % not its predicted time (they differ after a dropped frame)
        switch newOnset
            case 1, rest_onset=[rest_onset onsetT-t0];
            case 2, bw_onset=[bw_onset onsetT-t0];
            case 3, colour_onset=[colour_onset onsetT-t0];
        end
        
        % key presses since the last frame (triggers are stored in keys)
        [respTimes,escapePressed]=keys.poll(t0);
        for r=respTimes
            fixTask.respond(r);
        end
        if escapePressed
            break
        end
        
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

        % collect eye tracking sample
        if cfg.eye_track
            evt = Eyelink('NewestFloatSample');
            EyelinkData = cat(1, EyelinkData, [GetSecs-StartTime evt.gx(1) evt.gy(1) evt.pa(1)]);
        end
    end
    
    tLoopEnd=GetSecs-t0;
    if cfg.eye_track, Eyelink('Message','RUN_END t=%.4f',tLoopEnd); end
    LogData=LogData(1:nLog,:);
    frameMissed=frameMissed(1:nLog);
    frameFix=frameFix(1:nLog);
    keys.release();
    TriggerTime=keys.triggerTimes(t0);%s since the first trigger (first = 0)
    ResponseTime=keys.responses-t0;%every response-key press, s since the first trigger
    keys.report(t0,length(BlockSeq)-nPad);
    RunInfo=runInfo(wptr,ifi,t0);%date/time, versions, git commit, screen
    frameTiming=frameTimingSummary(LogData(:,5),frameMissed,ifi);
    completed=~escapePressed;

    % savings: onsets and durations measured from the flip time of each
    % block's first frame (blocks not shown, after Esc, are left out)
    frameBlock=discretize(LogData(:,1),[blockOnsets inf]);%block-table row of each frame
    [blockOnsetsMeas,blockDurMeas]=measuredBlockTiming(frameBlock,LogData(:,5),blockOnsets,ifi);
    names=names3;
    onsets=cell(1,3);
    durations=cell(1,3);
    for n=1:3
        isThis=strcmp(blkType,names{n})&~isnan(blockOnsetsMeas);
        onsets{n}=blockOnsetsMeas(isThis);
        durations{n}=blockDurMeas(isThis);
    end
    % should be the same onsets as collected during the run (rest_onset etc.)
    if ~isequal(sort([rest_onset bw_onset colour_onset]),sort(blockOnsetsMeas(~isnan(blockOnsetsMeas))))
        warning('colourProject: block onsets from the frame log differ from those collected during the run; check LogData.');
    end
    events=struct('onset',blockOnsetsMeas,'duration',blockDurMeas,'trial_type',{blkType}, ...
        'condition',blkCond,'colour',{blkColour},'orientation',blkOri, ...
        'planned_onset',blockOnsets,'planned_duration',blkDur,'block',1:numel(blkCond));
    shownB=~isnan(blockOnsetsMeas);
    events=structfun(@(c) c(shownB),events,'UniformOutput',false);
    writeEventsTsv([FileName '_events.tsv'],events);

    FixationData=fixTask.data;%[code t] 1=A->B 2=B->A 3=response
    LogColumns={'t_predicted','blockCode','phaseStep','alpha','flipOnset'};
    stimMetadataFile=metaFiles(newest).name;
    save([FileName '_Cond.mat'],'names','onsets','durations','-mat');
    save([FileName '_Eye.mat'],'EyelinkData','-mat');
    save([FileName '.mat'],'FixationData','LogData','LogColumns','pseudorandomisation','TriggerTime','ResponseTime', ...
        'fix_cfg','gammaInfo','bgDesc','bgDrive', ...
        'Sequence','Block','BlockSeq','BlockSeqDir','blkCond','blkType','blkColour','blkOri','blkDur', ...
        'blockOnsets','blockOnsetsMeas','blockDurMeas','frameBlock','frameMissed','frameFix','frameTiming', ...
        'completed','tLoopEnd','RunInfo','rngState','cfg','stim_cfg','cal_cfg','stimMetadataFile','sp', ...
        'orientationList','colourCondLabels','ifi','t0','-mat');

    % stop eye tracking (EDF copied before the end screen)
    if cfg.eye_track
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        Eyelink('ReceiveFile', 'etdata.edf', [FileName '_eyetrack.edf']);
        Eyelink('Shutdown');
    end
    
    % end screen: matched grey (no desktop flash), wait for Esc
    if escapePressed, endState='stopped early (Esc)'; else, endState='completed'; end
    waitAtEnd(wptr,bgDrive*[1 1 1],sprintf('Run %d %s and saved:\n  %s',name_run,endState,FileName));

    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    Screen('Preference','VisualDebugLevel',oldVisualDebugLevel);
    Screen('Preference','SuppressAllWarnings',oldSuppressAllWarnings);

    analysis_Stability(FileName);
    analysis_Fixation(FileName);
catch err
    if exist('keys','var'), try, keys.release(); catch, end, end
    % keep whatever was recorded (frame log, triggers, fixation) for an error mid-run
    if exist('t0','var')
        try
            crashFile=[FileName '_crash.mat'];
            if exist('keys','var'), crashTriggers=keys.triggers; crashResponses=keys.responses; end %#ok<NASGU>
            save(crashFile,'-regexp','^(?!image$|gratingTexture$).');
            fprintf(2,'Error during the run: workspace saved to %s\n',crashFile);
        catch
        end
    end
    Priority(0);
    RestoreCluts;
    Screen('CloseAll');
    ShowCursor;
    if cfg.eye_track
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        Eyelink('ReceiveFile', 'etdata.edf', [FileName '_eyetrack.edf']);
        Eyelink('Shutdown');
    end
    rethrow(err);  
end