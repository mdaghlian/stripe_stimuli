function [action, ks] = flickerKeys(ks, keys, key_cfg)
% flickerKeys  Responses for the flicker-matching tasks: press or hold.
%
%   ks = struct('key', 0, 't0', 0, 'tLast', 0, 'needRelease', true);
%   [action, ks] = flickerKeys(ks, keys, key_cfg)    % once per frame
%
%   keys has the key codes .dark, .light, .done and .escape. action is
%   'dark', 'light', 'done', 'escape' or '' (nothing this frame).
%
%   A press of dark/light gives one step. Held for key_cfg.holdDelay s, it
%   then repeats every key_cfg.repeatInterval s until released. Done and
%   Escape count once per press. After Done or Escape (and at the start,
%   with needRelease = true) all keys must be released before the next
%   response, so the key that started a trial cannot also step it.
%
%   Reads key_cfg.device: -3 = all keyboards and keypads (button boxes
%   included) on macOS/Linux; Windows always merges all keyboards.

action = '';
[down, t, kc] = KbCheck(key_cfg.device);
if ~down
    ks.key = 0;
    ks.needRelease = false;
    return
end
if ks.needRelease, return; end

if kc(keys.escape)
    action = 'escape';
    ks.needRelease = true;
elseif ks.key == 0
    % new press
    if kc(keys.dark)
        ks.key = keys.dark;  action = 'dark';
    elseif kc(keys.light)
        ks.key = keys.light; action = 'light';
    elseif kc(keys.done)
        action = 'done';
        ks.needRelease = true;
        return
    else
        return
    end
    ks.t0 = t;
    ks.tLast = t;
elseif kc(ks.key)
    % held: auto-repeat
    if t - ks.t0 >= key_cfg.holdDelay && t - ks.tLast >= key_cfg.repeatInterval
        if ks.key == keys.dark, action = 'dark'; else, action = 'light'; end
        ks.tLast = t;
    end
else
    % held key let go while another is down: wait for a full release
    ks.key = 0;
    ks.needRelease = true;
end
