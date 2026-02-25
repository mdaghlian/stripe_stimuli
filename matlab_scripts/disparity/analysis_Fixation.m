function analysis_Fixation(FileName)

% LOAD FixationData
load([FileName '.mat']);

% NUMBER OF RESPONSES
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
disp(['Number of changes: ', num2str(change)]);
disp(['Number of responses: ', num2str(response)]);
disp(['Number of hits: ', num2str(change_hit)]);
disp(['Number of misses: ', num2str(change_miss)]);
disp(['Error rate: ', num2str(change_miss/change*100), ' %']);
disp(['Mean RT: ', num2str(mean(rt)), ' ms']);
disp(['Corresponding SD: ', num2str(std(rt)), ' ms']);

% HISTOGRAM
figure
hold all
hist(rt);
hold off
xlabel('RT in ms','FontSize',16);
ylabel('Number of responses','FontSize',16);