function [onset, duration] = measuredBlockTiming(frameBlock, flipT, plannedOnsets, ifi)
% measuredBlockTiming  Block onsets/durations from the frames actually shown.
%
%   [onset, duration] = measuredBlockTiming(frameBlock, flipT, plannedOnsets, ifi)
%
%   frameBlock    : block index (into BlockList) of each logged frame
%   flipT         : that frame's Screen('Flip') StimulusOnsetTime - t0 (s)
%   plannedOnsets : planned block onsets (s), one per block in BlockList
%   ifi           : flip interval (s)
%
%   onset(b)    = flip time of block b's first frame (NaN if never shown,
%                 e.g. the run was stopped early with Esc)
%   duration(b) = time until the next shown block's first frame; for the
%                 last shown block, until its last frame ends (last flip + ifi)
%
%   Used for the SPM-style _Cond.mat so the onsets are when each block
%   actually appeared on screen, not the planned schedule. Prints how far
%   the measured onsets are from the planned ones.

nBlocks  = numel(plannedOnsets);
onset    = nan(1, nBlocks);
duration = nan(1, nBlocks);
for b = 1:nBlocks
    i = find(frameBlock == b, 1, 'first');
    if ~isempty(i), onset(b) = flipT(i); end
end

shown = find(~isnan(onset));
for k = 1:numel(shown)
    b = shown(k);
    if k < numel(shown)
        duration(b) = onset(shown(k+1)) - onset(b);
    else
        duration(b) = flipT(find(frameBlock == b, 1, 'last')) + ifi - onset(b);
    end
end

d = onset(shown) - plannedOnsets(shown);
fprintf('Block onsets: %d of %d shown, measured - planned: mean %.1f ms, max |%.1f| ms\n', ...
        numel(shown), nBlocks, 1000*mean(d), 1000*max(abs(d)));
