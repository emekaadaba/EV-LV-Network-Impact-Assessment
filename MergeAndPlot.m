%% MergeAndPlot.m
% Merges per-charger results then runs analysis and plotting

fprintf('=== Merging Results ===\n\n');
chargerPowers = [3, 7, 22];
for cp=1:length(chargerPowers)
    fname=sprintf('Results_%dkW.mat',chargerPowers(cp));
    if ~exist(fname,'file'), error('Missing %s',fname); end
    fprintf('Found: %s\n',fname);
end

Results=struct(); ResultsSmart=struct(); convergenceLog=struct();
for cp=1:length(chargerPowers)
    P=chargerPowers(cp); data=load(sprintf('Results_%dkW.mat',P));
    cL=sprintf('P%dkW',P);
    Results.(cL)=data.Results.(cL);
    if isfield(data,'ResultsSmart')&&isfield(data.ResultsSmart,cL)
        ResultsSmart.(cL)=data.ResultsSmart.(cL);
    end
    if isfield(data,'convergenceLog')&&isfield(data.convergenceLog,cL)
        convergenceLog.(cL)=data.convergenceLog.(cL);
    end
    fprintf('Merged %d kW\n',P);
end

penetrationLevels=data.penetrationLevels;
numCustomers=data.numCustomers;
transformerRating_kVA=data.transformerRating_kVA;
Vmin_pu=data.Vmin_pu; Vmax_pu=data.Vmax_pu;
primarySeason=data.primarySeason; primaryDay=data.primaryDay;

maxN=0;
for cp=1:length(chargerPowers)
    cL=sprintf('P%dkW',chargerPowers(cp));
    for pl=1:length(penetrationLevels)
        pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
        maxN=max(maxN,length(Results.(cL).(pL).peakDemand_kW));
    end
end
numMC=maxN;

if ~isempty(fieldnames(convergenceLog))
    fprintf('\n=== CONVERGENCE ===\n');
    for cp=1:length(chargerPowers)
        cL=sprintf('P%dkW',chargerPowers(cp));
        if ~isfield(convergenceLog,cL), continue; end
        fns=fieldnames(convergenceLog.(cL));
        ns=zeros(length(fns),1);
        for f=1:length(fns), ns(f)=convergenceLog.(cL).(fns{f}).N; end
        fprintf('  %d kW: %d-%d iters\n',chargerPowers(cp),min(ns),max(ns));
    end
end

sv={'Results','chargerPowers','penetrationLevels','numMC','numCustomers',...
    'transformerRating_kVA','Vmin_pu','Vmax_pu','primarySeason','primaryDay'};
if ~isempty(fieldnames(ResultsSmart)), sv{end+1}='ResultsSmart'; end
if ~isempty(fieldnames(convergenceLog)), sv{end+1}='convergenceLog'; end
save('SimulationResults.mat',sv{:});

fprintf('\nAnalysing...\n'); AnalyseResults;
fprintf('\nPlotting...\n'); PlotResults;
fprintf('\n=== Done! 10 figures in Figures/ ===\n');