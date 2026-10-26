function analysis_RedIsoLum(pathfile)

fs=filesep;
cfg_start;
% LOAD DATA
load([pathfile fs ['redIsoLumData' isoFileTag(findIso_cfg) '.mat']]);

% DATA SORTING
nCond1=max(expPar(:,1));
nReps=length(find(expPar(:,1)==1));
repCount=zeros(1,nCond1);
isoLumData=zeros(nCond1,nReps);
for trial=1:length(expPar)
    c1=expPar(trial,1);
    value=expPar(trial,3);
    repCount(c1)=repCount(c1)+1;
    isoLumData(c1,repCount(c1))=value;
end

% AVERAGE
meanData=mean(isoLumData,2);
% -> Updated less magic number method: find the mean per ecc band
% USING "TRUE" PIXEL VALUES HERE
eccList = findIso_cfg.ecc_mean * cfg.height;

% FIG. 1
figure
hold all
for e=1:nCond1
    scatter(ones(1,repCount(e))*eccList(e),isoLumData(e,:),25);
end
hold off
xlabel('Eccentricity (px)','FontSize',16);
ylabel('Set Isoluminance Value','FontSize',16);
set(gca,'FontSize',14);

% FIG. 2
figure
hold all
scatter(log(eccList),meanData,25);
hold off
xlabel('Eccentricity (px) - log scale','FontSize',16);
ylabel('Set Isoluminance Value','FontSize',16);
set(gca,'FontSize',14);

% FIG. 3
params=polyfit(log(eccList),meanData,1);%linear least-squares fit
fitY=polyval(params,log(eccList));

figure
hold all
C1=scatter(log(eccList),meanData,25);
set(C1,'linewidth',2);
C2=plot(log(eccList),fitY,'--b');
set(C2,'linewidth',3);
hold off
xlabel('Eccentricity (px) - log scale','FontSize',16);
ylabel('Set Isoluminance Value','FontSize',16);
set(gca,'FontSize',14);

% OUTPUT
redValues2Use=round(polyval(params,log(eccList)))
redParams=params

save([pathfile fs ['redFitData' isoFileTag(findIso_cfg) '.mat']],'redValues2Use','redParams','-mat');