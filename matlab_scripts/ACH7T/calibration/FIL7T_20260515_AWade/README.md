# FIL 7T projector calibration, 15 May 2026 (Alex Wade)

This folder holds Alex Wade's spectroradiometer calibration of the FIL 7T display, the luminance code from his toolbox, a script that runs that code to produce luminance tables, and the tables themselves. [`cal_FIL7T.m`](../../cal_FIL7T.m) reads the tables.

| Folder / file | What it is |
|---|---|
| `original/` | AW's data files, **copied byte for byte** from Dropbox `pilot-clean/code/other/stripe7T/Calibration/`, renamed for clarity (below). His notes are kept as a text transcript, `original/notes/AWade_calibration_notes.md`, in place of the PDF/Word files |
| `MANIFEST.csv` | every original file: original path, new path, size, SHA-256, and whether it is kept here. Kept copies have the same SHA-256 as the original |
| `oceanoptics_public/` | **AW's code, verbatim:** `estimate_luminance.py` and `LICENSE` from [wadelab/oceanoptics-public](https://github.com/wadelab/oceanoptics-public) (commit `ed9b9fa`, MIT licence, © 2026 Alex Wade, Wade Lab, University of York) |
| `build_tables.py` | runs AW's luminance function on `original/` to build `tables/` |
| `tables/cal_FIL7T_20260515_<run>.csv` | luminance (cd/m²) against drive (0–255) for R, G, B and W, one file per run |
| `tables/build_log.txt` | the checks printed by the last build |

## The measurement

From AW's notes (`original/notes/AWade_calibration_notes.md`):

- **Display:** FIL 7T Epson projector (EB-L1100U laser, standard configuration), full-field patches of R, G, B and W (R = G = B) at stepped drive levels, drawn by PsychoPy with an identity (linear) gamma.
- **Instrument:** OceanOptics USB2000 spectrometer with a long plastic fibre. The probe tip was at the position of the participant's eye, so the whole optical path (projector, screen and mirror) is included.
- **Fibre/spectrometer correction:** AW measured the fibre and spectrometer response against an HL-2000-CAL reference lamp and exported a `correction_factor` per wavelength. It matters little for the shape of each channel's curve, but it does matter for comparing channels (colour).
- **Absolute luminance:** there was no photometer at the 7T. AW's estimate for the unfiltered display, from the same pipeline cross-checked at York and on the 3T, is W ≈ 952 cd/m² (944–967) with the eye tracker off.
- **Runs:** AW marked these as the best ones, with exposures long enough for clean spectra and short enough not to saturate.

| Run | AW's folder / timestamp | ND filters stacked | Integration | Drive levels |
|---|---|---|---|---|
| `noFilter` | `NO_FILTER/` 111744 | none | 30 ms | 32 |
| `1xNDFilter` | `ND1/` 113055 | 1 | 240 ms | 16 |
| `2xNDFilter` | `ND2/` 113923 | 2 | 1.92 s | 16 |
| `3xNDFilter` | `ND3/` 120813 | 3 | 15.36 s | 16 |

**Naming.** `nxNDFilter` means n neutral-density filters stacked in the light path. AW's folders are called `ND1`–`ND3`, but by convention "ND1", "ND2" and "ND3" name a filter's *optical density* (×10, ×100, ×1000), which is not what they mean here. Each filter cuts luminance about 7–8× (6.6–8.5×), i.e. an optical density of about 0.9 per filter, so three filters together give about ×400, not ×1000. The scotopic pilot used six filters, which were not measured.

## Renamed files

Pattern: `original/<run>/<run>_<content>.<ext>`. `MANIFEST.csv` gives the exact original name of each file.

