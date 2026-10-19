classdef FixationTask < handle
% FixationTask  Central fixation + vigilance task shared by the ACH7T run scripts.
%
%   fixTask = FixationTask(fix_cfg, width, height)
%
%   The fixation marker alternates between two states (A and B) every
%   fix_cfg.minInterval-fix_cfg.maxInterval s (uniform, real time); the
%   participant presses the detect key at each change. Before the trigger
%   the marker is drawn in its idle colour (white).
%
%   fix_cfg fields (set in cfg_start.m):
%     style        'dot'   - small central marker
%                  'cross' - full-screen cross, corner to corner
%     size         dot half-width, px. Circle and triangle markers are
%                  scaled to the same area as the square, so a shape change
%                  does not also change the amount of light.
%     lineWidth    cross line width, px
%     task         'colour' - marker switches colourA <-> colourB
%                  'shape'  - marker switches shapeA <-> shapeB, drawn in
%                             colourShape. With style 'cross' the shape is
%                             drawn at the centre of the cross (lines in colourA).
%     dotShape     marker shape for the colour task: 'square', 'circle', 'triangle'
%     shapeA/B     the two shapes of the shape task
%     colourIdle   pre-trigger colour, RGB 0-255
%     colourA/B    colours of the two states
%     colourShape  shape colour in the shape task
%     minInterval, maxInterval   time between changes, s
%
%   Usage in a run script:
%     fixTask = FixationTask(fix_cfg, width, height);
%     fixTask.draw(wptr);      % idle marker, before the trigger
%     fixTask.start();         % after the trigger: state A, first change scheduled
%     % every frame:
%     fixTask.update(elapsed); % switch state when due (logs the change)
%     fixTask.draw(wptr);
%     % on a detect key press:
%     fixTask.respond(elapsed);
%     % at the end:
%     FixationData = fixTask.data; % [code, t]: 1 = A->B, 2 = B->A, 3 = response
%                              % (format read by analysis_Fixation)

    properties
        cfg
        state        = 0;    % 0 idle (pre-trigger), 1 A, 2 B
        data         = [];   % [code, t]
        lastChange   = 0;
        nextInterval = 0;
    end

    properties (Access = private)
        width
        height
    end

    methods
        function obj = FixationTask(fix_cfg, width, height)
            if ~any(strcmp(fix_cfg.style, {'dot', 'cross'}))
                error('FixationTask: fix_cfg.style must be ''dot'' or ''cross'' (got ''%s'').', fix_cfg.style);
            end
            if ~any(strcmp(fix_cfg.task, {'colour', 'shape'}))
                error('FixationTask: fix_cfg.task must be ''colour'' or ''shape'' (got ''%s'').', fix_cfg.task);
            end
            shapes = {'square', 'circle', 'triangle'};
            if ~all(ismember({fix_cfg.dotShape, fix_cfg.shapeA, fix_cfg.shapeB}, shapes))
                error('FixationTask: shapes must be one of: %s.', strjoin(shapes, ', '));
            end
            obj.cfg    = fix_cfg;
            obj.width  = width;
            obj.height = height;
        end

        function start(obj, t)
            % Call once after the trigger: switch to state A and schedule
            % the first change.
            if nargin < 2, t = 0; end
            obj.state        = 1;
            obj.data         = [];
            obj.lastChange   = t;
            obj.nextInterval = obj.randomInterval();
        end

        function changed = update(obj, t)
            % Switch state if the current interval has elapsed. t is time
            % since the trigger, s.
            changed = false;
            if obj.state == 0 || t - obj.lastChange < obj.nextInterval
                return
            end
            obj.lastChange   = t;
            obj.nextInterval = obj.randomInterval();
            if obj.state == 1
                obj.state = 2; obj.data = cat(1, obj.data, [1, t]);
            else
                obj.state = 1; obj.data = cat(1, obj.data, [2, t]);
            end
            changed = true;
        end

        function respond(obj, t)
            % Responses come from a key queue with their own press time,
            % which can precede a change already logged this frame; keep
            % data in time order (analysis_Fixation relies on the order).
            obj.data = sortrows(cat(1, obj.data, [3, t]), 2);
        end

        function draw(obj, wptr)
            c = obj.cfg;
            [lineColour, shapeColour, shape] = obj.appearance();
            if strcmp(c.style, 'cross')
                Screen('DrawLine', wptr, lineColour, 0, 0, obj.width, obj.height, c.lineWidth);
                Screen('DrawLine', wptr, lineColour, 0, obj.height, obj.width, 0, c.lineWidth);
                if ~strcmp(c.task, 'shape'), return; end
            end
            obj.drawShape(wptr, shape, shapeColour);
        end
    end

    methods (Access = private)
        function dt = randomInterval(obj)
            dt = obj.cfg.minInterval + (obj.cfg.maxInterval - obj.cfg.minInterval) * rand(1);
        end

        function [lineColour, shapeColour, shape] = appearance(obj)
            % lineColour: cross lines; shapeColour: central marker
            c = obj.cfg;
            if strcmp(c.task, 'colour')
                shape = c.dotShape;
                switch obj.state
                    case 0, lineColour = c.colourIdle;
                    case 1, lineColour = c.colourA;
                    case 2, lineColour = c.colourB;
                end
                shapeColour = lineColour;
            else
                if obj.state == 0
                    lineColour  = c.colourIdle;
                    shapeColour = c.colourIdle;
                else
                    lineColour  = c.colourA;
                    shapeColour = c.colourShape;
                end
                if obj.state == 2
                    shape = c.shapeB;
                else
                    shape = c.shapeA;
                end
            end
        end

        function drawShape(obj, wptr, shape, colour)
            h  = obj.cfg.size;   % half-width of the square; other shapes match its area
            cx = obj.width  / 2;
            cy = obj.height / 2;
            switch shape
                case 'square'
                    Screen('FillRect', wptr, colour, [cx-h cy-h cx+h cy+h]);
                case 'circle'
                    r = 2 * h / sqrt(pi);
                    Screen('FillOval', wptr, colour, [cx-r cy-r cx+r cy+r]);
                case 'triangle'
                    % upward-pointing equilateral triangle centred on its
                    % centroid; side s = 4h / 3^(1/4), circumradius = s / sqrt(3)
                    R   = 4 * h / 3^(1/4) / sqrt(3);
                    ang = [90 210 330];
                    xy  = [cx + R * cosd(ang); cy - R * sind(ang)]';
                    Screen('FillPoly', wptr, colour, xy, 1);
            end
        end
    end
end
