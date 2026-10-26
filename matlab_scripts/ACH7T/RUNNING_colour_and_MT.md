# Running a session: colour + MT localisers at the FIL 7T

These are step-by-step instructions for one scanning session. Calibration (isoluminance) is done at the start, in the scanner. Then **colour** and **MT** runs alternate.

Commands go in the MATLAB command window, typed exactly as shown. Replace `'P01'` and `'01'` with the participant ID and session number, and use **the same two values for every step of the session**.

---

## At a glance

| Step | What | Command | Time | Who presses keys |
|---|---|---|---|---|
| 0 | Set up the stimulus PC (once per visit) | – | 5 min | you |
| 1 | Blue isoluminance | `findIsoluminance_Blue('P01','01')` | ~5 min | participant |
| 2 | Red isoluminance | `findIsoluminance_Red('P01','01')` | ~5 min | participant |
| 3 | Red + blue additivity check (first session only) | `checkAdditivityRB('P01','01')` | ~5 min | participant |
| 4 | Make the stimuli | `makeStimuli('P01','01')` then `makeMT('P01','01')` | 2–5 min | nobody (e.g. during a structural scan) |
| 5 | Functional runs, alternating | `colourProject('P01','01',1)`, `mtLocalizer('P01','01',1)`, `colourProject('P01','01',2)`, … | 4.5 min each | participant (fixation task); scanner (trigger) |

Steps 1–3 need the participant in the scanner, looking at the screen. **Step 4 must come after steps 1–2**, because the stimuli are built from the participant's settings.

---

## Step 0. Set up the stimulus PC (once per visit)

1. **Projector:** switch it on in its **standard configuration**. Don't change any projector menu settings; the display calibration assumes the standard settings.
2. **Windows display settings:** set the projector output to **1920 × 1080**. The FIL default is 1920 × 1200; set it back to the default at the end of the visit.
3. **Eye tracker illumination:** off, unless you are eye tracking (the display was calibrated with it off).
4. **`cfg_start.m`** (in the `ACH7T` folder). Check these lines once per computer:
   ```matlab
   cfg.dir_base = '...';      % a folder on THIS computer where data are saved (must exist)
   cfg.width    = 1920;       % NOT 1470 (that is the development laptop)
   cfg.height   = 1080;       % NOT 956
   cfg.screenid = ...;        % the projector's screen number (0 = main screen)
   ```
   Leave everything else as it is. In particular, keep `cal_cfg.type = 'FIL7T'`, `cal_cfg.background = 'matched'` and `cal_cfg.rbCorrection = false` (step 3 says when to change the last one).
5. **MATLAB:** start MATLAB, make sure Psychtoolbox is on the path, and go to the folder:
   ```matlab
   cd('...\matlab_scripts\ACH7T')
   ```
6. **Room light:** keep the scanner room lighting the same from the calibration (steps 1–3) to the last run.

---

## Step 1. Blue isoluminance (participant in the scanner)

```matlab
findIsoluminance_Blue('P01','01')
```

- MATLAB first checks the refresh rate. If it stops with *"Measured refresh rate is … Hz but 60 Hz is expected"*, the display mode is wrong; fix it in Windows display settings (60 Hz, 1920 × 1080).
- A black screen appears.

**Tell the participant:**
> "Keep your eyes on the small dot in the middle. Around it you'll see a patch that flickers. Use button **1** to make it darker and button **2** to make it brighter, one press per step (hold the button to change faster), until the flicker is as weak as you can get it. Then press **3** to confirm. You'll do this 9 times, for patches at different distances from the centre. Press **1** now to start."

- The participant presses **1** to start.
- Each of the 9 trials: they adjust with **1** and **2**, then confirm with **3**. Button 3 only works after at least one adjustment.
- When all trials are done, the settings are **saved straight away** and the screen goes black. MATLAB prints *"Blue isoluminance completed and saved … Press Esc (any keyboard) to continue."* **Press Esc** when you're ready; the fit is then computed and a few figures open (close them).

## Step 2. Red isoluminance

```matlab
findIsoluminance_Red('P01','01')
```

The same procedure and instructions as step 1, with a different colour pair. It needs step 1 to have been done for the same participant and session. At the end it saves, prints *"Red isoluminance completed and saved … Press Esc to continue"*, and you press **Esc**.

## Step 3. Red + blue additivity check (first session only)

```matlab
checkAdditivityRB('P01','01')
```

This checks a property of the projector, not of the participant, so it only needs doing once per study. It can be done by anyone, including you.

**Tell the participant:** the same as step 1:
> "Make the flicker disappear: **1** darker, **2** brighter, **3** done. Press **1** to start."

- 3 trials of red against blue, then 9 trials of a red–blue mix against blue. Then it saves, prints the result and *"R+B additivity check completed and saved … Press Esc to continue"*; press **Esc** after reading the result.
- **Read the last lines in the MATLAB window:**
  - *"All m within ±3% of 1: red + blue add as the model assumes."* Nothing to do.
  - *"Some m differ from 1 by more than 3% …"* In `cfg_start.m`, set `cal_cfg.rbCorrection = true;` and keep it that way for this study. It must be set **before** step 4.

## Step 4. Make the stimuli

```matlab
makeStimuli('P01','01')
makeMT('P01','01')
```

