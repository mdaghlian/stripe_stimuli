function analysis_Fixation(FileName)

% LOAD FixationData
load([FileName '.mat']);

% NUMBER OF RESPONSES
% note that the logfile starts at the first colour change
response=0;
change=0;
for i=1:length(FixationData)
    if FixationData(i,1)==3
        response=response+1;
    else
        change=change+1;
    end
end

% NUMBER OF HITS, MISSES and RT
change_miss=0;
change_hit=0;
rt=[];
for i=1:length(FixationData)-1
    if (FixationData(i,1)~=3 && FixationData(i+1,1)~=3)
        change_miss=change_miss+1;
    elseif (FixationData(i,1)~=3 && FixationData(i+1,1)==3)
        change_hit=change_hit+1;
        rt=[rt (FixationData(i+1,2)-FixationData(i,2))*1000];
    end
end

if FixationData(end,1)~=3%add a miss if the run doesnt end with a response
    change_miss=change_miss+1;
end

% OUTPUT
fprintf('Number of changes: %d\n',change);
fprintf('Number of responses: %d\n',response);
fprintf('Number of hits: %d\n',change_hit);
fprintf('Number of misses: %d\n',change_miss);
fprintf('Error rate: %.2f%%\n\n',change_miss/change*100);
fprintf('Mean RT: %.2f ms\n',mean(rt));
fprintf('Corresponding SD: %.2f ms\n',std(rt));

% HISTOGRAM
figure
hold all
hist(rt);
hold off
xlabel('RT in ms','FontSize',16);
ylabel('Number of responses','FontSize',16);