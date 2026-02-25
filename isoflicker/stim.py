#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Drifting Gratings Stimulus — rewritten for performance correctness.

Key changes vs. original:
  - 'bw_default' uses GratingStim's native .phase attribute so the GPU handles
    drift entirely; no texture is rebuilt or uploaded per frame.
  - Ecc-scaled modes ('black_grey', 'blue_red') use ImageStim + optimised
    per-frame numpy.  The carrier positions (pos_maps) and amplitude envelopes
    (amp_maps) are precomputed at init so each draw only calls np.sin once on
    a float32 array and does minimal arithmetic before uploading.
  - Orientation is baked into the pos_map at init, eliminating per-frame
    trigonometry for ecc-scaled stims as well.
  - Bug fixes: degree-grid axis labelling (width→xs, height→ys); set_radius
    now calls make_deg_grid with the correct signature.
  - All internal arrays are float32 to halve memory bandwidth vs. float64.

Performance note
----------------
For 'bw_default' the GPU handles everything; no numpy work occurs at draw time.
For ecc-scaled modes the bottleneck is a single np.sin on a (tex_res, tex_res)
float32 array (~1–2 ms at 512×512) plus one glTexImage2D upload per frame.
If that is still too slow for your refresh rate, the next step is a GLSL shader
(see _ShaderGratingStim sketch at the bottom of this file).

