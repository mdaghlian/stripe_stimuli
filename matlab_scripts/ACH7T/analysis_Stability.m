function analysis_Stability(FileName)

% LOAD FixationData
load([FileName '.mat']);

% OUTPUT
fprintf('Number of time queries: %d\n',length(LogData));
fprintf('Total time: %d\n',LogData(end));

% Plot frame rate stability
figure
plot((LogData(2:end,1)-LogData(1:end-1,1))*1000)
xlabel('Frame number','FontSize',16);
ylabel('\Deltat in s','FontSize',16);