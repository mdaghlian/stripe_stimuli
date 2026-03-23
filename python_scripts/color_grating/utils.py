#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Flicker photometry isoluminance task — Blue vs Grey
blue condition : fixed = blue,     adjusted = grey  (all channels together)

Structure:
    - main()
    - parse_args()
    - load_settings()
    - build_monitor()
    - build_window()
    - build_stimuli()
    - run_task()
    - save_results()
"""

# =============================================================================
# 1. Imports
# =============================================================================
import csv
import os
import yaml
import random
import argparse
from psychopy import visual, core, event, monitors
import numpy as np
from scipy.optimize import curve_fit



# =============================================================================
# 2. Argument parsing
# =============================================================================
def parse_args():
    parser = argparse.ArgumentParser(description="Flicker Photometry Task")
    parser.add_argument("--sub",      required=True, help="Participant ID")
    parser.add_argument("--ses",      required=True, help="Session number/name")
    parser.add_argument("--settings", required=True, help="Path to settings.yml")
    return parser.parse_args()


# =============================================================================
# 3. Load YAML config
# =============================================================================
def load_settings(path):
    with open(path, "r") as f:
        return yaml.safe_load(f)

# =============================================================================
# 5. Apply adjustment
# Given the current scalar value and the adjusted colour's base RGB + channel
# spec, return the full [R, G, B] list with the appropriate channel(s) updated.
#
# channel "all" → achromatic:  R = G = B = value
# channel "R"   → only R       [value, base_g, base_b]
# channel "G"   → only G       [base_r, value, base_b]
# channel "B"   → only B       [base_r, base_g, value]
# =============================================================================
def apply_adjustment(value, base_color, channel):
    r, g, b = base_color
    ch = channel.upper()
    if ch == "ALL":
        return [value, value, value]
    elif ch == "R":
        print([value, g, b])
        return [value, g, b]
    elif ch == "G":
        return [r, value, b]
    elif ch == "B":
        return [r, g, value]
    else:
        raise ValueError(f"Unknown channel '{channel}'. Use 'all', 'R', 'G', or 'B'.")


# =============================================================================
# 6. Monitor creation
# Reads physical display properties from cfg["display"] and registers a
# temporary PsychoPy Monitor so that the window's deg ↔ pixel mapping is
# correct for this participant's setup.
# =============================================================================
def build_monitor(cfg):
    disp = cfg["display"]
    mon = monitors.Monitor(
        name="runtime_monitor",
        width=disp["screen_width_cm"],
        distance=disp["viewing_distance_cm"],
    )
    mon.setSizePix(cfg["window"]["size"])
    mon.save()   # saves temporarily; overwritten on each run
    return mon


# =============================================================================
# 7. Window creation
# =============================================================================
def build_window(cfg, mon):
    win_cfg = cfg["window"]
    win = visual.Window(
        size=win_cfg["size"],
        fullscr=win_cfg["fullscr"],
        color=cfg["background_color"],
        colorSpace="rgb",
        units="deg",
        allowGUI=False,
        monitor=mon,
    )
    win.mouseVisible = False
    return win


# =============================================================================
# 8. Ring stimulus maker
# =============================================================================
def make_ring(win, inner_deg, outer_deg, edges, bg):
    outer = visual.Circle(
        win, radius=outer_deg, edges=edges,
        fillColor=bg, lineColor=None,
        colorSpace="rgb", pos=(0, 0), autoLog=False, units="deg",
    )
    inner = visual.Circle(
        win, radius=max(inner_deg, 0.001), edges=edges,
        fillColor=bg, lineColor=None,
        colorSpace="rgb", pos=(0, 0), autoLog=False, units="deg",
    )
    return outer, inner


def build_stimuli(win, cfg):
    rings = []
    for ring in cfg["ring_params"]:
        rings.append(
            make_ring(
                win,
                inner_deg=ring["inner_deg"],
                outer_deg=ring["outer_deg"],
                edges=cfg["circle_edges"],
                bg=cfg["background_color"],
            )
        )
    fixation = visual.Circle(
        win, radius=0.1, fillColor=[1, 1, 1], lineColor=None, units="deg"
    )
    return rings, fixation


# =============================================================================
# 9. Main experiment loop
# =============================================================================
def run_task(win, cfg, condition_name, fitted_fixed_colors=None):

    BG_COLOR = cfg["background_color"]
    
    RING_PARAMS          = cfg["ring_params"]
    REPETITIONS          = cfg["repetitions"]
    FLICKER_RATE_HZ      = cfg["flicker"]["flicker_rate_hz"]
    FALLBACK_REFRESH_HZ  = cfg["flicker"]["monitor_refresh_hz"]

    fixed_cfg    = cfg['conditions'][condition_name]['fixed']
    adjusted_cfg = cfg['conditions'][condition_name]['adjusted']

    if condition_name == 'blue':
        print("Condition: BLUE fixed, GREY adjusted")
        print("Setting same BLUE for all rings")
        FIXED_COLOR = [fixed_cfg["color"]] * len(RING_PARAMS)
    elif condition_name == 'red':
        print("Condition: RED adjusted, GREY fixed")
        # fitted_fixed_colors is a list of per-ring RGB triplets in [-1,+1]
        # derived from the blue condition fit
        FIXED_COLOR = fitted_fixed_colors

    FIXED_LABEL    = fixed_cfg["label"]
    ADJ_BASE_COLOR = adjusted_cfg["color"]
    ADJ_LABEL      = adjusted_cfg["label"]
    ADJ_CHANNEL    = adjusted_cfg["channel"]
    ADJ_START      = adjusted_cfg["start"]
    ADJ_STEP       = adjusted_cfg["step"]
    ADJ_MIN        = adjusted_cfg["min"]
    ADJ_MAX        = adjusted_cfg["max"]

    # -- Measure actual monitor refresh rate --
    try:
        measured_hz = win.getActualFrameRate(nIdentical=10, nMaxFrames=100, threshold=1)
        if measured_hz is None or not (20 < measured_hz < 500):
            raise ValueError(f"Implausible measured rate: {measured_hz}")
        MONITOR_REFRESH_HZ = measured_hz
        print(f"Measured refresh rate: {MONITOR_REFRESH_HZ:.2f} Hz")
    except Exception as e:
        MONITOR_REFRESH_HZ = FALLBACK_REFRESH_HZ
        print(f"Refresh rate measurement failed ({e}). Using fallback: {MONITOR_REFRESH_HZ} Hz")

    UPDATE_FLICKER = max(1, round(MONITOR_REFRESH_HZ / (2 * FLICKER_RATE_HZ)))
    print(
        f"Flicker: {FLICKER_RATE_HZ} Hz target → {UPDATE_FLICKER} frames/phase "
        f"(actual: {MONITOR_REFRESH_HZ / UPDATE_FLICKER / 2:.2f} Hz)"
    )

    rings, fixation = build_stimuli(win, cfg)

    instructions = visual.TextStim(
        win,
        text=(
            f"FLICKER PHOTOMETRY TASK\n\n"
            f"The ring flickers between {FIXED_LABEL.upper()} and {ADJ_LABEL.upper()}.\n\n"
            f"\u2190 Make {ADJ_LABEL} DARKER\n"
            f"\u2192 Make {ADJ_LABEL} BRIGHTER\n\n"
            "SPACE = confirm   |   ESC = quit"
        ),
        color=[1, 1, 1], height=0.6, wrapWidth=26,
    )
    instructions.draw()
    win.flip()

    keys = event.waitKeys(keyList=["space", "escape"])
    if "escape" in keys:
        win.close()
        core.quit()

    trial_list = list(range(len(RING_PARAMS))) * REPETITIONS
    random.shuffle(trial_list)

    results = []

    for trial_num, ring_idx in enumerate(trial_list):

        ring_conf  = RING_PARAMS[ring_idx]
        inner_deg  = ring_conf["inner_deg"]
        outer_deg  = ring_conf["outer_deg"]
        label      = ring_conf["label"]
        outer_disc, inner_disc = rings[ring_idx]

        adj_value = ADJ_START

        cue = visual.TextStim(
            win,
            text=(
                f"Trial {trial_num + 1}/{len(trial_list)}\n"
                f"Ring: {label.upper()}  ({inner_deg}\u00b0\u2013{outer_deg}\u00b0 ecc.)\n\n"
                f"\u2190 {ADJ_LABEL} darker    \u2192 {ADJ_LABEL} brighter    SPACE = confirm"
            ),
            color=[1, 1, 1], height=0.65, wrapWidth=24,
        )
        cue.draw()
        win.flip()
        core.wait(2)
        event.clearEvents()

        frame_count  = 0
        phase_count  = 0
        running      = True

        while running:
            frame_count += 1

            if frame_count % UPDATE_FLICKER == 0:
                phase_count += 1
                if phase_count % 2 == 0:
                    outer_disc.fillColor = FIXED_COLOR[ring_idx]
                else:
                    outer_disc.fillColor = apply_adjustment(
                        adj_value, ADJ_BASE_COLOR, ADJ_CHANNEL
                    )

            for i in reversed(range(len(rings))):
                o, inn = rings[i]
                if i != ring_idx:
                    o.fillColor = BG_COLOR
                o.draw()
                inn.draw()

            fixation.draw()
            win.flip()

            keys = event.getKeys(keyList=["left", "right", "space", "escape"])
            for key in keys:
                if key == "escape":
                    win.close()
                    core.quit()
                elif key == "left":
                    adj_value = max(ADJ_MIN, adj_value - ADJ_STEP)
                elif key == "right":
                    adj_value = min(ADJ_MAX, adj_value + ADJ_STEP)
                elif key == "space":
                    running = False

        final_color = apply_adjustment(adj_value, ADJ_BASE_COLOR, ADJ_CHANNEL)

        results.append({
            "trial_number":         trial_num + 1,
            "fixed_color":          FIXED_COLOR[ring_idx],
            "ring_index":           ring_idx + 1,
            "ring_label":           label,
            "inner_deg":            inner_deg,
            "outer_deg":            outer_deg,
            "adjusted_scalar":      round(adj_value, 4),
            # 0..1 scale: PsychoPy's [-1,+1] → [0,1] for saving/fitting
            "adjusted_scalar_0_1":  round((adj_value + 1) / 2, 4),
            "final_color_R":        round(final_color[0], 4),
            "final_color_G":        round(final_color[1], 4),
            "final_color_B":        round(final_color[2], 4),
        })

    return results


# =============================================================================
# 10. Save
# =============================================================================
def save_results_yml(results, subject, session, condition_name):
    filename = f"./data/flicker_{subject}_s{session}_{condition_name}.yml"
    if not os.path.exists("./data"):
        os.makedirs("./data")
    dict2save = {
        'subject': subject,
        'session': session,
        'condition': condition_name,
        'results': results,
    }
    with open(filename, "w") as f:
        yaml.dump(dict2save, f)
    print(f"Saved \u2192 {filename}")


# =============================================================================
# 11. Curve fitting helpers
# =============================================================================

def path(subject, session, condition, fitted=False):
    return f"./data/flicker_{subject}_s{session}_{condition}{'_fitted' if fitted else ''}.yml"


def ecc(row):
    """Mean eccentricity of a ring in degrees."""
    return (float(row["inner_deg"]) + float(row["outer_deg"])) / 2.0


def log_func(x, a, b):
    """Logarithmic fit function: a * log(x) + b."""
    return a * np.log(np.asarray(x, dtype=float)) + b


def fit_params(x, y):
    (a, b), _ = curve_fit(log_func, np.asarray(x, float), np.asarray(y, float))
    return {"a": float(round(a, 4)), "b": float(round(b, 4))}


def fit_bluegrey_yml(subject, session):
    """
    Fit a log curve to blue-condition flicker photometry results.

    The adjusted_scalar_0_1 values are grey levels in [0,1] (mapped from
    PsychoPy's [-1,+1]) that appeared isoluminant to max blue at each
    eccentricity.

    Returns a list of per-ring RGB triplets (in PsychoPy [-1,+1] space)
    for use as FIXED_COLOR in the red condition.
    """
    with open(path(subject, session, "blue"), "r") as f:
        blue = yaml.load(f, Loader=yaml.FullLoader)

    results  = blue["results"]
    ecc_list = [ecc(r) for r in results]
    adj01    = [float(r["adjusted_scalar_0_1"]) for r in results]

    pB = fit_params(ecc_list, adj01)

    # Annotate each row with its fitted value
    results_fitted = []
    for r in results:
        rr = dict(r)
        rr["fitted_scalar_0_1"] = float(round(log_func(ecc(r), pB["a"], pB["b"]), 4))
        results_fitted.append(rr)

    # Per unique eccentricity: fitted value in [0,1] and in [-1,+1]
    ecc_unique  = sorted(set(ecc_list))
    fitted_data = {}   # ecc → scalar in [-1,+1] (PsychoPy space)
    for e in ecc_unique:
        fitted01        = float(round(log_func(e, pB["a"], pB["b"]), 4))
        fitted_data[e]  = round(fitted01 * 2 - 1, 4)   # [0,1] → [-1,+1]

    out = {
        "subject":          subject,
        "session":          session,
        "condition":        "blue_fitted",
        "fit_params_0_1":   pB,
        "results":          results,
        "results_fitted":   results_fitted,
        "ecc_unique":       ecc_unique,
        "fitted_data":      fitted_data,
    }
    out_file = path(subject, session, "blue", fitted=True)
    with open(out_file, "w") as f:
        yaml.dump(out, f)
    print(f"Saved fitted data → {out_file}")

    # Return per-ring RGB triplets in [-1,+1] for the red condition
    # Each ring uses its mean eccentricity to look up the fitted grey level
    ring_fitted_colors = []
    for r in results:
        e        = ecc(r)
        fitted01 = float(log_func(e, pB["a"], pB["b"]))
        fitted11 = fitted01 * 2 - 1          # [0,1] → [-1,+1]
        fitted11 = float(np.clip(fitted11, -1.0, 1.0))
        ring_fitted_colors.append([fitted11, fitted11, fitted11])

    return ring_fitted_colors


def fit_redgrey_yml(subject, session):
    """
    Fit a log curve to red-condition flicker photometry results and save
    a combined file containing both blue and red fit parameters.
    """
    # Load blue raw results for consistent eccentricity reference
    with open(path(subject, session, "blue"), "r") as f:
        blue = yaml.load(f, Loader=yaml.FullLoader)
    results_blue = blue["results"]
    ecc_list     = [ecc(r) for r in results_blue]

    # Load blue fit (run it first if the fitted file doesn't exist yet)
    blue_fit_file = path(subject, session, "blue", fitted=True)
    if not os.path.exists(blue_fit_file):
        fit_bluegrey_yml(subject, session)
    with open(blue_fit_file, "r") as f:
        blue_fit = yaml.load(f, Loader=yaml.FullLoader)
    pB = blue_fit["fit_params_0_1"]

    # Load and fit red results
    with open(path(subject, session, "red"), "r") as f:
        red = yaml.load(f, Loader=yaml.FullLoader)
    results_red = red["results"]
    ecc_list_red = [ecc(r) for r in results_red]
    adj01_red    = [float(r["adjusted_scalar_0_1"]) for r in results_red]
    pR           = fit_params(ecc_list_red, adj01_red)

    # Annotate rows with fitted scalars
    fitted_data_red = []
    for r in results_red:
        rr = dict(r)
        rr["fitted_scalar_0_1"] = float(round(log_func(ecc(r), pR["a"], pR["b"]), 4))
        fitted_data_red.append(rr)

    fitted_data_blue = []
    for r in results_blue:
        rr = dict(r)
        rr["fitted_scalar_0_1"] = float(round(log_func(ecc(r), pB["a"], pB["b"]), 4))
        fitted_data_blue.append(rr)

    combined = {
        "subject":              subject,
        "session":              session,
        "condition":            "COMBINED",
        "eccList":              ecc_list,
        "fit_paramsBlue_0_1":   pB,
        "fit_paramsRed_0_1":    pR,
        "fitted_data_blue":     fitted_data_blue,
        "fitted_data_red":      fitted_data_red,
    }

    out_file = path(subject, session, "COMBINED", fitted=True)
    with open(out_file, "w") as f:
        yaml.dump(combined, f)
    print(f"Saved combined fitted data → {out_file}")

    return combined


def screen_params(distance_cm, screen_cm, screen_px):
    """Returns (px_per_deg, screen_deg) for a given viewing geometry."""
    screen_deg  = 2 * np.degrees(np.arctan(screen_cm / (2 * distance_cm)))
    px_per_deg  = screen_px / screen_deg
    return px_per_deg, screen_deg