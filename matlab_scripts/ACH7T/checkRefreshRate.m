function ifi = checkRefreshRate(wptr, cfg)
% checkRefreshRate  Measured flip interval; error unless the refresh rate is
% cfg.expectedHz +/- cfg.toleranceHz.
%
%   ifi = checkRefreshRate(wptr, cfg)
%
%   The pre-rendered stimuli are designed so that each drift advances a
%   whole number of phase steps per frame at the expected refresh rate.
%   At another rate the speed would still be right (the run scripts take
%   phase from the flip timestamps), but the motion would be sampled
%   unevenly, so abort instead.

ifi = Screen('GetFlipInterval', wptr);
hz  = 1 / ifi;
fprintf('Measured refresh rate: %.2f Hz (flip interval %.3f ms)\n', hz, 1000*ifi);
if abs(hz - cfg.expectedHz) > cfg.toleranceHz
    error('Measured refresh rate is %.1f Hz but %g Hz is expected. Change the display mode or cfg.expectedHz.', ...
        hz, cfg.expectedHz);
end
end
