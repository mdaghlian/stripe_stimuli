#!/usr/bin/env python
# -*- coding: utf-8 -*-
# =============================================================================
# 1. Imports
# =============================================================================
import csv
import yaml
import random
import argparse
from psychopy import visual, core, event, monitors
import numpy as np
from utils import *
     
# =============================================================================
# MAIN
# =============================================================================
def main():
    args = parse_args()

    cfg  = load_settings(args.settings)
    fitted_fixed_colors = fit_bluegrey_yml(args.sub, args.ses)
    print("Fixed Grey at each eccentricity, set using the blue:\n", fitted_fixed_colors)
    print(len(fitted_fixed_colors), "rings with fitted parameters")

    mon  = build_monitor(cfg)
    win  = build_window(cfg, mon)

    results = run_task(
        win,
        cfg,
        condition_name='red',
        fitted_fixed_colors=fitted_fixed_colors,  # Pass the fitted scalars from the blue condition to configure the fixed colour in the red condition
     )

    save_results_yml(results, args.sub, args.ses, 'red')
    fit_redgrey_yml(args.sub, args.ses)
    end = visual.TextStim(win, text="Task complete.\nPress a key to exit.")
    end.draw()
    win.flip()
    event.waitKeys()
    win.close()
    core.quit()


# =============================================================================
# 12. Entry point
# =============================================================================
if __name__ == "__main__":
    main()