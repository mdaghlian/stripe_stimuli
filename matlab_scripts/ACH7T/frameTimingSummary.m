function ft = frameTimingSummary(flipT, missed, ifi)
% frameTimingSummary  Dropped-frame QC from the logged flip times.
%
%   ft = frameTimingSummary(flipT, missed, ifi)
%
%   flipT   Screen('Flip') StimulusOnsetTime - t0 of every frame (s)
%   missed  Screen('Flip') 4th output of every frame (> 0: PTB thinks the
%           flip missed its deadline)
%   ifi     measured flip interval (s)
%
%   ft.nFrames, ft.duration_s
%   ft.nLate        frame intervals > 1.5 x ifi (a frame was shown for
%                   two or more refreshes, i.e. dropped frames)
%   ft.nDropped     refreshes lost in total, sum(round(interval/ifi) - 1)
%   ft.lateAt_s     time (s since trigger 1) of each late frame
%   ft.maxInterval_ms, ft.meanInterval_ms, ft.sdInterval_ms
%   ft.nMissedPTB   frames PTB flagged as missed
% Printed as one line.

flipT = flipT(:); missed = missed(:);
d = diff(flipT);
late = d > 1.5 * ifi;
ft = struct();
ft.nFrames         = numel(flipT);
ft.duration_s      = flipT(end) - flipT(1) + ifi;
ft.nLate           = sum(late);
ft.nDropped        = sum(max(round(d / ifi) - 1, 0));
ft.lateAt_s        = flipT([false; late]);
ft.maxInterval_ms  = 1000 * max(d);
ft.meanInterval_ms = 1000 * mean(d);
ft.sdInterval_ms   = 1000 * std(d);
ft.nMissedPTB      = sum(missed > 0);
fprintf('Frames: %d, interval %.3f +/- %.3f ms (max %.1f ms); late frames %d (%d refreshes dropped); PTB missed flags %d\n', ...
    ft.nFrames, ft.meanInterval_ms, ft.sdInterval_ms, ft.maxInterval_ms, ft.nLate, ft.nDropped, ft.nMissedPTB);
end
