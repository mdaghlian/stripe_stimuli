"""Build luminance-vs-drive tables (tables/cal_FIL7T_20260515_<run>.csv) from
Alex Wade's FIL 7T calibration (original/), using AW's own luminance method.

The luminance computation is AW's, unmodified: oceanoptics_public/
estimate_luminance.py is a verbatim copy from
https://github.com/wadelab/oceanoptics-public (commit ed9b9fa, MIT licence,
(c) 2026 Alex Wade, Wade Lab, University of York; see oceanoptics_public/).
This script only drives it:

  * for every run, channel (R, G, B, W) and drive level it calls AW's
    luminance_index() with the settings his command-line tool uses when a
    spectral correction file is given: count_basis='energy', subtract_dark=True,
    clip_negative=False, spectral_correction = AW's correction_factor (from
    original/noFilter/noFilter_spectra_fullDrive_fibreCorrected.csv);
  * it converts the index to cd/m^2 exactly as AW's main() does
    (scale = reference luminance / reference index), with the reference
    = noFilter W at full drive = 952 cd/m^2 (AW's value, ET off). One scale
    for all runs, since luminance_index() divides by integration time;
  * it writes one CSV per run and a log of checks against AW's files and notes.

AW's estimate_luminance.py does this for one drive level per call (his tool
anchors absolute luminance); calling it at every level gives the per-channel
transfer curve that the stimulus code needs.

Note: AW's 'dark' spectrum is the mean of the drive-0 R, G and B spectra, i.e.
the black screen (calibrate_screen.py), so the tables are luminance ABOVE the
black screen. The projector's black level itself is not in these data.

Usage (Python >= 3.10, numpy):   python3 build_tables.py
"""
import csv
import os
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / 'oceanoptics_public'))
import estimate_luminance as aw  # noqa: E402  (AW's code, verbatim)

ORIG = HERE / 'original'
OUT = HERE / 'tables'
RUNS = ['noFilter', '1xNDFilter', '2xNDFilter', '3xNDFilter']   # 0-3 ND filters stacked (AW's NO_FILTER, ND1, ND2, ND3)
CHANNELS = 'RGBW'
REFERENCE = ('noFilter', 'W', 1.0, 952.0)   # run, colour, drive, cd/m^2 (AW's notes)
AW_W255 = {'noFilter': '944-967 (mean 952)', '1xNDFilter': '~143', '2xNDFilter': '~17-21', '3xNDFilter': '~1.8-2.5'}
CORRECTION_FILE = ORIG / 'noFilter' / 'noFilter_spectra_fullDrive_fibreCorrected.csv'
SETTINGS = dict(count_basis='energy', subtract_dark=True, clip_negative=False)


def index(cal, corr, colour, drive):
    value, actual = aw.luminance_index(calibration=cal, colour=colour, requested_drive=drive,
                                       spectral_correction=corr, **SETTINGS)
    assert actual == drive
    return value


def read_csv(path):
    with open(path) as f:
        rows = list(csv.reader(f))
    return rows[0], np.array(rows[1:], float)


def main():
    OUT.mkdir(exist_ok=True)
    log = []
    p = log.append
    corr = aw.load_spectral_correction(CORRECTION_FILE)
    cals = {run: aw.load_calibration(ORIG / run / f'{run}_spectra_allLevels.npz') for run in RUNS}

    ref_run, ref_colour, ref_drive, ref_lum = REFERENCE
    scale = ref_lum / index(cals[ref_run], corr, ref_colour, ref_drive)
    p(f'Method: AW estimate_luminance.luminance_index, settings {SETTINGS}')
    p(f'Spectral correction: {CORRECTION_FILE.relative_to(HERE)}')
    p(f'Reference: {ref_run} {ref_colour} drive {ref_drive} = {ref_lum} cd/m^2 -> scale {scale:.9g} cd/m^2 per index')

    # check: the four runs' fibre-correction files carry the same correction factor
    h0, a0 = read_csv(CORRECTION_FILE)
    for run, fn in [('1xNDFilter', '1xNDFilter_spectra_fullDrive_fibreCorrected.csv'),
                    ('2xNDFilter', '2xNDFilter_spectra_fullDrive_fibreCorrected.csv'),
                    ('3xNDFilter', '3xNDFilter_spectra_fullDrive_darkSubtracted_fibreCorrected.csv')]:
        h, a = read_csv(ORIG / run / fn)
        p(f'  {run} correction factor identical: '
          f'{a.shape == a0.shape and np.allclose(a[:, h.index("correction_factor")], a0[:, h0.index("correction_factor")])}')

    tables = {}
    p('')
    p('run         integration  levels  AW raw-count curve reproduced (max |diff|, counts)  W@255 (cd/m^2)  AW notes')
    for run, cal in cals.items():
        lum = {c: np.array([index(cal, corr, c, d) for d in cal.drive_levels]) * scale for c in CHANNELS}
        tables[run] = lum
        # check: AW's raw-count gamma curve (calibrate_screen.py: mean over pixels) from the same spectra
        z = np.load(cal.path, allow_pickle=True)
        aw_curve = z['gamma_curve'].item()
        err = max(np.max(np.abs(np.array([np.mean(s) for s in cal.spectra[c]]) - np.array(aw_curve[c]))) for c in CHANNELS)
        p(f'{run:11s} {cal.integration_us / 1000:8.0f} ms   {len(cal.drive_levels):4d}     {err:.3g}'
          f'{"":42s}{lum["W"][-1]:9.3f}      {AW_W255[run]}')
        cols = [cal.drive_levels * 255] + [lum[c] for c in CHANNELS]
        np.savetxt(OUT / f'cal_FIL7T_20260515_{run}.csv', np.column_stack(cols), delimiter=',',
                   header='drive,R_cdm2,G_cdm2,B_cdm2,W_cdm2', comments='', fmt='%.6g')

    # check: V-weighted R:G:B shares at full drive vs AW's fibre-corrected spectra file
    v = aw.photopic_weights(a0[:, 0], 'energy')
    awsh = np.array([np.trapezoid(a0[:, h0.index(c + '_corrected')] * v, a0[:, 0]) for c in 'RGB'])
    mine = np.array([tables['noFilter'][c][-1] for c in 'RGB'])
    p('')
    p('V-weighted R:G:B shares at full drive (noFilter)')
    p('  from AW fibre-corrected spectra file : %.3f %.3f %.3f' % tuple(awsh / awsh.sum()))
    p('  from these tables                    : %.3f %.3f %.3f' % tuple(mine / mine.sum()))
    p('')
    for run in RUNS:
        p(f'wrote tables/cal_FIL7T_20260515_{run}.csv  (R G B W at 255: '
          + ' '.join('%.4g' % tables[run][c][-1] for c in CHANNELS) + ' cd/m^2)')
    text = '\n'.join(log) + '\n'
    (OUT / 'build_log.txt').write_text(text)
    print(text, end='')


if __name__ == '__main__':
    main()