- No participant input. This takes a few minutes, so it can run during a structural scan.
- `makeStimuli` prints *"Display model: FIL 7T measured tables …"* and *"Background: … = W drive …"*. That background (a dim grey) is used by **both** the colour and the MT runs.
- If `makeMT` prints a warning about *"no flicker fits"*, steps 1–2 were not done for this participant and session, or the names don't match. Fix that before scanning.

---

## Step 5. Functional runs, alternating colour and MT

Run them in this order, counting runs separately for each localiser:

| # | Command | Length |
|---|---|---|
| 1 | `colourProject('P01','01',1)` | 270 s |
| 2 | `mtLocalizer('P01','01',1)` | 264 s |
| 3 | `colourProject('P01','01',2)` | 270 s |
| 4 | `mtLocalizer('P01','01',2)` | 264 s |
| … | continue alternating, increasing the run number by 1 each time | |

**Always start the colour runs at 1** for a new participant and session. Run 1 sets the colour/black-and-white block pattern, and later runs copy it.

### Each run, step by step

1. **Type the command** (don't start the scanner yet). MATLAB loads the stimuli and checks the refresh rate. The screen shows a uniform grey with a small white marker in the middle.
2. **Tell the participant** (first run; a reminder later):
   > "Keep your eyes on the shape in the middle the whole time. It will switch between a triangle and a circle every few seconds. Press button **1** each time it changes. Stripes or rings will appear around it; you don't need to do anything with them."
3. **Start the scanner.** The first scanner trigger starts the run; nothing happens until it arrives.
4. **During the run:** nothing to do. You can watch the fixation task in the MATLAB window afterwards.
5. **At the end**, the run is **saved straight away**. The screen stays a uniform grey, so the participant never sees the desktop, and MATLAB prints:
   ```
   Run 1 completed and saved:
     ...\P01_01_Run1_colour
   Press Esc (any keyboard) to continue.
   ```
   **Press Esc** when you're ready for the next run. MATLAB then closes the window and opens two small figures (frame timing and fixation performance). Look at them, then close them.
6. **Check the summary** in the MATLAB window:

   | Line | What it should say | If not |
   |---|---|---|
   | `Measured refresh rate:` | 59.9–60.1 Hz | MATLAB stops at the start if not; fix the display mode |
   | `Keyboard queues:` | 1 or more | – |
   | `Triggers received:` | ≈ run length ÷ TR (e.g. 270 s ÷ 2 s ≈ 136) | far fewer: the trigger isn't reaching the PC as key `5`. Check the trigger box / keypad interface before the next run |
   | `Gap of … s after trigger …` | none | note it in the scan log |
   | Fixation hits / misses | most changes detected | remind the participant about the task |

7. Note the run number and anything unusual in the scan log, then type the next command.

### If something goes wrong

- **To stop a run early:** press **Esc** during the run. What was recorded is saved immediately, and MATLAB prints *"Run … stopped early (Esc) and saved"*. Press **Esc** again to continue. Then repeat that run **with the next run number**, e.g. if `colourProject(...,3)` was stopped, run `colourProject(...,4)`, and note it in the log. Don't reuse a run number: its files would be overwritten.
- **To abort while waiting for the trigger:** press **Esc**. Nothing is saved, so start the same run number again.
- **MATLAB stops with an error:** the screen closes and the gamma table is restored. Read the message:
  - *"Stimuli … were made before gamma correction … Regenerate them with makeStimuli"*: run step 4 again.
  - *"No stim_metadata …"*: step 4 wasn't run for this participant and session.
  - *"cfg.dir_base does not exist"*: fix `cfg.dir_base` in `cfg_start.m`.
  - *"Measured refresh rate is … Hz"*: set the display to 60 Hz.
  - Anything else: note the message and the run number.

---

## Where the data go

```
<cfg.dir_base>/P01/colour/01/stimuli/          colour stimuli + calibration (bwFitData, redFitData, RBadditivity, stim_metadata)
<cfg.dir_base>/P01/colour/01/Run_<n>/logfiles/ colour runs: *_colour.mat, *_colour_Cond.mat (onsets for SPM), *_colour_Eye.mat
<cfg.dir_base>/P01/mt/01/stimuli/              MT stimuli + metadata
<cfg.dir_base>/P01/mt/01/Run_<n>/logfiles/     MT runs: *_mt.mat, *_mt_Cond.mat
```

Copy the whole `P01` folder off the stimulus PC at the end of the visit.

---

## Things to know (for the person running the session)

- **The display is dim on purpose.** Colour, black-and-white and rest screens all have the same mean luminance: a grey matched to this participant (roughly 25–65 cd/m²). The old version used a much brighter grey. The colour stripes look purple-ish, and blue never reaches full intensity; that is correct.
- **Same participant ID and session number everywhere.** The MT runs take their background from the colour calibration with the same ID and session. A mismatch gives a "no flicker fits" warning and a generic background.
- **Later sessions** (`'02'`, …): repeat steps 1, 2, 4 and 5. Step 3 isn't needed again.
- **Settings the calibration depends on:** standard projector configuration, 1920 × 1080, eye-tracker illumination off, unchanged room lighting. If any of these change mid-session, redo steps 1, 2 and 4.
- **Buttons:**
  - **1, 2, 3** = participant (darker / brighter / done in calibration; **1** = "it changed" in the runs),
  - **5** = scanner trigger (automatic),
  - **Esc** = experimenter (move on after a run or calibration has saved; stop a run early).
