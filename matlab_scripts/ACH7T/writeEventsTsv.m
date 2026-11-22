function writeEventsTsv(fileName, ev)
% writeEventsTsv  Block table as a BIDS-style events.tsv (tab separated).
%
%   writeEventsTsv(fileName, ev)
%
%   ev: struct of equal-length vectors / cellstr columns. The first columns
%   should be onset and duration (s since the first trigger, measured flip
%   times) and trial_type, as BIDS expects; any further fields are written
%   as extra columns (e.g. orientation, planned_onset). NaN -> 'n/a'.

T = struct2table(structfun(@(c) c(:), ev, 'UniformOutput', false));
writetable(T, fileName, 'FileType', 'text', 'Delimiter', '\t');
% BIDS writes missing values as n/a
txt = fileread(fileName);
txt = regexprep(txt, '(?<=^|\t)NaN(?=\t|\r?\n|$)', 'n/a', 'lineanchors');
fid = fopen(fileName, 'w'); fwrite(fid, txt); fclose(fid);
end
