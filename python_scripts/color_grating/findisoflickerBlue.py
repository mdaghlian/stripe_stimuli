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
from utils import *

# =============================================================================
# 11. MAIN
# =============================================================================
def main():
    args = parse_args()
    cfg  = load_settings(args.settings)
    mon  = build_monitor(cfg)
    win  = build_window(cfg, mon)

    results = run_task(
        win,
        cfg,
        condition_name='blue',
    )

    save_results_yml(results, args.sub, args.ses, 'blue')

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