# ACH7T colour calibration: measurements and plan

**Scope.** This document covers how the ACH7T colour paradigm should account for the FIL 7T display's gamma and colour properties. It combines:

- what the 15 May 2026 calibration of the display shows (Sections 1–2),
- what that means for the current ACH7T stimuli (Section 3),
- a plan for building the stimuli and the isoluminance task on that calibration (Sections 4–8).

It is the working document for the `gamma-correct` branch.

**Sources.**

- **Calibration data:** Alex Wade's spectroradiometer measurements of 15 May 2026, with his own luminance code, in [`ACH7T/calibration/FIL7T_20260515_AWade/`](ACH7T/calibration/FIL7T_20260515_AWade/README.md). `ACH7T/cal_FIL7T.m` reads the resulting tables.
- **Display facts:** FIL intranet, projector and stimulus-PC pages.
- **The paradigm:** Nasr, Polimeni & Tootell (2016), *J Neurosci* 36:1841 (Methods read in full).
- **Psychtoolbox:** the `PsychColorCorrection` source (PTB 3.0.22).
- **Literature:** a short search; references are at the end. References marked † are standard ones cited from memory and not re-checked online.

All luminance numbers below come from the tables, unless stated otherwise.

---

## 0. Summary

1. **The display.** The FIL 7T projector (Epson EB-L1100U, laser, 3LCD) runs in the FIL's standard configuration at 60 Hz.
   - **Gamma:** about 2.3 for every channel (fits for drive ≥ 50: R 2.05, G 2.29, B 2.49, W 2.26).
   - **Early clipping:** green stops rising at drive ≈ 206 and blue at ≈ 222; red rises slowly to 255.
   - **Not additive:** below the clip points, R + G + B shown separately add up to about 1.6 × white.
   - **Luminances:** white 952 cd/m², red at full drive 112 cd/m², blue only 26.5 cd/m².
2. **The current colour grating is isoluminant only at its peaks.** It is built from drive-unit sinusoids, so the summed luminance dips to about 46% between the red and blue peaks. That is a luminance grating at twice the stimulus spatial frequency, with Michelson contrast ≈ **0.39**. The flicker match cannot remove it, because it only matches the peaks.
3. **The BW grating and the background are not matched to the colour grating.**
   - The BW peak is 2 × the matched grey **in drive units**. Because of the gamma, its mean luminance is about **46 cd/m²**, against about 20 cd/m² for the current colour grating.
   - The rest grey (drive 128) is about **209 cd/m²**, roughly 10 × the stimuli.
