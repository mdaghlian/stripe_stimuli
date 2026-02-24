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
    # mon.setGamma(cfg["display"].get("gamma", 1.0))  # default to 1.0 if not specified
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
# Simulates an annulus with two filled circles drawn back-to-front:
#   1. outer disc  – radius = outer_deg
#   2. inner disc  – radius = inner_deg, filled with background colour
#                    to punch a hole in the outer disc
# inner_deg / outer_deg are degrees of visual angle (eccentricity).
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

    # -- Resolve which colour is fixed and which is adjusted --
    # Which colour is fixed & which is adjusted
    fixed_cfg = cfg['conditions'][condition_name]['fixed']
    adjusted_cfg = cfg['conditions'][condition_name]['adjusted']
    if condition_name == 'blue':
        print("Condition: BLUE fixed, GREY adjusted")
        print("Setting same BLUE for all rings")
        FIXED_COLOR    = [fixed_cfg["color"]]*len(RING_PARAMS)  # replicate the fixed colour for all rings
    elif condition_name == 'red':
        # Use the fitted values from the blue condition to set the fixed colour for each ring in the red condition
        print("Condition: RED adjusted, GREY fixed")
        FIXED_COLOR = fitted_fixed_colors  # list of fitted scalars for each ring from the blue condition
    FIXED_LABEL    = fixed_cfg["label"]

    ADJ_BASE_COLOR = adjusted_cfg["color"]   # base RGB; one channel will be driven
    ADJ_LABEL      = adjusted_cfg["label"]
    ADJ_CHANNEL    = adjusted_cfg["channel"]
    ADJ_START      = adjusted_cfg["start"]
    ADJ_STEP       = adjusted_cfg["step"]
    ADJ_MIN        = adjusted_cfg["min"]
    ADJ_MAX        = adjusted_cfg["max"]

    # -- Measure actual monitor refresh rate; fall back to YAML value --
    try:
        measured_hz = win.getActualFrameRate(nIdentical=10, nMaxFrames=100, threshold=1)
        if measured_hz is None or not (20 < measured_hz < 500):
            raise ValueError(f"Implausible measured rate: {measured_hz}")
        MONITOR_REFRESH_HZ = measured_hz
        print(f"Measured refresh rate: {MONITOR_REFRESH_HZ:.2f} Hz")
    except Exception as e:
        MONITOR_REFRESH_HZ = FALLBACK_REFRESH_HZ
        print(f"Refresh rate measurement failed ({e}). Using fallback: {MONITOR_REFRESH_HZ} Hz")

    # Each full cycle = 2 phases (fixed colour + adjusted colour), so:
    UPDATE_FLICKER = max(1, round(MONITOR_REFRESH_HZ / (2 * FLICKER_RATE_HZ)))
    print(
        f"Flicker: {FLICKER_RATE_HZ} Hz target → {UPDATE_FLICKER} frames/phase "
        f"(actual: {MONITOR_REFRESH_HZ / UPDATE_FLICKER / 2:.2f} Hz)"
    )

    # -- Build stimuli --
    rings, fixation = build_stimuli(win, cfg)

    # -- Instructions --
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

    # -- Trials --
    trial_list = list(range(len(RING_PARAMS))) * REPETITIONS
    random.shuffle(trial_list)

    results = []

    for trial_num, ring_idx in enumerate(trial_list):

        ring_conf  = RING_PARAMS[ring_idx]
        inner_deg  = ring_conf["inner_deg"]
        outer_deg  = ring_conf["outer_deg"]
        label      = ring_conf["label"]
        outer_disc, inner_disc = rings[ring_idx]

        adj_value = ADJ_START   # scalar on −1 → +1 scale

        # Pre-trial cue
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

        # -- Flicker loop --
        frame_count  = 0
        phase_count  = 0   # increments every UPDATE_FLICKER frames
        running      = True

        while running:
            frame_count += 1

            if frame_count % UPDATE_FLICKER == 0:
                phase_count += 1
                if phase_count % 2 == 0:
                    # Phase A: show the fixed colour
                    outer_disc.fillColor = FIXED_COLOR[ring_idx]
                else:
                    # Phase B: show the current adjusted colour
                    outer_disc.fillColor = apply_adjustment(
                        adj_value, ADJ_BASE_COLOR, ADJ_CHANNEL
                    )

            # Draw all rings back-to-front; non-target rings stay as background
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

        # Compute final adjusted colour for logging
        final_color = apply_adjustment(adj_value, ADJ_BASE_COLOR, ADJ_CHANNEL)

        results.append({
            # "participant":          participant_id,
            # "session":              session_id,
            # "condition":            condition_name,
            # "adjusted_color":       ADJ_LABEL,
            "trial_number":         trial_num + 1,
            "fixed_color":          FIXED_COLOR[ring_idx],
            "ring_index":           ring_idx + 1,
            "ring_label":           label,
            "inner_deg":            inner_deg,
            "outer_deg":            outer_deg,
            "adjusted_scalar":      round(adj_value, 4),
            "adjusted_scalar_0_1":  round((adj_value + 1) / 2, 4),
            "final_color_R":        round(final_color[0], 4),
            "final_color_G":        round(final_color[1], 4),
            "final_color_B":        round(final_color[2], 4),
        })

    return results


