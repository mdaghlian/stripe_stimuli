function analysis_Stability(FileName)

% LOAD FixationData
load([FileName '.mat']);

% OUTPUT
printf('Number of time queries: %d\n',length(LogTime));
printf('Total time: %d\n',LogTime(end));

% Plot frame rate stability
figure
plot((LogTime(2:end)-LogTime(1:end-1))*1000)
xlabel('Frame number','FontSize',16);
ylabel('\Deltat in s','FontSize',16);