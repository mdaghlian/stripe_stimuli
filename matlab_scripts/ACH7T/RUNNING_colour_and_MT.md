# MD instructions running ACH7T - photopic session

Colour + MT localisers, calibration at the start, then alternating runs.

---

## Setup (once per visit)

- Projector in its standard configuration (don't touch the menus).
- Windows display: projector at **1920 × 1080**, 60 Hz (set it back to the default 1920 × 1200 afterwards).
- Eye tracker illumination off.
- `cfg_start.m` (once per computer):
```matlab
cfg.dir_base = '...';   % data folder on this PC (must exist)
cfg.width    = 1920;
cfg.height   = 1080;
cfg.screenid = ...;     % projector screen
```

In MATLAB (Psychtoolbox on the path):
```matlab
cd('...\matlab_scripts\ACH7T')
subjid = 'MD_2026_11_02';
sesid  = '01';
```

Use the same `subjid` / `sesid` for everything below.

---

## Calibration (participant in the scanner)

All tasks: participant fixates the dot; **1** darker, **2** brighter (hold to go faster), **3** done. Participant presses **1** to start.
At the end MATLAB prints `... completed and saved ... Press Esc to continue` → press **Esc**.

Blue:
```matlab
findIsoluminance_Blue(subjid,sesid)
```

Red:
```matlab
findIsoluminance_Red(subjid,sesid)
```

Red + blue combined (once per projector setup, not every session):
```matlab
checkAdditivityRB(subjid,sesid)
```
- `All m within +/-3% of 1` → fine.
- `Some m differ ...` → set `cal_cfg.rbCorrection = true;` in `cfg_start.m` **before making stimuli**.

Gamma check (once per projector setup; anyone can do it):
```matlab
checkGamma(subjid,sesid)
```
- `All m within +/-3% of 1` → fine.
- `Some m differ ...` → note which channel / level; carry on, but flag it (the display model may be off there).

---

## Make stimuli

After blue + red (they use this participant's settings). Can run during a structural scan.
```matlab
makeStimuli(subjid,sesid)
makeMT(subjid,sesid)
```
- Should print `Display model: FIL 7T ...` and `Background: ... = W drive ...`.
- A `no flicker fits` warning means `subjid` / `sesid` don't match the calibration. Fix before scanning.

---

## Running (alternate colour and MT)

Start colour at run 1 (run 1 sets the block pattern).
```matlab
colourProject(subjid,sesid,1)   % 270 s
mtLocalizer(subjid,sesid,1)     % 264 s
colourProject(subjid,sesid,2)
mtLocalizer(subjid,sesid,2)
% ... and so on
```

Each run:
1. Type the command, then start the scanner. The first trigger (`5`) starts the run.
2. Participant: fixate the shape in the middle, press **1** every time it changes (triangle ↔ circle).
3. At the end the run is saved straight away; MATLAB prints `Run n completed and saved ... Press Esc to continue` → press **Esc**. Close the two figures.
4. Check the printout:
   - refresh rate 59.9–60.1 Hz,
   - `Triggers received` ≈ run length ÷ TR (far fewer → trigger not arriving as `5`; check before the next run),
   - no `Gap of ...` lines,
   - fixation: most changes detected.

---

## If something goes wrong

- **Stop a run:** Esc during the run (saved as `stopped early`), Esc again to continue. Redo it with the **next** run number (don't reuse numbers; files get overwritten).
- **Esc while waiting for the trigger:** nothing saved; rerun the same number.
- **Errors:**
  - `made before gamma correction` → rerun `makeStimuli`.
  - `No stim_metadata` → `makeStimuli` not run for this `subjid` / `sesid`.
  - `cfg.dir_base does not exist` → fix `cfg_start.m`.
  - `Measured refresh rate` → set the display to 60 Hz.

---

## Notes

- The display is dim on purpose: colour, BW and rest share one matched grey (~25–65 cd/m²). Purple-ish stripes are correct.
- Later sessions (`sesid = '02'`, ...): blue, red, make stimuli, runs. The additivity and gamma checks don't need repeating unless the projector setup changes.
- If projector settings, resolution, eye-tracker light or room lighting change mid-session: redo blue, red and make stimuli.
- Keys: **1/2/3** participant, **5** scanner trigger, **Esc** experimenter.

## Data

```
<dir_base>/<subjid>/colour/<sesid>/stimuli/logfiles/   calibration (bwFitData, redFitData, RBadditivity, GammaCheck) + stimulus metadata
<dir_base>/<subjid>/colour/<sesid>/Run_<n>/logfiles/   colour runs
<dir_base>/<subjid>/mt/<sesid>/Run_<n>/logfiles/       MT runs
```
Copy the whole `<subjid>` folder off the stimulus PC at the end.
