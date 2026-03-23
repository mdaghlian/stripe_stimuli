#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np
from utils import *


def main():
    parser = argparse.ArgumentParser(description="Flicker Photometry Task")
    parser.add_argument("--dist-cm",type=float)
    parser.add_argument("--screen-cm",type=float)
    parser.add_argument("--screen-pix", type=float)
    args = parser.parse_args()
    px_per_deg, screen_deg = screen_params(args.dist_cm, args.screen_cm, args.screen_pix)
    print(f'Screen distance = {args.dist_cm}')
    print(f'Screen in pix {args.screen_pix}')
    print(f'Screen in cm {args.screen_cm}')
    print(f'Screen in deg {screen_deg:.3f}')
    print(f'Pix per deg {px_per_deg:.3f}')
    print(f'')
    return parser.parse_args()

if __name__ == "__main__":
    main()