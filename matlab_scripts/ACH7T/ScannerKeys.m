classdef ScannerKeys < handle
% ScannerKeys  Scanner triggers and participant responses via a PTB KbQueue.
%
%   keys = ScannerKeys(triggerKey, detectKey, escapeKey, deviceIndex)
%
%   At the FIL, scanner triggers arrive as key presses ('5'). KbCheck only
%   reports whether a key is down at the instant it is called, so brief
%   trigger pulses and short button presses are missed between polls (in
%   the pilot, 4-13 of ~100 triggers per run were logged). A KbQueue
%   records every key event in the background with its GetSecs time,
%   however busy the frame loop is; the run script empties it once per
%   frame with poll().
%
%   All times are on PTB's GetSecs clock, the same clock as the
%   timestamps returned by Screen('Flip').
%
%   Usage in a run script:
%     keys = ScannerKeys(TriggerSign, DetectKey, escapeKey, cfg.kbIndex);
%     t0 = keys.waitForTrigger();      % GetSecs time of the first trigger
%     % every frame:
%     [respTimes, escapePressed] = keys.poll(t0);
%     for r = respTimes, fixTask.respond(r); end
%     % after the frame loop:
%     keys.release();
%     TriggerTime = keys.triggerTimes(t0);  % s since the first trigger (first = 0)
%     keys.report(t0, runDuration);         % trigger count / interval QC
%
%   deviceIndex: [] uses PTB's default keyboard. If the trigger box shows
%   up as a separate keyboard, pass its index (see GetKeyboardIndices).
%   Do not combine with ListenChar(2), which uses a KbQueue itself.

    properties
        triggerKey
        detectKey
        escapeKey
        deviceIndex
        triggers  = [];   % GetSecs times of all trigger presses
        responses = [];   % GetSecs times of all detect-key presses
    end

    methods
        function obj = ScannerKeys(triggerKey, detectKey, escapeKey, deviceIndex)
            if nargin < 4, deviceIndex = []; end
            obj.triggerKey  = triggerKey;
            obj.detectKey   = detectKey;
            obj.escapeKey   = escapeKey;
            obj.deviceIndex = deviceIndex;
            keysOfInterest = zeros(1, 256);
            keysOfInterest([triggerKey detectKey escapeKey]) = 1;
            KbQueueCreate(deviceIndex, keysOfInterest);
        end

        function t0 = waitForTrigger(obj)
            % Start the queue, discard anything pressed earlier, and block
            % until the first trigger. Returns the trigger's own event time.
            % Escape aborts the run with an error.
            KbQueueStart(obj.deviceIndex);
            KbQueueFlush(obj.deviceIndex);
            obj.triggers  = [];
            obj.responses = [];
            t0 = [];
            while isempty(t0)
                ev = KbQueueGetEvent(obj.deviceIndex, 1);   % waits up to 1 s
                if isempty(ev) || ~ev.Pressed, continue; end
                if ev.Keycode == obj.triggerKey
                    t0 = ev.Time;
                elseif ev.Keycode == obj.escapeKey
                    error('ScannerKeys: aborted with Escape while waiting for the trigger.');
                end
            end
            obj.triggers = t0;
        end

        function [respTimes, escapePressed] = poll(obj, t0)
            % Empty the queue. Triggers are stored; returns detect-key
            % press times (s since t0) and whether escape was pressed.
            respTimes     = [];
            escapePressed = false;
            while KbEventAvail(obj.deviceIndex)
                ev = KbQueueGetEvent(obj.deviceIndex);
                if ~ev.Pressed, continue; end   % ignore key releases
                switch ev.Keycode
                    case obj.triggerKey
                        obj.triggers(end+1) = ev.Time;
                    case obj.detectKey
                        obj.responses(end+1) = ev.Time;
                        respTimes(end+1) = ev.Time - t0; %#ok<AGROW>
                    case obj.escapeKey
                        escapePressed = true;
                end
            end
        end

        function release(obj)
            KbQueueStop(obj.deviceIndex);
            KbQueueRelease(obj.deviceIndex);
        end

        function t = triggerTimes(obj, t0)
            t = obj.triggers - t0;
        end

        function report(obj, t0, runDuration)
            % Print trigger QC. The TR is estimated from the median
            % trigger-to-trigger interval.
            t = obj.triggerTimes(t0);
            fprintf('\n--- Scanner triggers ---\n');
            fprintf('Triggers received: %d\n', numel(t));
            fprintf('Responses received: %d\n', numel(obj.responses));
            if numel(t) < 3
                fprintf('Too few triggers to estimate the TR.\n');
                return
            end
            iti = diff(t);
            TR  = median(iti);
            fprintf('Estimated TR (median interval): %.4f s\n', TR);
            ok = iti > 0.5*TR & iti < 1.5*TR;   % jitter of normal intervals, gaps reported below
            fprintf('Interval mean %.4f s, SD %.2f ms (excluding gaps), range %.4f-%.4f s\n', ...
                mean(iti(ok)), 1000*std(iti(ok)), min(iti), max(iti));
            fprintf('Expected for %.1f s at this TR: %d\n', runDuration, floor(runDuration/TR) + 1);
            gaps = find(iti > 1.5*TR);
            for g = gaps
                fprintf('  Gap of %.3f s after trigger %d (t = %.3f s)\n', iti(g), g, t(g));
            end
            if any(iti < 0.5*TR)
                fprintf('  %d intervals < 0.5 x TR: slice triggers or double presses?\n', sum(iti < 0.5*TR));
            end
        end
    end
end
