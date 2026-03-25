#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Drifting Gratings Stimulus.

Rendering strategies
--------------------
'bw_default'
    Standard achromatic GratingStim; only .phase is updated per frame.
    Zero numpy work at draw time.

'black_grey'
    Eccentricity-scaled achromatic grating.  The carrier is a BIPOLAR sine
    in [-1,+1], centred on the grey background (0 in PsychoPy space).
    s_11 is the fitted isoluminant-grey level converted to [-1,+1].
    The grating swings symmetrically: dark trough = -s_11, bright peak = +s_11.

    tex = carrier * s_11
    where carrier = sin(2π*(sf*pos + phase))  ∈ [-1, +1]

'blue_red'
    Colour-opponent grating.  Red and blue are phase-inverted relative to
    each other.  Red is amplitude-scaled by the fitted isoluminant red level
    (s_11_r); blue spans the full [-1,+1] range because during photometry
    blue was always at maximum (no eccentricity correction needed).

    R =  carrier * s_11_r     (centred on bg, amplitude = isoluminant red)
    G = -1                    (always off)
    B = -carrier              (full range, phase-inverted)
"""

import math
import numpy as np
import yaml
from psychopy import visual
from utils import log_func


# ─────────────────────────────────────────────────────────────────────────────
# Fitted-data I/O
# ─────────────────────────────────────────────────────────────────────────────

def _data_path(subject, session, tag, fitted=False):
    suffix = "_fitted" if fitted else ""
    return f"./data/flicker_{subject}_s{session}_{tag}{suffix}.yml"


def load_fitted_0_1_coefficients(subject, session, condition):
    """
    Load log-fit coefficients (a, b) for the requested condition from the
    COMBINED fitted file.

    Parameters
    ----------
    condition : str
        'blue' or 'red'

    Returns
    -------
    dict with keys 'a' and 'b'
    """
    fname = _data_path(subject, session, "COMBINED", fitted=True)
    with open(fname) as f:
        data = yaml.load(f, Loader=yaml.FullLoader)

    condition = condition.lower()
    if condition == 'blue':
        return data["fit_paramsBlue_0_1"]
    elif condition == 'red':
        return data["fit_paramsRed_0_1"]   # fixed: was incorrectly loading Blue
    else:
        raise ValueError(f"Unknown condition '{condition}'. Use 'blue' or 'red'.")


# ─────────────────────────────────────────────────────────────────────────────
# Spatial helpers
# ─────────────────────────────────────────────────────────────────────────────

def _make_deg_grid(tex_res, screen_width_deg, screen_height_deg):
    """
    Return (Xdeg, Ydeg, Edeg) float32 grids of shape (tex_res, tex_res).

    X spans [-screen_width_deg/2,  +screen_width_deg/2]  (columns).
    Y spans [-screen_height_deg/2, +screen_height_deg/2] (rows).
    Edeg is the eccentricity (distance from centre) in degrees.
    """
    xs = np.linspace(-screen_width_deg  / 2,  screen_width_deg  / 2,
                     tex_res, dtype=np.float32)
    ys = np.linspace(-screen_height_deg / 2,  screen_height_deg / 2,
                     tex_res, dtype=np.float32)
    Xdeg, Ydeg = np.meshgrid(xs, ys)
    Edeg = np.sqrt(Xdeg ** 2 + Ydeg ** 2).astype(np.float32)
    # Avoid log(0) at the fovea — clamp to a small positive value
    Edeg = np.where(Edeg < 1e-4, np.float32(1e-4), Edeg)
    return Xdeg, Ydeg, Edeg


def _make_pos_map(Xdeg, Ydeg, ori_deg):
    """
    Spatial position (degrees) along the grating's phase axis.
    ori_deg=0 → vertical grating (phase varies horizontally), matching
    PsychoPy's GratingStim ori=0 convention.
    """
    th = np.deg2rad(ori_deg)
    return (Xdeg * np.float32(np.cos(th))
            + Ydeg * np.float32(np.sin(th))).astype(np.float32)


# ─────────────────────────────────────────────────────────────────────────────
# Main class
# ─────────────────────────────────────────────────────────────────────────────

class DriftingGratings:
    """
    Manages drifting sinusoidal grating stimuli for one experimental session.
    """

    def __init__(self,
                 session,
                 orientations,               # list[float] – degrees
                 cols=('bw_default',),       # list[str]
                 subject=None,
                 session_num=None,
                 spatial_frequency=2.0,      # cycles per degree
                 speed_deg_per_sec=4.0,
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

        # Store original s_maps so contrast can be re-applied at runtime
        self._s_maps = {}

        cols = list(cols)
        self._bw_cols  = [c for c in cols if c == 'bw_default']
        self._ecc_cols = [c for c in cols if c != 'bw_default']

        # ── Strategy A: GratingStim for bw_default ────────────────────────
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
        self._pos_maps  = {}   # ori        → (H,W) float32 position array
        self._amp_maps  = {}   # col        → dict of precomputed arrays

        if self._ecc_cols:
            if screen_width_deg is None or screen_height_deg is None:
                raise ValueError(
                    "screen_width_deg and screen_height_deg must be provided "
                    "for ecc-scaled colour modes."
                )

            Xdeg, Ydeg, Edeg = _make_deg_grid(tex_res,
                                               screen_width_deg,
                                               screen_height_deg)

            # Precompute pos_map per orientation (trig done once at init)
            for ori in self.orientations:
                self._pos_maps[ori] = _make_pos_map(Xdeg, Ydeg, ori)

            # Precompute amplitude maps per colour condition
            for col in self._ecc_cols:
                condition_key = 'blue' if col == 'black_grey' else 'red'
                pars  = load_fitted_0_1_coefficients(subject, session_num,
                                                     condition_key)
                # s_map: fitted isoluminant level in [0,1] at every pixel
                s_map = log_func(Edeg, pars["a"], pars["b"]).astype(np.float32)
                s_map = np.clip(s_map, 0.0, 1.0)

                # Store raw s_map so contrast changes can rebuild s_11
                self._s_maps[col] = s_map

                if col == 'black_grey':
                    # s_map is in [0,1]; convert to [-1,+1] to get the
                    # amplitude of the bipolar carrier.
                    # carrier * s_11 swings between -s_11 and +s_11,
                    # centred on background (0).
                    s_11 = s_map * np.float32(2.0) - np.float32(1.0)
                    self._amp_maps[col] = dict(
                        mode='grey',
                        s_11=s_11 * np.float32(contrast),
                    )

                elif col == 'blue_red':
                    # Same bipolar logic for red.
                    # Blue needs no s_map — it was always max during photometry,
                    # so it just uses the raw carrier inverted.
                    s_11_r = s_map * np.float32(2.0) - np.float32(1.0)
                    self._amp_maps[col] = dict(
                        mode='blue_red',
                        s_11_r=s_11_r * np.float32(contrast),
                    )

                else:
                    raise ValueError(
                        f"Unknown colour mode '{col}'. "
                        "Use 'bw_default', 'black_grey', or 'blue_red'."
                    )

            # Create one ImageStim per (col, ori); seeded with a grey frame
            blank = np.zeros((tex_res, tex_res, 3), dtype=np.float32)
            for col in self._ecc_cols:
                for ori in self.orientations:
                    self._ecc_stims[(col, ori)] = visual.ImageStim(
                        win=session.win,
                        image=blank,
                        # mask='circle',
                        # units='deg',
                        # size=radius_deg * 2,
                    )

    # ── Internal: texture computation ─────────────────────────────────────────

    def _compute_ecc_tex(self, col, ori, phase_cycles):
        """
        Build the (tex_res, tex_res, 3) float32 texture for one ecc-scaled
        draw call.

        The carrier is kept BIPOLAR in [-1,+1].  Multiplying by s_11 (which
        is also in [-1,+1]) gives a grating that swings symmetrically around
        the grey background (0), with per-pixel amplitude set by the
        eccentricity fit.
        """
        # Bipolar carrier: stays in [-1, +1]
        carrier = np.sin(
            np.float32(2.0 * math.pi)
            * (self.spatial_frequency * self._pos_maps[ori]
               + np.float32(phase_cycles)),
            dtype=np.float32,
        )   # shape (H, W), range [-1, +1]

        a   = self._amp_maps[col]
        tex = np.empty((self.tex_res, self.tex_res, 3), dtype=np.float32)

        if a['mode'] == 'grey':
            # Swing around background (0): dark = -s_11, bright = +s_11
            ch = carrier * a['s_11']
            tex[..., 0] = ch
            tex[..., 1] = ch
            tex[..., 2] = ch

        else:  # blue_red
            # R: swings ±s_11_r around background
            # G: always off (-1)
            # B: phase-inverted, full range (no eccentricity scaling needed)
            tex[..., 0] =  carrier * a['s_11_r']
            tex[..., 1] =  np.float32(-1.0)
            tex[..., 2] = -carrier                  # full [-1,+1], inverted

        return tex

    # ── Public API ────────────────────────────────────────────────────────────

    def draw(self, time, col, orientation):
        """
        Draw the grating for the given colour condition and orientation at
        the specified experiment time (seconds).
        """
        phase_cycles = float(self.temporal_frequency * time)

        if col == 'bw_default':
            stim = self._bw_stims[orientation]
            stim.phase = phase_cycles % 1.0
            stim.draw()
            

        elif (col, orientation) in self._ecc_stims:
            stim = self._ecc_stims[(col, orientation)]
            stim.image = self._compute_ecc_tex(col, orientation, phase_cycles)
            stim.draw()

        # else:
        #     raise ValueError(
        #         f"Unknown (col={col!r}, orientation={orientation}) combination.\n"
        #         f"Available bw keys:  {list(self._bw_stims.keys())}\n"
        #         f"Available ecc keys: {list(self._ecc_stims.keys())}"
        #     )

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
        Update contrast for all conditions.
        For 'bw_default' this propagates directly to GratingStim.
        For ecc-scaled modes, s_11 is rebuilt from the stored raw s_map.
        """
        self.contrast = contrast
        for stim in self._bw_stims.values():
            stim.contrast = contrast
        for col, a in self._amp_maps.items():
            s_map = self._s_maps[col]
            s_11  = (s_map * np.float32(2.0) - np.float32(1.0)) * np.float32(contrast)
            if a['mode'] == 'grey':
                a['s_11'] = s_11
            else:  # blue_red
                a['s_11_r'] = s_11

    def set_position(self, pos):
        """Shift all stimuli by pos (degrees, PsychoPy convention)."""
        for stim in self._bw_stims.values():
            stim.pos = pos
        for stim in self._ecc_stims.values():
            stim.pos = pos

    def set_radius(self, radius_deg):
        """Resize the circular aperture."""
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


# ─────────────────────────────────────────────────────────────────────────────
# Fixation
# ─────────────────────────────────────────────────────────────────────────────

class FixationBullsEye(object):
    def __init__(self, win, fix_col, line_width, dot_radius, line_radius):
        self.fix_col     = fix_col
        self.line_width  = line_width
        self.dot_radius  = dot_radius
        self.line_radius = line_radius

        sin_45 = math.sin(math.radians(45))
        cos_45 = math.cos(math.radians(45))

        line1_start = (-self.line_radius * cos_45, -self.line_radius * sin_45)
        line1_end   = ( self.line_radius * cos_45,  self.line_radius * sin_45)
        line2_start = (-self.line_radius * cos_45,  self.line_radius * sin_45)
        line2_end   = ( self.line_radius * cos_45, -self.line_radius * sin_45)

        self.cross_line1 = visual.Line(
            win=win,
            start=line1_start, end=line1_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg',
        )
        self.cross_line2 = visual.Line(
            win=win,
            start=line2_start, end=line2_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg',
        )

    def draw(self):
        self.cross_line1.draw()
        self.cross_line2.draw()