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

def load_bluegrey_yml(subject, session):
    filename = f"./data/flicker_{subject}_s{session}_blue.yml"
    with open(filename, "r") as f:
        return yaml.load(f, Loader=yaml.FullLoader)
    
def fit_bluegrey_yml(subject, session):
    # Fit the blue data log function
    data = load_bluegrey_yml(subject, session)
    # Extract eccentricity and adjusted scalar values
    results = data['results']
    ecc_list = [(float(row["inner_deg"]) + float(row["outer_deg"])) / 2 for row in results]
    ecc = list(set(ecc_list))  # unique eccentricity values
    ecc.sort()  # ensure sorted by eccentricity
    adj_scalar = [float(row["adjusted_scalar_0_1"]) for row in results]

    # Fit a logarithmic function to the data
    def log_func(x, a, b):
        return a * np.log(x) + b
    popt, _ = curve_fit(log_func, ecc_list, adj_scalar)
    # Make new yml with fitted values + predictions + original data
    fitted_data = {}
    for tecc in ecc:
        fitted_scalar = log_func(tecc, *popt)
        adj01 = float(round(fitted_scalar, 4))
        # now convert back to −1 → +1 scale for use in the red task
        adj = round(adj01 * 2 - 1, 4)
        fitted_data[tecc] = adj

    fitted_filename = f"./data/flicker_{subject}_s{session}_blue_fitted.yml"
    dict2save = {
        'subject': subject,
        'session': session,
        'condition': 'blue_fitted',
        'fit_params': {
            'a': float(round(popt[0], 4)),
            'b': float(round(popt[1], 4)),
        },
        'fitted_data' : fitted_data,
    }
    with open(fitted_filename, "w") as f:
        yaml.dump(dict2save, f)
    print(f"Saved fitted data \u2192 {fitted_filename}")
    # Return the ecc-wise fitted scalar values for use in the red task
    # {row["ring_index"]: row["fitted_scalar_0_1"] for row in fitted_data}
    return [[fitted_data[tecc], fitted_data[tecc], fitted_data[tecc]] for tecc in ecc]
     
def fit_redgrey_yml(subject, session):
    dict2save = {
        'subject': subject,
        'session': session,
        'condition': 'COMBINED',
        'fit_paramsGrey': [], 
        'fit_paramsRed': [],
        'eccList': [],
    }
    # Load the blue fitted data
    with open(f"./data/flicker_{subject}_s{session}_blue_fitted.yml", "r") as f:
        data_blue = yaml.load(f, Loader=yaml.FullLoader)
    dict2save['fit_paramsBlue'] = data_blue['fit_params'].copy()

    # Extract eccentricity and adjusted scalar values for both conditions
    results_blue = data_blue['results']
    eccList = [(float(row["inner_deg"]) + float(row["outer_deg"])) / 2 for row in results_blue]
    dict2save['eccList'] = eccList

    # Fit the red data log function
    filename = f"./data/flicker_{subject}_s{session}_red.yml"
    with open(filename, "r") as f:
        data_red = yaml.load(f, Loader=yaml.FullLoader)
    results_red = data_red['results']
    adj_scalar_red = [float(row["adjusted_scalar_0_1"]) for row in results_red]
    def log_func(x, a, b):
        return a * np.log(x) + b
    popt_red, _ = curve_fit(log_func, eccList, adj_scalar_red)
    dict2save['fit_paramsRed'] = {
        'a': float(round(popt_red[0], 4)),
        'b': float(round(popt_red[1], 4)),
    }
    # Make new yml with fitted values + predictions + original data for red condition
    fitted_data_red = []
    for row in results_red:
        ecc_value = (float(row["inner_deg"]) + float(row["outer_deg"])) / 2
        fitted_scalar = log_func(ecc_value, *popt_red)
        row["fitted_scalar_0_1"] = float(round(fitted_scalar, 4))
        fitted_data_red.append(row)
    fitted_data_blue = []
    for row in results_blue:
        ecc_value = (float(row["inner_deg"]) + float(row["outer_deg"])) / 2
        fitted_scalar = log_func(ecc_value, *dict2save['fit_paramsBlue'].values())
        row["fitted_scalar_0_1"] = float(round(fitted_scalar, 4))
        fitted_data_blue.append(row)
    fitted_filename_all = f"./data/flicker_{subject}_s{session}_COMBINED_fitted.yml"
    dict2save['fitted_data_red'] = fitted_data_red
    dict2save['fitted_data_blue'] = fitted_data_blue
    with open(fitted_filename_all, "w") as f:
        yaml.dump(dict2save, f)
    print(f"Saved combined fitted data \u2192 {fitted_filename_all}")
