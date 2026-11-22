function info = useIdentityGamma(wptr)
% useIdentityGamma  Back up the current gamma tables, load an identity
% table on the window's screen, and read it back.
%
%   info = useIdentityGamma(wptr)     % after OpenWindow; call RestoreCluts on exit
%
%   The FIL 7T display was calibrated (and the isoluminance tasks run) with
%   an identity gamma table, so the drive values in the stimuli only mean
%   what the display model says under that table. Without this, the run
%   scripts use whatever table the OS or driver has loaded.
%
%   info (save it with the run's output):
%     info.table     the table read back from the driver (n x 3, 0-1)
%     info.maxDev    largest |read back - identity|, in 0-255 levels
%     info.ok        maxDev <= 0.5 level (a warning is printed if not)
%     info.timestamp

BackupCluts;
Screen('LoadNormalizedGammaTable', wptr, repmat(linspace(0, 1, 256)', 1, 3));
info = struct('table', [], 'maxDev', NaN, 'ok', false, 'timestamp', datestr(now, 'yyyy-mm-dd_HHMMSS')); %#ok<TNOW1,DATST>
try
    t = Screen('ReadNormalizedGammaTable', wptr);
    ident = repmat(linspace(0, 1, size(t, 1))', 1, size(t, 2));
    info.table  = t;
    info.maxDev = 255 * max(abs(t(:) - ident(:)));
    info.ok     = info.maxDev <= 0.5;
catch err
    warning('useIdentityGamma:readBack', 'useIdentityGamma: could not read the gamma table back (%s).', err.message);
end
if info.ok
    fprintf('Gamma table: identity loaded (read back, max deviation %.2f levels)\n', info.maxDev);
else
    warning('useIdentityGamma: the gamma table read back is NOT identity (max deviation %.1f levels). The display model may not apply.', info.maxDev);
end
end
