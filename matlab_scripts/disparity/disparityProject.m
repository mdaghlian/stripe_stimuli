function disparityProject(name_subj, name_sess, name_run)

close all
fs = filesep;

if ~exist('name_subj','var')
    name_subj = 'TestSubj';
end

if ~exist('name_sess','var')  
    name_sess = 'TestSess';
end

if ~exist('name_run','var')  
    name_run = 1;
end

% DIRECTORY
warning('off');%suppress annoying warnings because of embedding psychtoolbox folders, Matlab incompatibilities and missing semicolons
addpath(genpath('/usr/share/psychtoolbox-3'));
warning('on');
warning ('off','Octave:language-extension');
warning('off','Octave:missing-semicolon');
warning ('off','Octave:mixed-string-concat'); 
dir_base='/data/pt_01880/Experiment3_Stripes';

% ADJUSTABLE PARAMETERS
width = 1024;
height = 768;
conds = 2;
nConditions = 4;
nRuns = 12;
BlockTime = 30;
DelayTime = 15;
stereoMode = 6; % 6=Red-Green, 7=Green-Red, 8=Red-Blue, 9=Blue-Red
numDots = 200; % number of dots
dotSize = 4; % dot size
redLum = 140; % red luminance value
amp = 5; % amplitude of sinusoidal movement in px
freq = 0.25; % frequency of sinusoidal movement in Hz
MAXX = 8; % amount of screen partition in x-direction
MAXY = 6; % amount of screen partition in y-direction
save_screen = 0; % set to 1 for saving screenshots

% INITIALISE KEYS
escapeKey = KbName('escape'); % quit key
TriggerSign = KbName('5');
DetectKey = KbName('1');

%==========================================================================
% end of user specified settings (do not edit below)
%==========================================================================

% LOGFILE
% apparently, Octave doesnt support the creation of nested directories
if isdir(dir_base) == 0
    mkdir(dir_base); 
end

if isdir([dir_base fs name_subj]) == 0
    mkdir(dir_base,name_subj); 
end

if isdir([dir_base fs name_subj fs 'disparity']) == 0
    mkdir([dir_base fs name_subj],'disparity');
end

if isdir([dir_base fs name_subj fs 'disparity' fs name_sess])==0
    mkdir([dir_base fs name_subj fs 'disparity'],name_sess);    
end
pathfile = [dir_base fs name_subj fs 'disparity' fs name_sess];

if isdir([pathfile fs 'Run_' sprintf('%d', name_run)]) == 0
    mkdir([pathfile fs 'Run_' sprintf('%d', name_run)]);             
    mkdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'logfiles']);    
else
    error('Run has already been carried out!')
