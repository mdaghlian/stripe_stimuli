function cal = cal_FIL7T(filter)
% cal_FIL7T  Luminance model of the FIL 7T projector (Epson EB-L1100U),
% from Alex Wade's spectroradiometer calibration of 15 May 2026.
%
%   cal = cal_FIL7T();            % no ND filter (colour paradigm)
%   cal = cal_FIL7T('3xNDFilter'); % 'noFilter', '1xNDFilter', '2xNDFilter' or '3xNDFilter'
%
%   'nxNDFilter' means n ND filters stacked in the light path. (AW's run
%   folders call these ND1-ND3, but by convention 'ND1' etc. name an optical
%   density, which is not meant here: each filter cuts luminance ~7-8x, i.e.
%   optical density ~0.9 each.) The scotopic pilot
%   used six filters, which were not measured.
%
%   Data, build script and provenance: calibration/FIL7T_20260515_AWade/
%   (README.md there). Copied from Dropbox pilot-clean/code/other/stripe7T/Calibration/:
%     noFilter    NO_FILTER/calibration_20260515_111744.npz  32 levels, 30 ms
%     1xNDFilter  ND1/calibration_20260515_113055.npz      16 levels, 240 ms
%     2xNDFilter  ND2/calibration_20260515_113923.npz      16 levels, 1.92 s
%     3xNDFilter  ND3/calibration_20260515_120813.npz      16 levels, 15.36 s
%   (AW's original folder names; his "best" runs). Spectra of full-field R, G, B and W (all channels
%   equal) at each drive level, probe at the eye position, identity gamma,
%   eye tracker off.
%
%   Luminance is computed with AW's own method: luminance_index() from his
%   estimate_luminance.py (https://github.com/wadelab/oceanoptics-public,
%   commit ed9b9fa, MIT licence; verbatim copy in
%   calibration/FIL7T_20260515_AWade/oceanoptics_public/), called at every
%   drive level: spectrum minus dark, / integration time, x AW's fibre
%   correction factor, x CIE 1924 V(lambda), integrated; scaled so that
%   noFilter W at 255 = 952 cd/m^2 (AW's value). One scale for all runs, so
%   the filter tables are in absolute cd/m^2 too. Checks against AW's files
%   and notes (tables/build_log.txt):
%     - AW's exported gamma curves (mean raw counts) are reproduced exactly;
%     - W at 255 with 1/2/3 filters: 143.8, 16.8, 2.32 cd/m^2 (AW: ~143,
%       ~17-21, ~1.8-2.5).
%   Tables: calibration/FIL7T_20260515_AWade/tables/cal_FIL7T_20260515_<filter>.csv
%   (drive, cd/m^2 for R G B W), made by build_tables.py in that folder.
%   See ACH7T_calibration_plan.md.
%
%   Valid for the projector in its standard configuration, as measured.
%   R + B additivity has not been measured (see the plan, step 1b). The filter
%   tables are noisier at low drive (long integration, small signal).
%
%   BLACK LEVEL: AW's 'dark' spectrum is the black screen (mean of the
%   drive-0 R, G, B spectra), so every table is luminance ABOVE the black
%   screen; the projector's own black level was not measured. cal.black is
%   therefore 0. A typical LCD projector black is roughly 1/1000-1/2000 of
%   white (here ~0.5-1 cd/m^2 unfiltered), which adds equally to every
%   stimulus and to the background.
%
%   Model: a stimulus with drive d_c in channel c has luminance above black
%       L = sum_c cal.dL(c, d_c)
%   For an
%   achromatic stimulus (R = G = B) use channel 'W', not the sum of R, G, B:
%   the display is not additive for R + G + B.
%
%   Fields and functions (drive in 0..255, luminance in cd/m^2):
%     cal.black          0: black level not measured (see above)
%     cal.dL(c, d)       luminance above black of channel c ('R','G','B','W') at drive d
%     cal.L(c, d)        luminance of a single-channel stimulus (= cal.black + dL)
%     cal.d(c, dLtarget) drive (not rounded) giving luminance dLtarget above black
%                        in channel c; clamped to [0, cal.dLmax.(c)]
%     cal.dLmax.(c)      largest luminance above black that channel c reaches
%     cal.clip.(c)       first measured drive on the plateau (within 1% of the top)
%     cal.table          the table [drive R G B W]
%     cal.filter, cal.source
%
%   This is displayModel(struct('type','FIL7T','filter',filter)); see
%   displayModel.m for other sources (any table file, gamma values, clip points).

if nargin < 1 || isempty(filter), filter = 'noFilter'; end
cal = displayModel(struct('type', 'FIL7T', 'filter', filter));
cal.source = sprintf('A. Wade, FIL 7T calibration 15 May 2026, %s run', filter);
end
