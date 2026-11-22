function info = runInfo(wptr, ifi, t0)
% runInfo  Who/what/where of a run, for the run's .mat file.
%
%   info = runInfo(wptr, ifi, t0)
%
%   Call after the frame loop, with the window still open (it calls git
%   and hostname, which would cost frames during the run).
%
%   info.triggerClock   wall-clock date/time of the first trigger
%                       (from t0, the GetSecs time of trigger 1)
%   info.t0_GetSecs     t0 itself; every run time is GetSecs - t0
%   info.ifi, refreshHz measured flip interval / rate (checkRefreshRate)
%   info.nominalHz      the display's nominal rate (Screen('NominalFrameRate'))
%   info.windowSize     [width height] of the onscreen window, px
%   info.screenid, info.displaySize_mm (as reported by the OS)
%   info.matlab, info.ptb, info.computer, info.host, info.user
%   info.gitCommit, info.gitDirty  version of these scripts (empty if
%                       git is not available)
%   info.codeDir        folder the scripts ran from

info = struct();
% wall clock of trigger 1: now, minus the time since the trigger
info.t0_GetSecs   = t0;
info.triggerClock = datestr(now - (GetSecs - t0) / 86400, 'yyyy-mm-dd HH:MM:SS.FFF'); %#ok<TNOW1,DATST>
info.ifi          = ifi;
info.refreshHz    = 1 / ifi;
try, info.nominalHz = Screen('NominalFrameRate', wptr); catch, info.nominalHz = NaN; end
[w, h] = Screen('WindowSize', wptr);
info.windowSize   = [w h];
try, info.screenid = Screen('WindowScreenNumber', wptr); catch, info.screenid = NaN; end
try
    [wmm, hmm] = Screen('DisplaySize', info.screenid);
    info.displaySize_mm = [wmm hmm];
catch
    info.displaySize_mm = [NaN NaN];
end
info.matlab   = version;
try, info.ptb = PsychtoolboxVersion; catch, info.ptb = ''; end
info.computer = computer;
[~, host] = system('hostname');
info.host     = strtrim(host);
info.user     = getenv('USER');
if isempty(info.user), info.user = getenv('USERNAME'); end

info.codeDir   = fileparts(mfilename('fullpath'));
info.gitCommit = '';
info.gitDirty  = [];
try
    [s, out] = system(sprintf('git -C "%s" rev-parse HEAD', info.codeDir));
    if s == 0
        info.gitCommit = strtrim(out);
        [~, st] = system(sprintf('git -C "%s" status --porcelain', info.codeDir));
        info.gitDirty = ~isempty(strtrim(st));   % true: uncommitted changes to the scripts
    end
catch
end
end
