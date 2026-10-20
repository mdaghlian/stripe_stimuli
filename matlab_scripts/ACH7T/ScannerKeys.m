classdef ScannerKeys < handle
% ScannerKeys  Scanner triggers and participant responses via PTB KbQueues.
%
%   keys = ScannerKeys(triggerKey, detectKey, escapeKey)
%
%   At the FIL, scanner triggers arrive as key presses ('5'). KbCheck only
%   reports whether a key is down at the instant it is called, so brief
%   trigger pulses and short button presses are missed between polls (in
%   the pilot, 4-13 of ~100 triggers per run were logged). A KbQueue
%   records every key event in the background with its GetSecs time,
%   however busy the frame loop is; the run script empties it once per
%   frame with poll().
%
%   Keyboard-agnostic: a KbQueue listens to one device, so one queue is
%   opened on every keyboard found (GetKeyboardIndices) and their events
%   are merged. The trigger box, button box and the experimenter's
%   keyboard therefore all work without configuration, as with KbCheck.
%   On Windows, where PTB merges all keyboards into one device, a single
%   default queue is used.
%
%   All times are on PTB's GetSecs clock, the same clock as the
%   timestamps returned by Screen('Flip').
%
%   Usage in a run script:
%     keys = ScannerKeys(TriggerSign, DetectKey, escapeKey);
%     t0 = keys.waitForTrigger();      % GetSecs time of the first trigger
%     % every frame:
%     [respTimes, escapePressed] = keys.poll(t0);
%     for r = respTimes, fixTask.respond(r); end
%     % after the frame loop:
%     keys.release();
%     TriggerTime = keys.triggerTimes(t0);  % s since the first trigger (first = 0)
%     keys.report(t0, runDuration);         % trigger count / interval QC
%
%   Do not combine with ListenChar(2), which uses a KbQueue itself.

    properties
        triggerKey
        detectKey
        escapeKey
        devices   = {};   % device indices with an open queue ([] = default)
        triggers  = [];   % GetSecs times of all trigger presses
        responses = [];   % GetSecs times of all detect-key presses
    end

    methods
        function obj = ScannerKeys(triggerKey, detectKey, escapeKey)
            obj.triggerKey = triggerKey;
            obj.detectKey  = detectKey;
            obj.escapeKey  = escapeKey;
            keysOfInterest = zeros(1, 256);
            keysOfInterest([triggerKey detectKey escapeKey]) = 1;

            candidates = {};
            if ~IsWin
                candidates = num2cell(GetKeyboardIndices);
            end
            for k = 1:numel(candidates)
                try
                    KbQueueCreate(candidates{k}, keysOfInterest);
                    obj.devices{end+1} = candidates{k};
                catch
                    % some HID devices report as keyboards but refuse a queue
                end
            end
            if isempty(obj.devices)
                KbQueueCreate([], keysOfInterest);
                obj.devices = {[]};
            end
        end

        function t0 = waitForTrigger(obj)
            % Start the queues, discard anything pressed earlier, and block
            % until the first trigger. Returns the trigger's own event time.
            % Escape aborts the run with an error.
            for k = 1:numel(obj.devices)
                KbQueueStart(obj.devices{k});
                KbQueueFlush(obj.devices{k});
            end
            obj.triggers  = [];
            obj.responses = [];
            t0 = [];
            while isempty(t0)
                ev = obj.nextEvents();
                for e = ev
                    if e.Keycode == obj.triggerKey
                        t0 = e.Time;
                        break
                    elseif e.Keycode == obj.escapeKey
                        error('ScannerKeys: aborted with Escape while waiting for the trigger.');
                    end
                end
                if isempty(t0), WaitSecs(0.001); end
            end
            obj.triggers = t0;
            % presses that arrived with or after the trigger are handled by poll()
            obj.pending = ev([ev.Time] > t0);
        end

        function [respTimes, escapePressed] = poll(obj, t0)
            % Empty the queues. Triggers are stored; returns detect-key
            % press times (s since t0) and whether escape was pressed.
            respTimes     = [];
            escapePressed = false;
            ev = [obj.pending obj.nextEvents()];
            obj.pending = [];
            for e = ev
                switch e.Keycode
                    case obj.triggerKey
                        obj.triggers(end+1) = e.Time;
                    case obj.detectKey
                        obj.responses(end+1) = e.Time;
                        respTimes(end+1) = e.Time - t0; %#ok<AGROW>
                    case obj.escapeKey
                        escapePressed = true;
                end
            end
        end

        function release(obj)
            for k = 1:numel(obj.devices)
                KbQueueStop(obj.devices{k});
                KbQueueRelease(obj.devices{k});
            end
        end

        function t = triggerTimes(obj, t0)
            t = obj.triggers - t0;
        end

        function report(obj, t0, runDuration)
            % Print trigger QC. The TR is estimated from the median
            % trigger-to-trigger interval.
            t = obj.triggerTimes(t0);
            fprintf('\n--- Scanner triggers ---\n');
            fprintf('Keyboard queues: %d\n', numel(obj.devices));
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
                fprintf('  %d intervals < 0.5 x TR: slice triggers, double presses, or the same key on two keyboards?\n', sum(iti < 0.5*TR));
            end
        end
    end

    properties (Access = private)
        pending = [];   % events read by waitForTrigger after the first trigger
    end

    methods (Access = private)
        function ev = nextEvents(obj)
            % All key-press events waiting in every queue, in time order.
            ev = [];
            for k = 1:numel(obj.devices)
                d = obj.devices{k};
                while KbEventAvail(d)
                    e = KbQueueGetEvent(d);
                    if e.Pressed   % ignore key releases
                        e = struct('Time', e.Time, 'Keycode', e.Keycode);
                        ev = [ev e]; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(ev)
                [~, i] = sort([ev.Time]);
                ev = ev(i);
            end
        end
    end
end
