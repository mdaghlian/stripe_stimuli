# Alex Wade: calibration notes (text transcript)

This is a text transcript of three documents from Dropbox `pilot-clean/code/other/stripe7T/Calibration/`. The figures (photos and plots of raw spectra, correction factors and corrected spectra) are not reproduced. The wording is AW's; only the layout has been changed.

| Original file | Contents |
|---|---|
| `AW-calibration-notes.pdf` | Part 1 (7T notes) and Part 2 (general method), with figures |
| `FIL7TCalibration notes_.docx` | Part 1 only (same text) |
| `(2) Calibration UCL _ Notion.pdf` | Part 2 only (Notion export, 28 May 2026) |

**Naming note (not AW's).** In AW's text and folder names, "ND1", "ND2" and "ND3" (and "3 ND filters", "FIL7T_ETOff_ND1" etc.) mean 1, 2 and 3 ND filters stacked, not optical densities 1–3. Elsewhere in this repository these runs are called `1xNDFilter`, `2xNDFilter` and `3xNDFilter`. AW's text below is unchanged.

The original files are listed in `../../MANIFEST.csv` with their sizes and SHA-256 checksums. They are not kept in this repository.

---

## Part 1. 7T-specific notes

Calibration conducted on 15 May 2026 (written "05/15/26") on the 7T system at the FIL.

- EPSON ELP projector similar to the one used in the 3T.

The calibration pipeline was set up so that the probe tip sat where the subject's eye would be (nice job!). In other words, the entire optical pipeline was accounted for up to the eyeball. We used the same long, plastic 'light pipe' cable that we used for other calibrations in MR suites (see earlier FIL calibrations for example) and 'backed out' the spectral properties of the light pipe using a reference light source. We were then able to 'correct' the measured spectra to generate a 'corrected' calibration with accurate spectra. This doesn't matter much for the gamma correction but it does matter for cone isolation / colour experiments.

Initial calibrations done using the default screen with the eyetracker off. The fiber optic cable we used is very opaque at high wavelengths so we probably don't see the ET illumination (which is above 700 nm I think).

We did several other calibrations with e.g. ET on, or with 1, 2, and 3 additional ND filters in the path. Note that as we changed the ND filters, we needed to also change the integration time. This is set in microseconds in the USB2000 software, so e.g. 300000 is equivalent to 0.3 seconds. With 3 ND filters in the path, we were up at about 1,920,000 µs per measurement (about 2 s) or even 15,360,000 (15 s). There are lots of measurements, 16 per R, G, B, W channel = 64, so at the high ND settings the whole calibration could take many minutes.

All the raw data are in this directory but the most important thing is probably the raw spectrum for the 'unfiltered' response (the 111744 timestamped stuff) and the three 'best' ND filtered sets (i.e. the ones where the integration time was high enough to get a noise-free estimate but low enough to not saturate at the high end):

- ND1: 113055
- ND2: 113923
- ND3: 120813

We did not make a direct luminance measurement in the 7T. But I did make one using exactly the same pipeline on a screen with known luminance at York and sanity-checked it with other luminance measurements made on the 3T screen at the FIL. That says that the unfiltered luminance measured at the eyeball location in the 7T was approximately 900 cd/m². That feels about right given that previous measurements of the screen at the 3T (which has the same model projector) were about 830 cd/m².

Note that even 3 ND filters only get you down to an estimated 2 cd/m². That's not definitely scotopic AFAIK (pure rod vision… something < 0.005 cd/m²?). Each ND filter seems to reduce luminance by about ×8, so 3 of them reduce by ×512… Three more would probably do it!

| Run | Luminance |
|---|---|
| FIL7T_ETOff, latest/clean 30 ms runs | about 944–967 cd/m², mean 952 cd/m² |
| FIL7T_ETOff_ND1 | about 143 cd/m² |
| FIL7T_ETOff_ND2 | about 17–21 cd/m² |
| FIL7T_ETOff_ND3 | about 1.8–2.5 cd/m² |

---

## Part 2. General method ("Calibration UCL", imported from Notion)

On 18 July 2025 we measured the spectra, gamma and luminance for three displays in the basement of the UCL Functional Imaging Laboratory:

1. The screen in the shielded room for the EEG lab (LCD flat panel).
2. The screen in the 'Quattro' fMRI suite (3T / projector / Epson?).
3. The screen in the CTF MEG suite (Propixx projector).

On 15 May 2026 we made another calibration on the 7T. The procedure was essentially identical to what is described here (below). The data are here: https://drive.google.com/drive/folders/1t_RoHfeaCjpgX4SsM5Rov9OCX0x5NqW2?usp=drive_link

Calibration was performed using an OceanOptics USB2000 photospectrometer that we have used for many previous calibrations. There are three components in the calibration chain: the spectrometer, the fiber optic connector and a reference calibrated light source (HL-2000-CAL).

In addition we used a Minolta LS-100 photometer to measure the absolute luminance of the screen in cd/m² at three different levels (black, gray, white: PsychoPy levels −1, 0 and 1).

To do the calibration we positioned one end of the fibre optic connector about 10 cm from the screen (enough that the screen was the only thing within the acceptance angle of the probe). We plugged the other end of the fibre optic cable into the OceanOptics USB2000.

### Measurements

A Python script was then used to step through full-field patches of Red, Green, Blue and White outputs from the minimum to maximum output values. Measurements of the spectra were taken at each level for each colour and saved to disk. The script used PsychoPy libraries to generate the stimuli (with a linear software gamma) and the Seabreeze library to query the OceanOptics device.

To make the luminance measurements, we used a separate script to set the screen to black, mid-gray and white and made manual measurements with the Minolta device, being sure to place the 'target' region of the photometer squarely on the display. In the MRI calibration we were careful not to bring the photometer into the room: we did the measurements through the open door of the MRI room onto the back of the projector display surface. That means that the measurements aren't quite correct (because the subject actually sees the screen through a mirror) but we assume those losses are pretty small and that the mirror is relatively 'flat' spectrally.

You can access the (private) GitHub repo here: https://github.com/wadelab/oceanoptics. Ask for access! You might also be interested in the pyplr Python library (https://pypi.org/project/pyplr/), which also contains some routines for calibration using the same devices.

Raw calibration data are here: https://drive.google.com/drive/folders/195pTvVIhrtGgBYY1toCBATnK5HuDYn1w?usp=sharing

### Correction

We can't use the raw data directly because they are not true representations of the spectra coming from the screen. The reason is that the light collection pathway (the cable, the junction between the cable and the spectrometer, the spectrometer itself) all introduce biases into the measurement. Broadly, the spectrometer might be over- or under-sensitive to particular wavelengths (it is!) and the fiber optic cable might absorb light at some wavelengths and not others (it does!). We picked a cable that was entirely made of plastic and also very long (so that we can make measurements in the MRI bore). But it's not optically perfect in the way that a nice expensive glass one from Thor might be.

*[Figure, not reproduced: the raw data and, in black, the correction factors to apply to the UCL dataset.]* Note that the big rise at the long-wavelength end means that the fibre optic cable was relatively opaque at these wavelengths.

To fix this we use a calibrated light source. This (the HL-2000-CAL) is a light with a known output that we can image through the same pipeline. We then compare the known spectrum of this device against the one we measure and work out what correction we need to apply to any future measures. We have done this and the files are in the same Google Drive link (under HL-2000-CAL).

*[Figure, not reproduced: the 'corrected' spectra, taking into account the biases induced by the recording pipeline.]* The dotted lines indicate what was 'really' there. The fact that they sit above the 'measured' lines in some places indicates that the cable was absorbing relatively highly in those spectral regions. I'm a little nervous about what's happening above 700 nm. I suspect that the measurements are noisy up there because the cable is really opaque, but the good news is that the cone photoreceptors don't absorb much up there either, so it won't make any difference.

### Final file generation

Once we have generated a 'correct spectra' file, e.g. `FIL_EEG_2_spectra_final_20250716_121715_corrected.csv`, we can use it to generate an actual PsychoPy monitor calibration. Do this using the script `generate_corrected_monitor_profile.py`. When you call this it wants to know the following things:

- Screen resolution (pixels, e.g. 1920 × 1080)
- Screen distance (cm)
- Screen size (cm)
- Location of the corrected spectra files you just made (for computing LMS→RGB and DKL→RGB transforms)
- Location of the GammaParams.csv file that you made when the screen was calibrated (e.g. `FIL_EEG_2_gamma_params_20250716_121715.csv`)
- Name of the monitor file (e.g. `EEG_Calib_2025`)

It will prompt you for these if you don't enter them on the command line.

### PsychoPy conversion matrices

Corrected data are available here (NOTE: from the 2025 session): EEG, MEG, MRI. *[Links in the original document.]* These files contain both the original and the corrected data (with obvious column headings) so that you can compare them.