4. **The flicker-photometry idea is right; what is missing is the display model.** Measuring each observer's isoluminance by flicker at several eccentricities is standard practice and is what Nasr et al. (2016) did. The fix is to work in linear luminance:
   - measure the display (done: Alex's tables),
   - measure only the observer's ratios psychophysically,
   - build every stimulus and the background in luminance, and convert to drive at the last step.
5. **Using Alex's tables, a linearised grating has a residual of ≈ 0.012** (the 8-bit limit). After that, the precision of the flicker match dominates: a 2% match error gives 0.017, and 5% gives 0.031.
6. **The main unknown is whether red + blue add on this projector.** It can be checked in the scanner by flicker photometry, without an instrument (Section 5, step 1b).
7. **Design anchor.** The colour grating, the BW grating's mean and the background should all have the same luminance for the observer: about 26.5 cd/m², set by blue's ceiling. That is photopic, as a colour paradigm needs. It also removes the luminance pulse at every block change.

---

## 1. The calibration

**The data** are in [`ACH7T/calibration/FIL7T_20260515_AWade/`](ACH7T/calibration/FIL7T_20260515_AWade/README.md). The README there documents the files, the renaming and the checks.

- **Setup:** full-field R, G, B and W (R = G = B) patches at stepped drive levels, drawn by PsychoPy with an identity gamma. The OceanOptics USB2000 probe was at the participant's eye position, so the projector, screen and mirror are all included. A fibre/spectrometer correction was measured against an HL-2000-CAL reference lamp. The eye tracker was off.
- **Runs:**

  | Run | ND filters stacked | Integration | Drive levels |
  |---|---|---|---|
  | `noFilter` | 0 | 30 ms | 32 |
  | `1xNDFilter` | 1 | 240 ms | 16 |
  | `2xNDFilter` | 2 | 1.92 s | 16 |
  | `3xNDFilter` | 3 | 15.36 s | 16 |

  The names count filters. They are not optical densities: each filter cuts luminance about 7–8×, an optical density of about 0.9.
- **Absolute scale:** white at full drive = 952 cd/m² (Alex's estimate, from the same pipeline cross-checked against a photometer elsewhere).
- **Luminance method:** Alex's `estimate_luminance.py` from [wadelab/oceanoptics-public](https://github.com/wadelab/oceanoptics-public), copied verbatim. For each spectrum: minus dark, ÷ integration time, × fibre correction, × CIE 1924 V(λ), integrated, scaled to 952 cd/m². It is applied at every drive level, which gives luminance against drive for each channel.
- **Black level:** the "dark" spectrum is the black screen, so the tables give luminance above black. The projector's own black level was not measured; it adds equally to every stimulus and the background.

**Conditions the experiment has to reproduce:**

- the projector in its standard configuration, as measured;
- an identity gamma table on the stimulus PC;
- the eye tracker off, or a separate calibration with it on;
- the same resolution as the stimuli were made for (1920 × 1080 in `cfg_start.m`).

---

## 2. What the measurements show

### 2.1 Luminance against drive (no filter, cd/m² at the eye)

Selected rows from the 32-level table. The last column is (R + G + B) / W; 1.00 would mean the display is additive.

| Drive | R | G | B | W | (R+G+B)/W |
|---:|---:|---:|---:|---:|---:|
| 25 | 0.5 | 6.3 | (≈ 0) | 4.4 | – |
| 49 | 3.8 | 31.7 | 0.4 | 22.1 | 1.62 |
| 66 | 7.7 | 62.6 | 1.2 | 46.0 | 1.55 |
| 90 | 15.6 | 129.1 | 2.9 | 91.6 | 1.61 |
| 107 | 22.7 | 191.4 | 3.9 | 138.9 | 1.57 |
| 132 | 35.9 | 297.3 | 7.1 | 223.2 | 1.52 |
| 156 | 51.1 | 455.2 | 10.9 | 315.6 | 1.64 |
| 181 | 68.2 | 627.5 | 15.8 | 457.0 | 1.56 |
| 206 | 87.3 | **829.7** | 21.9 | 600.3 | 1.56 |
| 222 | 99.2 | 812.7 | **26.5** | 730.5 | 1.28 |
| 239 | 109.1 | 830.6 | 26.6 | 862.1 | 1.12 |
| 255 | 111.9 | 832.5 | 26.5 | 952.0 | 1.02 |

Bold marks where green and blue stop rising. Blue's luminance below drive 50 is within the noise.

**Luminance shares at full drive:** R 11.5%, G 85.7%, B 2.7%. The spectral peaks are at about 614 nm (R), 540 nm (G) and 463 nm (B).

### 2.2 Gamma and clipping

| Channel | Clip point (drive) | Max luminance (cd/m²) | γ (fit, drive 50 to the clip) |
|---|---:|---:|---:|
| R | rises slowly to 255 (109 at 239) | 111.9 | 2.05 |
| G | 206 | ≈ 830 | 2.29 |
| B | 222 | 26.5 | 2.49 |
| W | 255 | 952 | 2.26 |

These gammas are summaries only. The stimulus code should use the measured tables (`cal_FIL7T.m`), which capture the curve shape and the clipping exactly.

The exported `gamma_params` files fitted a power law to raw spectrometer counts, including the flat clipped top. Those values describe raw counts, not luminance, and are not used here.

### 2.3 Non-additivity

Below the clip points, the primaries shown separately sum to about 1.6 × white at the same drive. They only converge at full drive. The boost and the early clipping are probably the same mechanism in the projector's colour processing. A primary boosted 1.6× reaches its ceiling at about (1/1.6)<sup>1/2.3</sup> ≈ 0.81 of full drive, matching the clip points of 206–222.

Two consequences:

- The luminance of the R + B mixtures in the colour grating **cannot be predicted** from the single-channel curves; it has to be checked (Section 5, step 1b).
- Grey (R = G = B) must use the measured W curve, not the sum of R, G and B.

**Note: how likely are red and blue to add?** No measurement of red + blue mixtures on this projector model was found, either published or in Alex's calibrations of the 7T (May 2026) and 3T (July 2025) Epsons, which measured single channels and white only. The evidence points both ways.

- **For additivity:**
  - **The optics are additive.** 3LCD projectors combine three separate LCD panels in a prism, with no colour wheel or white segment. LCD projectors are generally reported to be additive to within a fraction of a percent, unlike single-chip DLP (see the LCD/DLP characterisation literature in the references). The data agree at full drive: R + G + B = 1.02 × W.
  - **The colour grating never uses green** (G = 0 everywhere), so every pixel is a fully saturated colour, like a pure primary. If the boost below full drive depends on saturation, red + blue mixtures get the same treatment as red or blue alone, and the single-channel tables add correctly.
- **Against:** the non-additivity below full drive is large and present on both installations measured with the same method (Alex's luminance code):

  | | (R+G+B)/W at mid drives | At full drive | G / B stop rising at |
  |---|---|---|---|
  | 7T (15 May 2026) | 1.51–1.64 | 1.02 | 206 / 222 |
  | 3T Quattro (16 Jul 2025) | 1.42–1.60 | 1.00 | ≈ 204–238 |

  This is how the model behaves in its standard configuration. It comes from image processing rather than the optics, and the mechanism is unknown. If it depends on saturation, red + blue add. If it depends on something else (e.g. the overall brightness of the frame, or a colour-space mapping that treats magenta differently from red and blue), they may not.

**Estimate:** probably close to additive for the G = 0 grating, but not safe to assume. A 10% shortfall would leave a residual of about 0.06, the largest remaining error, so the flicker-based check (Section 5, step 1b) is worth its few minutes of scanner time.

### 2.4 Filters

| Filters stacked | W at 255 (cd/m²) | Total attenuation | Attenuation of the last filter |
|---|---:|---:|---:|
| 0 | 952 | 1 | – |
| 1 | 143.8 | 6.6 × | 6.6 × |
| 2 | 16.8 | 57 × | 8.6 × |
| 3 | 2.32 | 411 × | 7.2 × |
| 6 (scotopic pilot, **extrapolated**) | ≈ 0.006 | ≈ 160,000 × | – |

- **Gamma is unchanged by the filters.** The white curve's shape agrees across 0–3 filters to within about 2.4%, the same as repeat-to-repeat variation (W γ 2.26–2.36). The filters scale luminance down without changing the transfer curve.
- **Six filters** (the scotopic pilot) put grey 128 at about 0.0013 cd/m², at the scotopic/mesopic boundary, as intended. This is extrapolated; nothing was measured through six filters.
- **For colour, use only the no-filter table.** The single-channel red and blue curves get noisy through 2–3 filters (very small signal), and their red-to-blue balance varies between runs.

### 2.5 Uniformity

All readings come from one probe position. The tables describe the screen at that point. The in-scanner flicker match absorbs chromatic non-uniformity at each band. Luminance fall-off towards the edges would affect the background and the BW grating slightly. A few spot readings at the band centres would quantify it (Section 5, step 1c).

---

## 3. What this means for the current ACH7T stimuli

### 3.1 The colour grating

`makeStimuli.m` sets blue = 255·g and red = r<sub>match</sub>·(1 − g), with g a [0, 1] sinusoid: antiphase sinusoids in drive units. On the measured display, with red matched to blue's full-drive luminance (red drive ≈ 115):

| Phase g | Blue (cd/m²) | Red (cd/m²) | Sum |
|---:|---:|---:|---:|
| 0 | 0.0 | 26.6 | **26.6** |
| 0.25 | 1.2 | 13.9 | 15.1 |
| 0.5 | 6.4 | 5.8 | **12.2** |
| 0.75 | 18.0 | 0.9 | 18.9 |
| 1 | 26.6 | 0.0 | **26.6** |

The result is a luminance grating at **2 × the stimulus spatial frequency**, with Michelson contrast ≈ **0.39** and mean ≈ 20.5 cd/m², drifting with the colour grating. The flicker-match values are still valid: they correctly give the red drive whose luminance equals blue's peak, for that observer. What is missing is converting those values to luminance, building the sinusoids in luminance, and converting each channel back to drive with its own curve.

Also:

- **Blue above 222 does nothing.** The top 13% of the blue drive range is on the plateau, so the blue sinusoid's peaks are flat.
- **The red start points of the flicker task (180–220) are far above the expected match** (drive ≈ 115 for an average observer).

### 3.2 The BW grating

The BW peak is 2 × the matched grey, in drive units (grey match ≈ drive 52, so the peak is ≈ 105). With γ ≈ 2.3, doubling the drive multiplies luminance by about 5. The grating's luminance therefore runs from 0 to about 133 cd/m² with a **mean of about 46 cd/m²**: roughly twice the colour grating's luminance, not equal to it. Its profile is also not sinusoidal: bright bars are narrow, and dark regions are wide.

Built in linear luminance instead, a BW grating from 0 to 2 × 26.6 = 53 cd/m² (peak drive ≈ 70) has a mean of 26.6 cd/m², equal to the colour grating, and a true sinusoidal profile.

### 3.3 Background and rest blocks

Grey 128 is about **209 cd/m²**, about 10 × the stimuli. Each rest ↔ stimulus change, and each block boundary (the fades pass through the background), is a full-field luminance step of roughly that size. The grey with the same luminance as the colour grating is drive ≈ **52**.

Matching the mean luminance of the colour grating, the BW grating and the rest periods has not been achieved in earlier implementations of this paradigm, including the ACH7T pilot: their means differed from one another and from the rest grey by large factors. Building all three around one luminance anchor (Section 5, step 3) addresses this.

### 3.4 Display state

The flicker tasks load an identity gamma table. The run scripts load none, so they run under whatever the OS has loaded. Both must use the identity table, the state in which the display was measured.

---

## 4. First principles

The aim is a red/blue grating that drives colour-opponent mechanisms but **not** the luminance mechanism of *this* observer, at *every* point in space and time, and in the adaptation state of the experiment. The control is an achromatic grating with the same mean luminance, on a baseline at that luminance.

Three things lie between a pixel value and "luminance for this observer":

| Link | Determined by | Measured by |
|---|---|---|
| Drive → light | each channel's curve (gamma, clipping), how channels combine (additivity), uniformity, display configuration | an instrument (done: Alex's tables) |
| Light → luminance for this observer | L:M cone ratio, macular pigment (strongest centrally, falling with eccentricity), lens density; individual differences of tens of percent | psychophysics (flicker photometry, minimum motion) |
| Context | surround luminance and adaptation, flicker frequency, retinal location | matching the calibration conditions to the experiment |

**Why not a standard photometric (V(λ)) match?** Individual luminosity functions differ, especially at the blue end because of macular pigment. fMRI colour studies therefore set isoluminance per observer (Nasr 2016; Mullen et al. 2007; Engel et al. 1997†). The ratio also changes with eccentricity (Bilodeau & Faubert 1997; Nasr 2016, Fig. 2), largely because macular pigment falls off across the central few degrees (van der Veen et al. 2009).

**Why a flicker match in drive units only holds at the matched point.** Flicker photometry finds the red drive whose luminance equals blue at a given drive, for that observer. It says nothing about intermediate drives. With γ ≈ 2.3, half the drive gives about 20% of the luminance, so drive-unit sinusoids dip between their peaks.

**The principle:**

```
instrument:     drive  <-->  linear light, per channel (checked for mixtures)
psychophysics:  observer's luminance ratios  red : blue,  grey : blue   (per eccentricity)
design:         every stimulus and the background in linear units -> drive at the end
```

### 4.1 The current approach against this

| Aspect | Current ACH7T | Assessment |
|---|---|---|
| Per-observer, per-eccentricity flicker match with blue at maximum as the reference | yes | **Right**, and standard. Blue is the dimmest primary, so it sets the luminance ceiling. |
| Low spatial frequency | 0.4 cpd (Nasr: 0.2 cpd) | **Right in principle.** Low SF limits the luminance artefacts that chromatic aberration creates at red/blue edges; Nasr chose 0.2 cpd for this reason. Consider whether 0.4 is needed. |
| Display model | none | **Missing.** Causes the 0.39 artefact. |
| Chain of matches | blue ↔ grey, then red ↔ that grey | **Avoidable.** Two matches compound errors, and grey is where the projector is least additive. Match red to blue directly; use a separate grey ↔ blue match only for the BW control and the background. |
| Display state | identity table in the flicker task, OS table in the experiment | **Make consistent:** identity table throughout, standard projector configuration. |
| Flicker-task surround | black | **Match the experiment:** a surround at the background luminance. |
| Where the flicker task is done | **in the scanner** (as in the ACH7T pilot), as Nasr did just before the functional runs | **Right; keep it.** Same projector, mirror and viewing conditions as the experiment, and it absorbs chromatic non-uniformity at each band. |
| Flicker frequency | 30 Hz (refresh / 2), as in Nasr | Pilot against 15 Hz (Section 5, step 2). |
| Eccentricity model | linear in log(eccentricity) through 3 points, clamped | Acceptable; keep the outer band on screen. |
| BW and background luminance | defined in drive units | **Define in luminance** around one anchor (Section 5, step 3). |

**Note on the BW control.** The published description of the paradigm (Nasr 2016) sets the BW grating's white point to the matched grey and its black to zero, so its mean is half the matched luminance. This plan matches the BW grating's *mean* to the colour grating instead, so that colour, BW and rest share one luminance (Section 5, step 3). Comparisons with the published results should take that design difference into account.

---

## 5. Plan

### Step 1. Display model

**Display facts:**
- **Projector:** Epson EB-L1100U laser projector (3LCD, ELPLL08 lens), 60 Hz (Windows may report 59.9 Hz), about 2 frames (40 ms) of latency, native 1920 × 1080.
- **Stimulus PC:** Windows 11 with Psychtoolbox 3.0.16.
- **Display settings:** may be changed for a session but are returned to the defaults afterwards. The projector runs in the FIL's standard configuration.

A laser light source is stable over time, so a measurement in the standard configuration is a good description of later sessions.

**1a. Use Alex's tables now** (`cal_FIL7T()`, no filter). They give luminance above black against drive, per channel:

- **Model:** a stimulus with drive d<sub>c</sub> in channel c has luminance Σ<sub>c</sub> ΔL<sub>c</sub>(d<sub>c</sub>).
- **Grey uses the W table**, not R + G + B.
- **`cal.d` inverts a channel's curve** on its rising part.
- **Accuracy:** a grating built from the tables has a residual of ≈ 0.012, the 8-bit limit, provided red and blue add (1b).

**1b. Check R + B additivity in the scanner by flicker photometry (no instrument).**

Flicker photometry is additive (Abney's law holds for it; Wagner & Boynton 1972). A flicker match can therefore test whether the *display* adds red and blue, and any observer can do it, including the experimenter.

1. Make the usual red ↔ blue match, giving that observer's k.
2. Flicker the mixture the model predicts is isoluminant, red at ½·L<sub>B</sub>·k plus blue at ½·L<sub>B</sub>, against pure blue at L<sub>B</sub>. Adjust a scale *m* on the mixture until the flicker is minimal.
3. If the display adds R + B, *m* = 1. Repeat at the ¼ and ¾ proportions.

Interpretation:

- ***m* within about ±3% of 1:** additive; use the per-channel model.
- ***m* clearly different from 1:** use the measured *m*(g) as a correction: with `cal_cfg.rbCorrection = true`, `makeStimuli` multiplies the colour grating's luminance at blue fraction g by *m*(g). (*m* > 1 means the mixture had to be raised, i.e. the display gives less than the sum.)
- **Implemented** as `checkAdditivityRB(subj, sess)` (settings: `rbcheck_cfg`). It saves `RBadditivity_<time>.mat` in the session's `stimuli/logfiles`.
- **Reference:** R + B mixtures at 90% of the sum would leave a residual of about 0.06 if not corrected.

**1c. Refine with a spectroradiometer when one is available:**

- R + B in the grating's proportions (the physical version of 1b),
- grey ramps,
- spot readings at the band centres (uniformity),
- if possible, the black level.

If R + B turns out to be clearly non-additive, measure the R–B plane (G = 0) on a grid; PTB's `PsychColorCorrection` `LookupTable3D` can apply it at display time. Also compute the stimulus cone contrasts from the spectra (Section 7).

**Every session:** the stimulus PC at the resolution the stimuli were made for, the projector in its standard configuration, and the identity gamma table loaded. Optionally repeat 1b on one observer as a drift check.

### Step 2. Psychophysics in linear units, in the scanner

Two **independent, single-stage** matches, both made in the scanner just before the functional runs (as the flicker task already is, e.g. in the pilot), on a surround at the background luminance (step 3), at each eccentricity band:

| Match | Reference | Adjusted | Used for |
|---|---|---|---|
| Colour | blue at its maximum, L<sub>B</sub> ≈ 26.5 cd/m² | red luminance | red weight k(ecc) |
| Achromatic | blue at its maximum, L<sub>B</sub> | grey (W) luminance | L<sub>grey</sub>(ecc): the achromatic luminance this observer sees as equal to the colour grating; sets the BW grating and the background |

- **Steps in linear luminance:** e.g. ±1.5% per press with a coarse ±6% key, converted to drive with `cal_FIL7T`. Near the expected red match (drive ≈ 115), one drive level is about 2% in luminance, adequate at 8 bits. Never ask red for more than it can produce.
- **Flicker frequency.** Flicker photometry is normally run at about 10–20 Hz (Wagner & Boynton 1972; Lee, Martin & Valberg 1988†).
  - Too slow, and the colour difference itself flickers, and S-cone signals bias red-vs-blue matches.
  - Too fast, and the null becomes shallow. At about 26 cd/m², 30 Hz may be near the flicker-fusion limit for many observers.
  - A 60 Hz display can alternate at 30, 15 or 10 Hz. **Pilot 15 Hz against 30 Hz** on two or three observers, keep whichever gives the smaller spread, then fix it and report it. 30 Hz keeps comparability with Nasr.
- **Repetitions:** at least 4 per band (Nasr used 4), approaching from above and below with jittered starts. Print the SD per band; repeat bands whose SD exceeds about 5% of the match.
- **Bands:** inside the screen height, with centres that bracket the stimulus. Fit k(ecc) and L<sub>grey</sub>(ecc) against log eccentricity and clamp outside the bands (as now).
- **Rendering:** with a linear-luminance display model, the task can draw the two fields on alternate frames instead of animating the gamma table. It then uses the same rendering as the experiment.

### Step 3. Build every stimulus in linear units around one anchor

With L<sub>B</sub> the blue maximum and g a sinusoid in [0, 1]:

| Stimulus | Definition (linear luminance) | Mean |
|---|---|---|
| Colour grating | B = L<sub>B</sub>·g, R = L<sub>B</sub>·k(ecc)·(1 − g) | constant at every point (isoluminant) |
| BW grating | W = 2·L<sub>grey</sub>(ecc)·g′ (0 to 2·L<sub>grey</sub>, sinusoidal in luminance) | L<sub>grey</sub>(ecc), equal for this observer to the colour grating |
| Background / rest | W = L<sub>grey</sub> | the same |
| Block transitions | cross-fades between stimuli, blended in linear units | the same throughout |

Consequences:

- **No luminance step** at rest ↔ stimulus changes or at block boundaries.
- **BW peak about 53 cd/m²** (W drive ≈ 70), well within reach.
- **The display runs at about 26 cd/m²** unfiltered: photopic, as a colour paradigm requires. Check the fixation task and eye tracker at that level.

**Where the conversion to drive happens:**

| | **A. Pre-computed drive images** (minimal change) | **B. Linear rendering in PTB** (target) |
|---|---|---|
| How | `makeStimuli` converts each channel with `cal.d` and writes drive PNGs; the run scripts load an identity gamma table | images stored in linear units; `PsychImaging` with a floating-point framebuffer and `DisplayColorCorrection` `LookupTable` (or `LookupTable3D`) holding the measured inverse curves |
| Fades / cross-fades | blending on drive values: luminance not constant during a fade | blending in linear units: luminance constant |
| Flicker task | needs its own conversion | same pipeline |
| New calibration | regenerate all stimuli | load a new table |
| Effort | small | moderate |

Do A first, then B when the fades are reworked. PTB's documentation recommends the hardware gamma table for *simple* gamma on 8-bit displays, but that cannot express the clipping or a 2-D mixture table, and the flicker task uses the hardware table for its animation. The shader-based `LookupTable` is the appropriate route.

### Step 4. Validate the actual stimulus

1. **Psychophysically (no instrument).** Run a minimum-motion check with the real colour grating (Anstis & Cavanagh 1983): alternate it with a luminance grating offset by a quarter cycle. Any residual luminance in the colour grating produces apparent motion in a predictable direction.
2. **Physically, when possible.** Measure a small spot while the grating drifts slowly; the summed luminance should be flat to within about 2%. Repeat with the BW grating and the background.
3. **Report** the settings, the SD per band, k(ecc), L<sub>grey</sub>(ecc), the validation result and the cone contrasts.

---

## 6. Precision budget

| Source | Residual (Michelson) | Notes |
|---|---:|---|
| Current drive-space grating | **0.39** | at 2 × the grating's spatial frequency |
| Linearised, 8-bit, perfect match | 0.012 | Blue has only 58 drive levels below 1 cd/m², so the troughs are coarse but adequate. |
| Red match off by 2% / 5% / 10% | 0.017 / 0.031 / 0.052 | at the grating's own spatial frequency |
| R + B mixtures at 90% of the sum (uncorrected) | ≈ 0.06 | measured and corrected by step 1b |
| Display drift / non-uniformity | a few % | per-session check; in-scanner matching absorbs chromatic non-uniformity |
| Chromatic aberration at red/blue edges | small at 0.2–0.4 cpd | inherent to red/blue |

After linearisation, the precision of the flicker match is the dominant term, so in-scanner matching, the frequency, enough repetitions and a matched surround matter most. More bit depth (10-bit output, bit-stealing: Pelli & Zhang 1991†; Tyler 1997†) would only improve the smallest term.

---

## 7. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Cone-contrast / DKL design** (Derrington, Krauskopf & Lennie 1984†; Engel et al. 1997†; Mullen et al. 2007) | The textbook approach for colour fMRI. It changes the stimulus (lower saturation, modulation around neutral grey) and loses comparability with Nasr. **Keep red/blue, but compute and report the L, M and S cone contrasts** from the measured spectra and cone fundamentals (Stockman & Sharpe 2000†). |
| **Minimum-motion photometry** instead of flicker (Anstis & Cavanagh 1983) | Often more sensitive and easier for naive observers. **Use as validation (step 4);** keep flicker photometry as the primary method. |
| **A fixed photometric match** (V(λ) only) | Not adequate: individual differences exceed the precision needed. |
| **More bit depth** | Not needed (0.012 from quantisation). |
| **Luminance-noise masking** | Changes the stimulus and adds luminance energy; not recommended for this localiser. |
| **A different display** | Outside this project's control. The pipeline works with any display once step 1 is repeated. |

---

## 8. Changes to ACH7T

| # | Change | Status / depends on |
|---|---|---|
| 1 | Display model: Alex's data, code and tables; `cal_FIL7T.m`; `displayModel.m` (measured tables, any table file, or gamma values per channel or across, with clip points), selected by `cal_cfg` (step 1a) | **done** (`b3ecb62`, `11aae5b`) |
| 2 | Flicker-based R + B additivity check (step 1b): `checkAdditivityRB.m`, with optional correction in `makeStimuli` (`cal_cfg.rbCorrection`) | **done** (`b0309c3`); run it in the scanner (a few minutes) |
| 3 | Flicker task rewrite: red ↔ blue and grey ↔ blue single-stage matches, linear-luminance steps, frame-by-frame rendering, surround at the background luminance, 15 or 30 Hz (piloted), ≥ 4 repetitions per band with SD reported, bands within the screen | 1 |
| 4 | `makeStimuli`: colour, BW and background built in linear units around L<sub>grey</sub> (step 3), converted per channel (option A) | **colour and BW done** (`daef28a`): the gratings are built in luminance from the existing flicker matches. Background still grey 128; the matching grey drive is saved in `stim_params` |
| 5 | Run scripts: identity gamma table, background from L<sub>grey</sub>, table restored on exit | **identity table done** (`5a812d5`); background to do |
| 6 | Validation: minimum-motion check (step 4); physical measurement and cone contrasts when possible | 4, 5 |
| 7 | Later: linear rendering (option B) and luminance-neutral cross-fades | 5 |

---

## 9. Open questions

1. Was the 15 May calibration made with the projector in its standard configuration, at the experiment's resolution? (Worth confirming, so that the tables can be used with confidence.)
2. Should the background be one luminance, or follow L<sub>grey</sub>(ecc) radially (exactly matched at every eccentricity, but visibly non-uniform)?
3. How important is comparability with the published stimuli? If important, keep 0.2 cpd and 30 Hz unless the pilot argues otherwise, and note the BW design difference (Section 4.1).

---

## References

Checked for this document:

- Nasr S, Polimeni JR, Tootell RBH (2016). Interdigitated color- and disparity-selective columns within human visual cortical areas V2 and V3. *J Neurosci* 36(6):1841–1857. [PDF](https://www.jneurosci.org/content/jneuro/36/6/1841.full.pdf)
- Wagner G, Boynton RM (1972). Comparison of four methods of heterochromatic photometry. *JOSA* 62:1508. [doi:10.1364/JOSA.62.001508](https://doi.org/10.1364/JOSA.62.001508)
- Bilodeau L, Faubert J (1997). Isoluminance and chromatic motion perception throughout the visual field. *Vision Res* 37:2073–2081.
- Anstis S, Cavanagh P (1983). A minimum motion technique for judging equiluminance. In Mollon & Sharpe (eds), *Colour Vision: Physiology and Psychophysics*, pp. 155–166. [Demonstration](https://michaelbach.de/ot/col-flicker/)
- Mullen KT, Dumoulin SO, McMahon KL, de Zubicaray GI, Hess RF (2007). Selectivity of human retinotopic visual cortex to S-cone-opponent, L/M-cone-opponent and achromatic stimulation. *Eur J Neurosci*. [record](https://neurosynth.org/studies/17284191)
- van der Veen RLP et al. (2009). Correspondence between retinal reflectometry and a flicker-based technique in the measurement of macular pigment spatial profiles. *J Biomed Opt* 14:064046.
- Wade A. oceanoptics-public: display calibration with an Ocean Optics spectrometer. [github.com/wadelab/oceanoptics-public](https://github.com/wadelab/oceanoptics-public) (commit `ed9b9fa`).
- Psychtoolbox-3, `PsychColorCorrection.m` (`LookupTable`, `LookupTable3D`).
- [York University, Heterochromatic flicker photometry](https://www.yorku.ca/eye/hfp.htm).
- Colorimetric characterisation of LCD and DLP projection displays (ResearchGate record). [link](https://www.researchgate.net/publication/245413681_Colorimetric_characterization_of_LCD_and_DLP_projection_displays)
- Characterisation of a desktop LCD projector. *Displays* (2000). [link](https://www.sciencedirect.com/science/article/abs/pii/S0141938200000494)

Standard references, cited from memory (†):

- Brainard DH (1989). Calibration of a computer controlled color monitor. *Color Res Appl* 14:23–34.
- Brainard DH, Pelli DG, Robson T (2002). Display characterization. In *Encyclopedia of Imaging Science and Technology*. Wiley.
- Packer O et al. (2001). Characterization and use of a digital light projector for vision research. *Vision Res* 41:427–439.
- Lee BB, Martin PR, Valberg A (1988). The physiological basis of heterochromatic flicker photometry demonstrated in the ganglion cells of the macaque retina. *J Physiol* 404:323–347.
- Derrington AM, Krauskopf J, Lennie P (1984). Chromatic mechanisms in lateral geniculate nucleus of macaque. *J Physiol* 357:241–265.
- Stockman A, Sharpe LT (2000). The spectral sensitivities of the middle- and long-wavelength-sensitive cones derived from measurements in observers of known genotype. *Vision Res* 40:1711–1737.
- Engel S, Zhang X, Wandell B (1997). Colour tuning in human visual cortex measured with functional magnetic resonance imaging. *Nature* 388:68–71.
- Pelli DG, Zhang L (1991). Accurate control of contrast on microcomputer displays. *Vision Res* 31:1337–1350.
- Tyler CW (1997). Colour bit-stealing to enhance the luminance resolution of digital displays on a single pixel basis. *Spatial Vision* 10:369–377.
