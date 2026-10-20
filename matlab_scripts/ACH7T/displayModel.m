function model = displayModel(spec)
% displayModel  Luminance model of the display: drive (0-255) <-> luminance,
% per channel. Used to build stimuli in linear luminance (makeStimuli).
%
%   model = displayModel(spec)     % spec: a struct, usually cal_cfg from cfg_start
%   model = displayModel()         % FIL 7T measured tables, no filter
%
%   spec.type selects the source:
%     'FIL7T'   Alex Wade's measured tables for the FIL 7T projector
%               (calibration/FIL7T_20260515_AWade/).
%               spec.filter: 'noFilter' (default), '1xNDFilter', '2xNDFilter', '3xNDFilter'
%     'table'   any table file: CSV with a one-line header and columns
%               drive (0-255), R, G, B, W (luminance; cd/m^2 or relative).
%               spec.file: path to the CSV
%     'gamma'   power law per channel, set by hand:
%               L = Lmax * min(d/clip, 1)^gamma
%               spec.gamma: one value for all channels, or [R G B W]
%               spec.clip:  drive at which each channel stops rising,
%                           one value or [R G B W] (default 255)
%               spec.Lmax:  luminance at the clip point, one value or
%                           [R G B W] (default 1, i.e. relative units)
%     'linear'  no correction: luminance = drive. Stimuli built with this
%               model are identical to drive-unit stimuli (the behaviour
%               before gamma correction).
%
%   The returned model (all luminances above black, drive in 0..255,
%   vectorised over d and L):
%     model.dL(c, d)     luminance of channel c ('R','G','B','W') at drive d
%     model.d(c, L)      drive (not rounded) giving luminance L in channel c,
%                        clamped to [0, model.dLmax.(c)] (inverse on the rising part)
%     model.L(c, d)      model.black + model.dL(c, d)
%     model.dLmax.(c)    largest luminance channel c reaches
%     model.clip.(c)     drive from which channel c stops rising
%     model.black        black level (0: not part of the models above)
%     model.type, model.description, model.spec
%
%   A mixture of channels has luminance sum_c dL(c, d_c) if the display is
%   additive. For grey (R = G = B) use channel 'W', not R + G + B (the FIL
%   7T projector is not additive for R + G + B). R + B additivity can be
%   checked with checkAdditivityRB.m.

if nargin < 1 || isempty(spec), spec = struct('type', 'FIL7T'); end
if ~isfield(spec, 'type'), error('displayModel: spec.type is required (FIL7T, table, gamma or linear).'); end
chans = {'R', 'G', 'B', 'W'};
fs = filesep;

switch lower(spec.type)
    case 'fil7t'
        filter = 'noFilter';
        if isfield(spec, 'filter') && ~isempty(spec.filter), filter = spec.filter; end
        filters = {'noFilter', '1xNDFilter', '2xNDFilter', '3xNDFilter'};
        if ~any(strcmp(filter, filters))
            error('displayModel: filter must be one of: %s.', strjoin(filters, ', '));
        end
        here = fileparts(mfilename('fullpath'));
        file = [here fs 'calibration' fs 'FIL7T_20260515_AWade' fs 'tables' fs ...
            'cal_FIL7T_20260515_' filter '.csv'];
        model = tableModel(file, chans);
        model.filter = filter;
        model.description = sprintf('FIL 7T measured tables (A. Wade, 15 May 2026), %s', filter);

    case 'table'
        if ~isfield(spec, 'file') || exist(spec.file, 'file') ~= 2
            error('displayModel: spec.file must name an existing CSV (drive,R,G,B,W).');
        end
        model = tableModel(spec.file, chans);
        model.description = sprintf('table %s', spec.file);

    case 'gamma'
        if ~isfield(spec, 'gamma') || isempty(spec.gamma)
            error('displayModel: spec.gamma is required for type ''gamma''.');
        end
        g    = perChannel(spec.gamma, 'gamma');
        clip = perChannel(getfieldDefault(spec, 'clip', 255), 'clip');
        Lmax = perChannel(getfieldDefault(spec, 'Lmax', 1), 'Lmax');
        if any(clip <= 0 | clip > 255), error('displayModel: clip points must be in (0, 255].'); end
        model = struct();
        for k = 1:4
            c = chans{k};
            model.dLmax.(c) = Lmax(k);
            model.clip.(c)  = clip(k);
            G.(c) = g(k); C.(c) = clip(k); M.(c) = Lmax(k);
        end
        model.dL = @(c, d) M.(c) * min(max(d, 0) / C.(c), 1) .^ G.(c);
        model.d  = @(c, L) C.(c) * (min(max(L, 0), M.(c)) / M.(c)) .^ (1 / G.(c));
        model.description = sprintf('power law: gamma [%s], clip [%s], Lmax [%s] (R G B W)', ...
            num2str(g, '%g '), num2str(clip, '%g '), num2str(Lmax, '%g '));

    case 'linear'
        model = struct();
        for k = 1:4
            c = chans{k};
            model.dLmax.(c) = 255;
            model.clip.(c)  = 255;
        end
        model.dL = @(c, d) min(max(d, 0), 255);
        model.d  = @(c, L) min(max(L, 0), 255);
        model.description = 'linear: no gamma correction (luminance = drive)';

    otherwise
        error('displayModel: unknown spec.type ''%s'' (FIL7T, table, gamma or linear).', spec.type);
end

model.black = 0;
model.L     = @(c, d) model.black + model.dL(c, d);
model.type  = spec.type;
model.spec  = spec;
end


% =============================================================================
function model = tableModel(file, chans)
% Measured table: interpolate, forward and inverse.
tab = csvread(file, 1, 0);   % skip header; csvread for older MATLAB
if size(tab, 2) < 5, error('displayModel: %s must have columns drive,R,G,B,W.', file); end
drive = tab(:, 1);
model = struct();
model.table = tab;
model.file  = file;
for k = 1:numel(chans)
    c = chans{k};
    y = max(tab(:, k+1), 0);              % drive 0 is ~0 +/- noise (luminance above black)
    y = cummax(y);                        % luminance cannot fall with drive (removes noise)
    top = find(y >= 0.99 * y(end), 1);    % start of the plateau (within 1% of the top)
    fwd.(c) = y;
    [yu, iu] = unique(y(1:top), 'first'); % inverse on the rising part; drop repeated values
    inv.(c) = [yu, drive(iu)];
    model.dLmax.(c) = y(top);
    model.clip.(c)  = drive(top);
end
model.dL = @(c, d) interp1(drive, fwd.(c), min(max(d, 0), 255), 'linear');
model.d  = @(c, L) interp1(inv.(c)(:,1), inv.(c)(:,2), min(max(L, 0), model.dLmax.(c)), 'linear');
end


function v = perChannel(x, name)
% One value for all channels, or [R G B W].
if isscalar(x)
    v = repmat(x, 1, 4);
elseif numel(x) == 4
    v = x(:)';
else
    error('displayModel: %s must be one value or [R G B W].', name);
end
end


function v = getfieldDefault(s, f, default)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = default; end
end