# =============================================================================
# 10. Save CSV
# =============================================================================
def save_results(results, subject, session, condition_name):
    filename = f"./data/flicker_{subject}_s{session}_{condition_name}.csv"
    fieldnames = list(results[0].keys())
    with open(filename, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames)
        writer.writeheader()
        writer.writerows(results)
    print(f"Saved \u2192 {filename}")

def save_results_yml(results, subject, session, condition_name):
    filename = f"./data/flicker_{subject}_s{session}_{condition_name}.yml"
    dict2save = {
        'subject': subject,
        'session': session,
        'condition': condition_name,
        'results': results,
    }
    with open(filename, "w") as f:
        yaml.dump(dict2save, f)
    print(f"Saved \u2192 {filename}")

import yaml
import numpy as np
from scipy.optimize import curve_fit

def path(subject, session, condition, fitted=False):
    return f"./data/flicker_{subject}_s{session}_{condition}{'_fitted' if fitted else ''}.yml"

def ecc(row):
    return (float(row["inner_deg"]) + float(row["outer_deg"])) / 2.0

def log_func(x, a, b):
    return a * np.log(x) + b

def fit_params(x, y):
    (a, b), _ = curve_fit(log_func, np.asarray(x, float), np.asarray(y, float))
    return {"a": float(round(a, 4)), "b": float(round(b, 4))}

def fit_bluegrey_yml(subject, session):
    # load blue
    with open(path(subject, session, "blue"), "r") as f:
        blue = yaml.load(f, Loader=yaml.FullLoader)

    results = blue["results"]
    ecc_list = [ecc(r) for r in results]
    adj01 = [float(r["adjusted_scalar_0_1"]) for r in results]

    # fit
    pB = fit_params(ecc_list, adj01)

    # per-row fitted (0..1 scale) + ecc-wise predictions (-1..+1 scale)
    results_fitted = []
    for r in results:
        rr = dict(r)
        rr["fitted_scalar_0_1"] = float(round(log_func(ecc(r), pB["a"], pB["b"]), 4))
        results_fitted.append(rr)

    ecc_unique = sorted(set(ecc_list))
    fitted_data = {}
    for e in ecc_unique:
        fitted01 = float(round(log_func(e, pB["a"], pB["b"]), 4))
        fitted_data[e] = round(fitted01 * 2 - 1, 4)  # 0..1 -> -1..+1

    # save (IMPORTANT: include 'results' so combined fit can read it)
    out = {
        "subject": subject,
        "session": session,
        "condition": "blue_fitted",
        "fit_params": pB,
        "results": results,
        "results_fitted": results_fitted,
        "ecc_unique": ecc_unique,
        "fitted_data": fitted_data,
    }
    out_file = path(subject, session, "blue", fitted=True)
    with open(out_file, "w") as f:
        yaml.dump(out, f)
    print(f"Saved fitted data → {out_file}")

    # return triplets per ecc (for red task usage)
    return [[fitted_data[e]] * 3 for e in ecc_unique]

def fit_redgrey_yml(subject, session):
    # load blue originals to define eccList (consistent reference)
    with open(path(subject, session, "blue"), "r") as f:
        blue = yaml.load(f, Loader=yaml.FullLoader)
    results_blue = blue["results"]
    eccList = [ecc(r) for r in results_blue]

    # load blue fit params (fit if missing)
    blue_fit_file = path(subject, session, "blue", fitted=True)
    try:
        with open(blue_fit_file, "r") as f:
            blue_fit = yaml.load(f, Loader=yaml.FullLoader)
        pB = blue_fit["fit_params"]
    except FileNotFoundError:
        fit_bluegrey_yml(subject, session)
        with open(blue_fit_file, "r") as f:
            blue_fit = yaml.load(f, Loader=yaml.FullLoader)
        pB = blue_fit["fit_params"]

    # load + fit red against eccList
    with open(path(subject, session, "red"), "r") as f:
        red = yaml.load(f, Loader=yaml.FullLoader)
    results_red = red["results"]
    adj01_red = [float(r["adjusted_scalar_0_1"]) for r in results_red]
    pR = fit_params(eccList, adj01_red)

    # annotate per-row fitted scalars (0..1)
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
        "subject": subject,
        "session": session,
        "condition": "COMBINED",
        "eccList": eccList,
        "fit_paramsBlue": pB,
        "fit_paramsRed": pR,
        "fitted_data_blue": fitted_data_blue,
        "fitted_data_red": fitted_data_red,
    }

    out_file = path(subject, session, "COMBINED", fitted=True)
    with open(out_file, "w") as f:
        yaml.dump(combined, f)
    print(f"Saved combined fitted data → {out_file}")

    return combined