| New name | Original name | Contents |
|---|---|---|
| `<run>_spectra_allLevels.npz` | `calibration_<ts>.npz` | **The source data:** wavelengths, drive levels, every R/G/B/W spectrum, the dark spectrum, metadata (integration time), AW's raw-count curve and fit |
| *(not kept)* | `spectra_<ts>.csv` | the same spectra in long format (wavelength_nm, drive, colour, intensity), noFilter and 1xNDFilter only. Checked identical to the `.npz` (all 192 spectra, every value) and removed to save 17 MB; listed in `MANIFEST.csv` |
| `<run>_gammaCurve_meanRawCounts.csv/.png` | `gamma_curve_<ts>.*` | AW export: mean raw count over all 2048 pixels, dark offset included, per drive level |
| `<run>_gammaFit_meanRawCounts.csv` | `gamma_params_<ts>.csv` | AW's power-law fit to that raw-count curve |
| `<run>_spectra_fullDrive.csv` | `spectra_final_<ts>.csv` | AW export: spectra at full drive |
| `<run>_spectra_fullDrive_fibreCorrected.csv/.png` | `spectra_final_<ts>_corrected.*` | the same with the `correction_factor` column and the corrected spectra |
| `<run>_spectra_fullDrive_darkSubtracted_fibreCorrected.*` | `spectra_final_<ts>_darksub_corrected.*` | 3xNDFilter only: as above, dark-subtracted |
| `<run>_spectra_fullDrive_raw.png` | `spectra_max_<ts>.png` | AW plot of the raw full-drive spectra |
| `noFilter_gammaCurve_meanRawCounts_run111450.png` | `NO_FILTER/gamma_curve_20260515_111450.png` | a plot from an earlier run (111450) that was in the same folder |
| `notes/AWade_calibration_notes.md` | `AW-calibration-notes.pdf`, `FIL7TCalibration notes_.docx`, `(2) Calibration UCL _ Notion.pdf` | text transcript of AW's 7T notes and general method, without the figures. The three originals are not kept here; they are listed in `MANIFEST.csv` |

Notes on the originals:

- **Fits.** The `gammaFit_meanRawCounts` values are fits to raw counts, including the flat clipped top of each channel's curve and the dark offset. They are not luminance gammas, and the tables do not use them (see [ACH7T_calibration_plan.md](../../../ACH7T_calibration_plan.md), Section 2.2).
- **1xNDFilter corrected spectra.** `1xNDFilter_spectra_fullDrive_fibreCorrected.csv` is byte-identical to the noFilter one, i.e. it shows the noFilter spectra. Its `correction_factor` column, the only part used here, is the same in all four runs anyway.

## How the tables are made: AW's method

**Credit.** The luminance computation is Alex Wade's, from his toolbox [wadelab/oceanoptics-public](https://github.com/wadelab/oceanoptics-public). The data were measured with the same toolbox (`calibrate_screen.py`). `oceanoptics_public/estimate_luminance.py` is copied unchanged from commit `ed9b9fa`, together with its MIT `LICENSE`:

