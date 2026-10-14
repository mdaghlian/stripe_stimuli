# Instructions for running: 

subjid='ZZ'
sesid='01'

% 1) Blue calibration
% run -> 
findIsoluminance_Blue(subjid,sesid);
% When finished press escape

% 2) Red calibration
findIsoluminance_Red(subjid, sesid);
% When finished press escape

% 3) Create stimuli 
makeStimuli(subjid, sesid);

% 4) Run experiment
colourProject(subjid, sesid, 1); % run 1 
colourProject(subjid, sesid, 2); % run 1 

% etc
























## Note on randomisation in colourProject.m 

- A condition is an orientation+stim combination
- e.g., bw-0deg; bw-90deg; colour-0deg; etc. 
- 2xstim (bw; colour)
- 4xorientation (0 45 90 135)
- so 8 conditions in total
- ***
- Each condition in 1:nConditions (8) appears exactly nBlocks/nConditions
- if we set 8 blocks, then that is once per run
- ***
- the list of 8-conditions is shuffled randomly
- -> then checked that:
- -> (1) No 2 consecutive blocks can be the same condition
- -> (2) No 3 consecutive blocks can be the same stim type (bw; colour)
- ***
- this list is then doubled [a,b,c] -> [a,a,b,b,c,c]
- Giving even & odd block IDs; motion direction is flipped 
- Across runs - the same blocks always have the same stim 
- but orientation can change


## Debug notes at FIL
Try running...
```matlab
restoredefaultpath
addpath('C:\...\Psychtoolbox\Psychbasic') % right click add path + subfolders
addpath('C:\...\Psychtoolbox ) <- but here had to right click then add again... 
```
cycle through - try closing and reopening...
Screen 

## 


findIsoluminance_Red('s001t', 's1');
findIsoluminance_Blue('s001t', 's1');
makeStimuli('s001t', 's1');



