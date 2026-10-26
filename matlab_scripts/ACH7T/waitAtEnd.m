function waitAtEnd(wptr, colour, message)
% waitAtEnd  End-of-run screen: hold a uniform screen, tell the experimenter
% in the MATLAB command window, and wait for Esc.
%
%   waitAtEnd(wptr, colour, message)
%
%   Called after the run has been SAVED, so pressing Esc (or anything
%   going wrong) cannot lose data. The window stays open on a uniform
%   field (the matched grey, or black for the scotopic paradigm) so the
%   participant does not see the desktop between runs.

Screen('FillRect', wptr, colour);
Screen('Flip', wptr);
fprintf('\n============================================================\n');
fprintf('%s\n', message);
fprintf('Press Esc (any keyboard) to continue.\n');
fprintf('============================================================\n');
escapeKey = KbName('ESCAPE');
KbReleaseWait(-3);   % -3 = all keyboards and keypads
while true
    [~, ~, keyCode] = KbCheck(-3);
    if keyCode(escapeKey), break; end
    WaitSecs(0.01);
end
end
