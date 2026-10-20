function [rDrive, bDrive] = rbMixtureDrives(model, LB, k, p, m)
% rbMixtureDrives  Drive values of the red + blue mixture used in the
% additivity check (checkAdditivityRB).
%
%   [rDrive, bDrive] = rbMixtureDrives(model, LB, k, p, m)
%
%   The mixture with blue fraction p is predicted (if red and blue add) to
%   be isoluminant with pure blue at LB for an observer whose red weight is
%   k (red at k*LB matches blue at LB):
%       blue luminance  m * p * LB
%       red  luminance  m * (1 - p) * k * LB
%   m scales the whole mixture. Luminances are in display-model units and
%   converted to drive with model.d.

bDrive = model.d('B', m * p * LB);
rDrive = model.d('R', m * (1 - p) * k * LB);
end