end
FileName = [pathfile fs 'Run_' sprintf('%d', name_run) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d', name_run) '_disparity'];
FileName_old = [pathfile fs 'Run_' sprintf('%d', name_run-1) fs 'logfiles' fs name_subj '_' name_sess '_Run' sprintf('%d', name_run-1) '_disparity'];

% EXPERIMENTAL PARADIGM
if name_run==1
    BlockSeq = [];
    for i = 1:nConditions
        BlockSeq = [BlockSeq randperm(conds)];
    end
    BlockSeq = [0 BlockSeq 0];
else
    % load BlockSeq from last run
    load([FileName_old '.mat']);
    clear BlockLengths FixationData LogTime
end
BlockLengths = ones(size(BlockSeq)) * BlockTime;
BlockLengths(1) = DelayTime; 
BlockLengths(end) = DelayTime;

% FIXED PARAMETERS
fixSize = 10;
X1 = floor(width/2 - fixSize/2); % fixation spot coordinates
X2 = floor(width/2 + fixSize/2);
Y1 = floor(height/2 - fixSize/2);
Y2 = floor(height/2 + fixSize/2);

% OPEN PSYCHTOOLBOX WINDOW
try
    AssertOpenGL; % break and issue an eror message if the installed Psychtoolbox is not based on OpenGL or Screen() is not working properly.
    screenid = max(Screen('Screens'));
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'AllViews', 'RestrictProcessing', CenterRect([0 0 width height], Screen('Rect', screenid)));
    [windowPtr, windowRect] = PsychImaging('OpenWindow', screenid, BlackIndex(screenid), [], [], [], stereoMode);
    HideCursor;
    MaxPriority(windowPtr);
    Screen('BlendFunction', windowPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % set up alpha-blending for smooth (anti-aliased) drawing of dots
    oldVisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 3);
    oldSuppressAllWarnings = Screen('Preference', 'SuppressAllWarnings', 1);

    % stimulus preparation
    xmax = RectWidth(windowRect) / MAXX;
    ymax = RectHeight(windowRect) / MAXY;
    for i = 1:MAXX
        for j = 1:MAXY
            dots(i,j).DATA = zeros(3,numDots);
            dots(i,j).DATA(1,:) = xmax*rand(1,numDots) - (i-MAXX/2)*xmax;
            dots(i,j).DATA(2,:) = ymax*rand(1,numDots) - (j-MAXY/2)*ymax;        
            dots(i,j).PHI = rand(1);
        end
    end

    % choose stereo mode
    switch stereoMode
        case 6
            SetAnaglyphStereoParameters('LeftGains', windowPtr,  [1.0 0.0 0.0]);
            SetAnaglyphStereoParameters('RightGains', windowPtr, [0.0 0.6 0.0]);
        case 7
            SetAnaglyphStereoParameters('LeftGains', windowPtr,  [0.0 0.6 0.0]);
            SetAnaglyphStereoParameters('RightGains', windowPtr, [1.0 0.0 0.0]);
        case 8
            SetAnaglyphStereoParameters('LeftGains', windowPtr, [0.4 0.0 0.0]);
            SetAnaglyphStereoParameters('RightGains', windowPtr, [0.0 0.2 0.7]);
        case 9
            SetAnaglyphStereoParameters('LeftGains', windowPtr, [0.0 0.2 0.7]);
            SetAnaglyphStereoParameters('RightGains', windowPtr, [0.4 0.0 0.0]);
        otherwise
            error('Unknown stereoMode specified.');
    end

    % Initially fill left- and right-eye image buffer with black background
    % color:
    Screen('SelectStereoDrawBuffer', windowPtr, 0);
    Screen('FillRect', windowPtr, BlackIndex(screenid));
    Screen('SelectStereoDrawBuffer', windowPtr, 1);
    Screen('FillRect', windowPtr, BlackIndex(screenid));

    % Show cleared start screen:
    Screen('Flip', windowPtr);

    % wait for the trigger command 
    [~,~,keyCode] = KbCheck;
    while ~keyCode(TriggerSign)
        [~,~,keyCode] = KbCheck;
    end
    
    % start time measurement (in seconds)
    tic
    
    % first time query
    StartTime = toc;
    LastResponseTime = toc;
    LastKeyCheck = toc;
    
    % experiment
    FixIndex = 0;
    FixationShape = 1; 
    FixCnt = 0;
    FixRand = 0;
    FixationData = [];
    rest_onset = [];
    disparity_onset = [];
    control_onset = [];
    LogTime = [];
    TriggerTime = [];
    exitFlag = 0;
    img_count = 0;
    for Counter = 1:length(BlockSeq)
        
        % check onset time of condition block
        if BlockSeq(Counter) == 1 
            disparity_onset = [disparity_onset toc-StartTime];
        elseif BlockSeq(Counter) == 2 
            control_onset = [control_onset toc-StartTime];
        else
            rest_onset = [rest_onset toc-StartTime];
        end
                
        RunTime = toc;
        while toc - RunTime < BlockLengths(Counter) && exitFlag == 0
            DOTS = [];
            for i = 1:MAXX
                for j = 1:MAXY
                    DOTS = cat(2, DOTS, dots(i,j).DATA);
                end
            end

            % Select left-eye image buffer for drawing:
            Screen('SelectStereoDrawBuffer', windowPtr, 0);
            
            if BlockSeq(Counter) == 1
                Screen('DrawDots', windowPtr, DOTS(1:2,:) + [DOTS(3,:); zeros(1,size(DOTS,2))], dotSize, redLum, windowRect(3:4)/2, 1);            
            elseif BlockSeq(Counter) == 2
                Screen('DrawDots', windowPtr, DOTS(1:2,:), dotSize, redLum, windowRect(3:4)/2, 1);
            else
                Screen('FillRect', windowPtr, BlackIndex(screenid));
            end
            
            if FixIndex == 1
                Screen('FillRect', windowPtr, redLum, [X1 Y1 X2 Y2]);
            else
                Screen('FillOval',windowPtr, redLum, [X1 Y1 X2 Y2]);            
            end

            % Select right-eye image buffer for drawing:
            Screen('SelectStereoDrawBuffer', windowPtr, 1);
            
            if BlockSeq(Counter) == 1
                Screen('DrawDots', windowPtr, DOTS(1:2,:) - [DOTS(3,:); zeros(1,size(DOTS,2))], dotSize, WhiteIndex(screenid), windowRect(3:4)/2, 1);
            elseif BlockSeq(Counter) == 2
                Screen('DrawDots', windowPtr, DOTS(1:2,:), dotSize, WhiteIndex(screenid), windowRect(3:4)/2, 1);
            else
                Screen('FillRect', windowPtr, BlackIndex(screenid));
            end
            
            if FixIndex == 1
                Screen('FillRect', windowPtr, WhiteIndex(screenid), [X1 Y1 X2 Y2]);
            else
                Screen('FillOval',windowPtr, WhiteIndex(screenid), [X1 Y1 X2 Y2]);            
            end   
            
            Screen('DrawingFinished', windowPtr);

            timer = toc;
            for i = 1:MAXX
                for j = 1:MAXY
                    dots(i,j).DATA(3, :) = amp .* sin(2*pi*(freq*timer + dots(i,j).PHI))*((-1)^i)*((-1)^j);
                end
            end

            % flip screen
            Screen('Flip', windowPtr);
            LogTime = [LogTime toc]; % log timestamp
            
            % check key presses
            if toc - LastKeyCheck > 0.2
                LastKeyCheck = toc;
                [~,~,keyCode] = KbCheck;
                if keyCode(escapeKey)
                    exitFlag = 1;
                elseif keyCode(DetectKey) && toc - LastResponseTime > 0.3
                    FixationData = cat(1, FixationData, [3 toc-StartTime]);
                    LastResponseTime = toc;
                elseif keyCode(TriggerSign)
                    TriggerTime=[TriggerTime toc-StartTime];
                end
            end

            % randomise fixation spot
            % colour is changed each 240-600 frames, i.e., between 4-10 seconds at a frame rate of 60 Hz
            if FixCnt == FixRand
                FixCnt = 0;
                FixRand = randi(361) + 239;
                if FixationShape == 1
                    FixationShape = 0;
                    FixIndex = 0;
                    FixationData = cat(1, FixationData, [1 toc-StartTime]);
                else
                    FixationShape = 1;
                    FixIndex = 1;
                    FixationData = cat(1, FixationData, [2 toc-StartTime]);
                end
            end
            FixCnt = FixCnt + 1;
            
            % save screen shots
            if save_screen ~=0
                % save screen into subfolder
                if isdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']) == 0
                    mkdir([pathfile fs 'Run_' sprintf('%d', name_run) fs 'img']);
                end
                
                % get stimulus image into array
                imageArray = Screen('GetImage', windowPtr, [0 0 width height]);
                
                % write screen shot to image
                imwrite(imageArray, [pathfile fs 'Run_' sprintf('%d', name_run) fs 'img' fs 'img_' num2str(img_count) '.png']);
                
                img_count = img_count + 1;
            end
            
        end
    end    
    
    % end screen
	Screen('SelectStereoDrawBuffer', windowPtr, 0);
    Screen('FillRect', windowPtr, BlackIndex(screenid));
    Screen('SelectStereoDrawBuffer', windowPtr, 1);
    Screen('FillRect', windowPtr, BlackIndex(screenid));
    if name_run ~= nRuns
        Screen('SelectStereoDrawBuffer', windowPtr, 0);
        Screen('TextSize',windowPtr,70);
        DrawFormattedText(windowPtr,'Bitte Augen schließen','center','center',255);
		Screen('SelectStereoDrawBuffer', windowPtr, 1);
        Screen('TextSize',windowPtr,70);
        DrawFormattedText(windowPtr,'Bitte Augen schließen','center','center',255);
    else
        Screen('SelectStereoDrawBuffer', windowPtr, 0);
        Screen('TextSize',windowPtr,70);
        DrawFormattedText(windowPtr,'Vielen Dank für die Teilnahme!','center','center',255);
		Screen('SelectStereoDrawBuffer', windowPtr, 1);
        Screen('TextSize',windowPtr,70);
        DrawFormattedText(windowPtr,'Vielen Dank für die Teilnahme!','center','center',255);
    end    
    Screen('Flip',windowPtr);
    exitFlag = 0;
    while ~exitFlag
        [~,~,KeyCode] = KbCheck; 
        if KeyCode(escapeKey)
            exitFlag = 1;
        end
    end
    
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    Screen('Preference','VisualDebugLevel',oldVisualDebugLevel);
    Screen('Preference','SuppressAllWarnings',oldSuppressAllWarnings);
    
    % savings
    names = cell(1,3);
    names{1} = 'rest';
    names{2} = 'disparity';
    names{3} = 'control';
    onsets = cell(1,3);
    onsets{1} = rest_onset;
    onsets{2} = disparity_onset;
    onsets{3} = control_onset;
    durations = cell(1,3);
    durations{1} = DelayTime;
    durations{2} = BlockTime;
    durations{3} = BlockTime;
    
    save('-mat-binary',[FileName '_Cond.mat'],'names','onsets','durations');
    save('-mat-binary',[FileName '.mat'],'BlockSeq', 'BlockLengths', 'FixationData','LogTime','TriggerTime');
    analysis_Stability(FileName);
    analysis_Fixation(FileName);
catch
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    psychrethrow(psychlasterror);
end
