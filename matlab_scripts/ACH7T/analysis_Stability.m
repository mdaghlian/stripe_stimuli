function analysis_Stability(FileName)

% LOAD FixationData
load([FileName '.mat']);

% OUTPUT
fprintf('Number of time queries: %d\n',size(LogData,1));
fprintf('Total time: %.2f s\n',LogData(end,1));

% Plot frame rate stability
figure
plot((LogData(2:end,1)-LogData(1:end-1,1))*1000)
xlabel('Frame number','FontSize',16);
ylabel('\Deltat in ms','FontSize',16);