| File | SHA-256 (identical to the repository's) |
|---|---|
| `estimate_luminance.py` | `a4919b8a3bc0b5cf0b4dbc1201ceacf7536f689bc36215cf8e4bde06ac023087` |
| `LICENSE` | `bcf23b55f95b55686dc6b6013b92f17982262d3b7fae2e73e0ae121f9aa282b1` |

**What AW's toolbox already does, and what was needed here.**

- **`calibrate_screen.py`** (measurement) saves every spectrum. It also exports a raw-count gamma curve and fit: the mean spectrometer count, with no dark subtraction, fibre correction or V(λ). Those raw-count fits go into his PsychoPy monitor profile (`combine_calibrations.py`). They are not luminance gammas (below).
- **`estimate_luminance.py`** turns a spectrum into luminance properly: minus dark, ÷ integration time, × the fibre `correction_factor`, × CIE 1924 V(λ) (his tabulated values), integrated (trapezoid), then scaled to a photometer reading. His command-line tool does this for **one** drive level per call (default: full drive), to anchor absolute cd/m².
- **What the stimulus code needs** is luminance against drive for each channel. `build_tables.py` therefore calls AW's `luminance_index()` at **every** drive level. It uses the settings his tool uses when a correction file is given:
  - `count_basis='energy'`,
  - dark subtracted,
  - negatives *not* clipped,
  - the correction factor from `noFilter_spectra_fullDrive_fibreCorrected.csv`.

  It converts to cd/m² exactly as his `main()` does (scale = reference luminance ÷ reference index), with the reference **noFilter W at full drive = 952 cd/m²**. Because `luminance_index()` divides by integration time, one scale serves all four runs, so the filter tables are in absolute cd/m² as well.

`build_tables.py` adds no luminance maths of its own: only the loop, the CSV output and the checks. Drive = AW's `drive_levels` (0–1) × 255.

**Black level.** In `calibrate_screen.py`, AW's `dark` spectrum is the mean of the drive-0 R, G and B spectra, i.e. **the black screen**. The tables are therefore **luminance above the black screen** (drive 0 ≈ 0, within noise). The projector's own black level is not in these data. LCD projectors typically reach about 1/1000–1/2000 of white, here roughly 0.5–1 cd/m² unfiltered. Black adds the same amount to every stimulus and to the background.

To rebuild (Python ≥ 3.10 with numpy):

```bash
python3 build_tables.py
```

## Checks (from `tables/build_log.txt`)

| Check | Result |
|---|---|
| AW's raw-count curves (`gammaCurve_meanRawCounts`) recomputed from the raw spectra | identical (difference 0) in every run |
| `correction_factor` in the four runs' corrected files | identical |
| W at 255 against AW's notes | noFilter 952 (952), 1xNDFilter 143.8 (~143), 2xNDFilter 16.8 (~17–21), 3xNDFilter 2.32 (~1.8–2.5) |
| V-weighted R : G : B shares at full drive | 0.115 : 0.857 : 0.027, against 0.118 : 0.851 : 0.031 computed from AW's 5 nm fibre-corrected export |

AW's fibre-corrected export is dark-subtracted (its spectra match ours to within 1–2% in shape). The small difference in the shares most likely comes from that file being resampled to 5 nm: blue's narrow spectrum is the most sensitive to resampling. The tables use the full-resolution spectra. This does not affect isoluminance, which is set by each observer's flicker match; the tables supply each channel's curve shape.

## Using the tables

```matlab
cal = cal_FIL7T();        % noFilter (default); or cal_FIL7T('1xNDFilter'), '2xNDFilter', '3xNDFilter'
```

`cal_FIL7T.m` documents the model:
- luminance above black: L = Σ ΔL<sub>c</sub> (`cal.black` = 0, not measured);
- grey uses the W table, not R + G + B;
- `cal.d` gives the drive for a target luminance.

Things to keep in mind:

- **noFilter** is the table for the colour paradigm. Its clip points are G 206 and B 222; R keeps rising slowly to 255.
  - Compared with the uncorrected values in the calibration report (R 76.9 cd/m² at its clip), the fibre correction makes red brighter (≈ 112 cd/m² at 255). The predicted red drive that matches blue is therefore ≈ 115, not 134.
  - A colour grating built from these tables (blue peak 26.5 cd/m², red matched) has a residual luminance modulation of Michelson ≈ 0.01, the 8-bit limit, assuming R + B add. The grey with the same luminance is drive ≈ 52.
- **Filter tables** (1–3 filters) are noisier at low drive (small signal over long exposures). Their red-to-blue balance also differs from noFilter: the predicted red match is 123, 171 and 141 with 1, 2 and 3 filters. That is either some spectral non-neutrality of the filters or noise. **Use the filter tables for achromatic luminance only, not for colour ratios.**
- **Black level:** not measured (see above). The tables are luminance above the black screen.
- **R + B additivity was not measured.** See [ACH7T_calibration_plan.md](../../../ACH7T_calibration_plan.md), Section 5, step 1b.