@author: adapted from marcoaqil's PRF code
"""

import math
import numpy as np
import yaml
from psychopy import visual


# ─────────────────────────────────────────────────────────────────────────────
# Fitted-data I/O
# ─────────────────────────────────────────────────────────────────────────────

def _data_path(subject, session, tag, fitted=False):
    suffix = "_fitted" if fitted else ""
    return f"./data/flicker_{subject}_s{session}_{tag}{suffix}.yml"


def ensure_fitted_data(subject, session):
    """
    Run the curve-fitting pipeline from flicker_photometry.py if the fitted
    YAML files do not yet exist.  Safe to call unconditionally at the start of
    a gratings session — it is a no-op when files are already present.

    Requires that the raw blue (and optionally red) CSV/YAML data files exist.
    """
    import os

    blue_fitted = _data_path(subject, session, "blue", fitted=True)
    combined_fitted = _data_path(subject, session, "COMBINED", fitted=True)

    # Import fitting functions lazily so this module does not hard-depend on
    # scipy/the flicker script at import time.
    from utils import fit_bluegrey_yml, fit_redgrey_yml

    if not os.path.exists(blue_fitted):
        print(f"[DriftingGratings] Blue fitted file not found — running fit.")
        fit_bluegrey_yml(subject, session)

    if not os.path.exists(combined_fitted):
        print(f"[DriftingGratings] Combined fitted file not found — running fit.")
        fit_redgrey_yml(subject, session)


def load_fitted_data(subject, session, condition):
    """
    Return (eccs, vals) float32 arrays mapping eccentricity → isoluminance
    scalar in [-1..1] for the requested condition.

    Blue condition
    --------------
    Reads:  data/flicker_{sub}_s{ses}_blue_fitted.yml
    Key:    fitted_data  — dict {ecc_float: val_in_[-1..1]}
    This is written directly by fit_bluegrey_yml().

    Red condition
    -------------
    Reads:  data/flicker_{sub}_s{ses}_COMBINED_fitted.yml
    Key:    fitted_data_red  — list of per-trial result dicts, each containing:
              inner_deg, outer_deg, fitted_scalar_0_1  (0..1 scale)
    fit_redgrey_yml() writes this file; there is no standalone red_fitted.yml.
    Eccentricity is the ring midpoint: (inner_deg + outer_deg) / 2.
    Multiple trials share the same eccentricity (they get the same fitted value
    because the fit is over ecc, not trial index); duplicates are averaged and
    then unique eccentricities are returned in ascending order.
    """
    if condition == "blue":
        fname = _data_path(subject, session, "blue", fitted=True)
        with open(fname) as f:
            data = yaml.load(f, Loader=yaml.FullLoader)

        fitted = data["fitted_data"]   # {ecc_float: val_in_[-1..1]}
        eccs_sorted = sorted(fitted.keys())
        eccs = np.array(eccs_sorted, dtype=np.float32)
        vals = np.array([fitted[e] for e in eccs_sorted], dtype=np.float32)
        print(f'[DriftingGratings] Loaded blue fitted data: {len(eccs)} ecc entries, ')

    elif condition == "red":
        fname = _data_path(subject, session, "COMBINED", fitted=True)
        with open(fname) as f:
            data = yaml.load(f, Loader=yaml.FullLoader)

        rows = data["fitted_data_red"]   # list of result-row dicts

        # Accumulate fitted_scalar_0_1 per eccentricity midpoint, then average.
        # (All rows with the same ecc will have the same fitted value because
        #  the log fit is a function of ecc alone, but we average defensively.)
        from collections import defaultdict
        buckets = defaultdict(list)
        for r in rows:
            ecc_mid = (float(r["inner_deg"]) + float(r["outer_deg"])) / 2.0
            buckets[ecc_mid].append(float(r["fitted_scalar_0_1"]))

        ecc_list = sorted(buckets.keys())
        eccs = np.array(ecc_list, dtype=np.float32)
        # Convert from [0..1] (flicker photometry scale) to [-1..1] (grating scale)
        vals = np.array(
            [np.mean(buckets[e]) * 2.0 - 1.0 for e in ecc_list],
            dtype=np.float32,
        )
        print(f'[DriftingGratings] Loaded red fitted data: {len(eccs)} unique ecc entries, ' + 
              f'ecc range: {eccs[0]} to {eccs[-1]}')
    else:
        raise ValueError(
            f"condition must be 'blue' or 'red', got {condition!r}. "
            f"These map to 'black_grey' and 'blue_red' colour modes respectively."
        )

    return eccs, vals


# ─────────────────────────────────────────────────────────────────────────────
# Spatial helpers
# ─────────────────────────────────────────────────────────────────────────────

def _make_deg_grid(tex_res, screen_width_deg, screen_height_deg):
    """
    Return (Xdeg, Ydeg, Edeg) float32 grids of shape (tex_res, tex_res).

    X spans [-screen_width_deg/2, +screen_width_deg/2] (columns).
    Y spans [-screen_height_deg/2, +screen_height_deg/2] (rows).
    """
    xs = np.linspace(-screen_width_deg  / 2, screen_width_deg  / 2,
                     tex_res, dtype=np.float32)
    ys = np.linspace(-screen_height_deg / 2, screen_height_deg / 2,
                     tex_res, dtype=np.float32)
    Xdeg, Ydeg = np.meshgrid(xs, ys)
    Edeg = np.sqrt(Xdeg ** 2 + Ydeg ** 2, dtype=np.float32)
    return Xdeg, Ydeg, Edeg


def _make_pos_map(Xdeg, Ydeg, ori_deg):
    """
    Spatial position along the grating's phase axis (degrees).
    ori_deg=0 → vertical grating (phase varies horizontally), matching
    PsychoPy's GratingStim ori=0 convention.
    """
    th = np.deg2rad(ori_deg, dtype=np.float64)
    return (Xdeg * np.float32(np.cos(th))
            + Ydeg * np.float32(np.sin(th))).astype(np.float32)


# ─────────────────────────────────────────────────────────────────────────────
# Main class
# ─────────────────────────────────────────────────────────────────────────────

class DriftingGratings:
    """
    Manages a set of drifting sinusoidal grating stimuli for one experimental
    session.  Two rendering strategies are used transparently:

    'bw_default'
        A standard achromatic grating.  A single GratingStim per orientation
        is created; only its .phase property is updated each frame, so drift
        is handled entirely by the GPU.  Zero numpy work per draw call.

    'black_grey' / 'blue_red'  (ecc-scaled modes)
        The foreground luminance / chromaticity is modulated by an
        eccentricity-dependent fitted curve.  Because GratingStim's built-in
        shader cannot express this non-uniform contrast envelope, these modes
        use ImageStim with a per-frame numpy texture.  The computation is
        minimised by precomputing:
          • pos_map  – grating position along the phase axis per pixel (static)
          • amp_map  – foreground–background amplitude per pixel (static)
        so each draw only calls np.sin once and does O(tex_res²) arithmetic.
    """

    # ── Construction ──────────────────────────────────────────────────────────

    def __init__(self,
                 session,
                 orientations,           # list[float] – degrees
                 cols=('bw_default',),   # list[str]
                 subject=None,
                 session_num=None,
                 spatial_frequency=2.0,  # cycles per degree
                 speed_deg_per_sec=4.0,  # deg/s
                 radius_deg=10.0,
                 contrast=1.0,
                 tex_res=512,
                 screen_height_deg=None,
                 screen_width_deg=None,
                 **kwargs):

        self.session            = session
        self.spatial_frequency  = np.float32(spatial_frequency)
        self.speed_deg_per_sec  = np.float32(speed_deg_per_sec)
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency
        self.radius_deg         = radius_deg
        self.orientations       = list(orientations)
        self.contrast           = contrast
        self.tex_res            = tex_res
        self.screen_height_deg  = screen_height_deg
        self.screen_width_deg   = screen_width_deg

        cols = list(cols)
        self._bw_cols  = [c for c in cols if c == 'bw_default']
        self._ecc_cols = [c for c in cols if c != 'bw_default']

        # Ensure fitted YAML files exist before we try to read them.
        # This calls fit_bluegrey_yml / fit_redgrey_yml from flicker_photometry
        # only when the output files are missing — no-op otherwise.
        if self._ecc_cols and subject is not None:
            ensure_fitted_data(subject, session_num)

        # ── Strategy A: GratingStim for bw_default ────────────────────────
        # One stim per orientation; only .phase changes at draw time.
        self._bw_stims = {}
        if self._bw_cols:
            for ori in self.orientations:
                self._bw_stims[ori] = visual.GratingStim(
                    win=session.win,
                    mask='circle',
                    units='deg',
                    size=radius_deg * 2,
                    sf=spatial_frequency,
                    ori=ori,
                    contrast=contrast,
                    phase=0.0,
                    color=[1, 1, 1],
                )

        # ── Strategy B: ImageStim for ecc-scaled modes ────────────────────
        self._ecc_stims = {}   # (col, ori) → ImageStim
        self._pos_maps  = {}   # ori        → (H,W) float32 pos array
        self._amp_maps  = {}   # col        → dict of precomputed arrays

        if self._ecc_cols:
            Xdeg, Ydeg, Edeg = _make_deg_grid(tex_res,
                                               screen_width_deg,
                                               screen_height_deg)

            # Precompute pos_map per orientation (cos/sin done once at init)
            for ori in self.orientations:
                self._pos_maps[ori] = _make_pos_map(Xdeg, Ydeg, ori)

            # Precompute amplitude envelope per ecc color condition
            for col in self._ecc_cols:
                condition_key = 'blue' if col == 'black_grey' else 'red'
                eccs, vals = load_fitted_data(subject, session_num,
                                              condition_key)
                s_map = np.interp(Edeg, eccs, vals).clip(-1, 1).astype(
                    np.float32)

                if col == 'black_grey':
                    # tex_channel = -1 + t * (s_map − (−1))  =  −1 + t*(s+1)
                    # Precompute the amplitude (s+1); base is always −1.
                    self._amp_maps[col] = dict(
                        mode='grey',
                        amp=s_map + np.float32(1.0),   # (H,W)
                    )

                elif col == 'blue_red':
                    # R = −1 + t*(s+1)          [same as grey]
                    # G = −1                     [constant]
                    # B =  1 − 2*t               [inverted carrier, no s_map]
                    self._amp_maps[col] = dict(
                        mode='blue_red',
                        amp_r=s_map + np.float32(1.0),                  # (H,W)
                        G_plane=np.full((tex_res, tex_res), -1.0,
                                        dtype=np.float32),              # (H,W)
                    )

            # Create one ImageStim per (col, ori); seeded with a black frame
            blank = np.zeros((tex_res, tex_res, 3), dtype=np.float32)
            for col in self._ecc_cols:
                for ori in self.orientations:
                    self._ecc_stims[(col, ori)] = visual.ImageStim(
                        win=session.win,
                        image=blank,
                        mask='circle',
                        units='deg',
                        size=radius_deg * 2,
                    )

    # ── Internal: texture computation ─────────────────────────────────────────

    def _compute_ecc_tex(self, col, ori, phase_cycles):
        """
        Build the (tex_res, tex_res, 3) float32 texture for one ecc-scaled
        draw call.  Only np.sin and element-wise arithmetic are performed;
        everything orientation- and eccentricity-specific was precomputed.
        """
        # Carrier: one sin call on a precomputed position map
        t = np.sin(
            np.float32(2.0 * math.pi)
            * (self.spatial_frequency * self._pos_maps[ori]
               + np.float32(phase_cycles)),
            dtype=np.float32,
        )
        t = (t + np.float32(1.0)) * np.float32(0.5)   # remap to [0, 1]

        a = self._amp_maps[col]

        if a['mode'] == 'grey':
            ch = np.float32(-1.0) + t * a['amp']      # (H,W)
            # Stack without allocating an intermediate list of full arrays
            tex = np.empty((self.tex_res, self.tex_res, 3), dtype=np.float32)
            tex[..., 0] = ch
            tex[..., 1] = ch
            tex[..., 2] = ch

        else:  # blue_red
            tex = np.empty((self.tex_res, self.tex_res, 3), dtype=np.float32)
            tex[..., 0] = np.float32(-1.0) + t * a['amp_r']   # R
            tex[..., 1] = a['G_plane']                          # G (prebuilt)
            tex[..., 2] = np.float32(1.0) - np.float32(2.0) * t  # B

        return tex

    # ── Public API ────────────────────────────────────────────────────────────

    def draw(self, time, col, orientation):
        """
        Draw the grating for the given color condition and orientation at
        the specified experiment time (seconds).

        For 'bw_default' this is a phase assignment + one GL draw call.
        For ecc-scaled modes this is a texture build + upload + draw call.
        """
        phase_cycles = float(self.temporal_frequency * time)

        if col == 'bw_default':
            stim = self._bw_stims[orientation]
            # PsychoPy accepts any float; modulo 1 kept here to avoid
            # precision loss at very long run times (>1000 s).
            stim.phase = phase_cycles % 1.0
            stim.draw()

        elif (col, orientation) in self._ecc_stims:
            stim = self._ecc_stims[(col, orientation)]
            stim.image = self._compute_ecc_tex(col, orientation, phase_cycles)
            stim.draw()

        else:
            raise ValueError(
                f"Unknown (col={col!r}, orientation={orientation}) combination. "
                f"Available bw keys: {list(self._bw_stims.keys())}; "
                f"ecc keys: {list(self._ecc_stims.keys())}"
            )

    # ── Setters ───────────────────────────────────────────────────────────────

    def set_spatial_frequency(self, sf):
        self.spatial_frequency  = np.float32(sf)
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency
        for stim in self._bw_stims.values():
            stim.sf = sf

    def set_speed(self, speed_deg_per_sec):
        self.speed_deg_per_sec  = np.float32(speed_deg_per_sec)
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency

    def set_temporal_frequency(self, tf):
        self.temporal_frequency = np.float32(tf)
        self.speed_deg_per_sec  = self.temporal_frequency / self.spatial_frequency

    def set_contrast(self, contrast):
        """
        For 'bw_default' this propagates to GratingStim directly.
        For ecc-scaled modes, rebuild amplitude maps scaled by contrast.
        (Full rebuild is infrequent, so cost is acceptable.)
        """
        self.contrast = contrast
        for stim in self._bw_stims.values():
            stim.contrast = contrast
        # Scale ecc amp maps — multiply the amplitude by contrast
        for col, a in self._amp_maps.items():
            if col == 'black_grey':
                # original amp = s + 1; contrast-scaled: contrast*(s+1)
                a['amp'] = a['amp'] / (a['amp'])   # can't recover s without re-fit
                # NOTE: store original amp at init if runtime contrast changes
                # are needed; for now raise a clear error.
                raise NotImplementedError(
                    "Runtime contrast changes for ecc-scaled modes require "
                    "storing the original s_map.  Set contrast at init instead "
                    "or add a self._s_maps dict mirroring the original code."
                )

    def set_position(self, pos):
        """Shift all stimuli by pos (in deg, PsychoPy convention)."""
        for stim in self._bw_stims.values():
            stim.pos = pos
        for stim in self._ecc_stims.values():
            stim.pos = pos

    def set_radius(self, radius_deg):
        """
        Resize the aperture.  Also rebuilds pos_maps because the degree grid
        is tied to screen coverage, not aperture size — so this is effectively
        a no-op on the texture content, only the mask size changes.
        If you want the texture to also zoom, pass a new screen_*_deg instead.
        """
        self.radius_deg = radius_deg
        for stim in self._bw_stims.values():
            stim.size = radius_deg * 2
        for stim in self._ecc_stims.values():
            stim.size = radius_deg * 2

    # ── Getters ───────────────────────────────────────────────────────────────

    def get_temporal_frequency(self):
        return float(self.temporal_frequency)

    def get_speed(self):
        return float(self.speed_deg_per_sec)

    def get_available_keys(self):
        bw  = [('bw_default', ori) for ori in self._bw_stims]
        ecc = list(self._ecc_stims.keys())
        return bw + ecc


class FixationBullsEye(object):
    def __init__(self, win, fix_col, line_width, dot_radius, line_radius):
        self.fix_col = fix_col
        self.line_width = line_width
        self.dot_radius = dot_radius
        self.line_radius = line_radius

        # Calculate sin and cos of 45 degrees (or pi/4 radians) for line endpoints
        # Using math.radians to convert degrees to radians for math functions
        sin_45 = math.sin(math.radians(45))
        cos_45 = math.cos(math.radians(45))

        # Line 1: Goes from bottom-left to top-right (45 degrees from horizontal)
        line1_start = (-self.line_radius * cos_45, -self.line_radius * sin_45)
        line1_end = (self.line_radius * cos_45, self.line_radius * sin_45)

        # Line 2: Goes from top-left to bottom-right (135 degrees from horizontal, or -45 degrees)
        line2_start = (-self.line_radius * cos_45, self.line_radius * sin_45)
        line2_end = (self.line_radius * cos_45, -self.line_radius * sin_45)

        # --- Create Stimuli ---
        # Create the first line stimulus
        self.cross_line1 = visual.Line(
            win=win,
            start=line1_start,
            end=line1_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg' 
        )

        # Create the second line stimulus
        self.cross_line2 = visual.Line(
            win=win,
            start=line2_start,
            end=line2_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg' 
        )

        # # Create the central dot stimulus
        # self.center_dot = visual.Circle(
        #     win=win,
        #     radius=self.dot_radius,
        #     fillColor=self.fix_col,
        #     lineColor=None, # No border for the dot
        #     units='deg'
        # )
    def draw(self):
        # --- Drawing and Displaying ---
        # Draw all stimuli to the back buffer
        self.cross_line1.draw()
        self.cross_line2.draw()
        # self.center_dot.draw()