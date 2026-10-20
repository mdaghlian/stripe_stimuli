function useIdentityGamma(wptr)
% useIdentityGamma  Back up the current gamma tables and load an identity
% table on the window's screen.
%
%   useIdentityGamma(wptr)     % after OpenWindow; call RestoreCluts on exit
%
%   The FIL 7T display was calibrated (and the isoluminance tasks run) with
%   an identity gamma table, so the drive values in the stimuli only mean
%   what the display model says under that table. Without this, the run
%   scripts use whatever table the OS or driver has loaded.

BackupCluts;
Screen('LoadNormalizedGammaTable', wptr, repmat(linspace(0, 1, 256)', 1, 3));
end
