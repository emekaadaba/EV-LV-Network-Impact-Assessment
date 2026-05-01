%% AnalyseResults.m
% Uses actual iteration count per scenario

if ~exist('Results','var')
    if exist('SimulationResults.mat','file'), load('SimulationResults.mat');
    else, error('No results.'); end
end

fprintf('\n=== RESULTS ANALYSIS ===\n\n');
violThr=0.05;
getNmc=@(R)length(R.peakDemand_kW);

for cp=1:length(chargerPowers)
    cL=sprintf('P%dkW',chargerPowers(cp));
    fprintf('=== %d kW ===\n',chargerPowers(cp));
    fprintf('%-6s %-5s %-10s %-10s %-10s %-10s %-12s\n','Pen','N','MinV','TX%','Cable%','Loss','Violations');
    fprintf('%s\n',repmat('-',1,68));
    HV=100;HT=100;HC=100;
    for pl=1:length(penetrationLevels)
        pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
        R=Results.(cL).(pL); nI=getNmc(R);
        mV=mean(R.minVoltage); mT=mean(R.peakTransformerLoad_pct);
        mC=mean(R.peakCableLoad_pct); mL=mean(R.totalLosses_kWh);
        nViol=sum(R.numCustViolated>0); pctV=nViol/nI*100;
        fprintf('%-6s %-5d %-10.4f %-10.1f %-10.1f %-10.2f %-12s\n',...
            sprintf('%d%%',round(penetrationLevels(pl)*100)),nI,mV,mT,mC,mL,...
            sprintf('%.1f%%(%d/%d)',pctV,nViol,nI));
        if pl>1
            if pctV/100>violThr&&HV==100, HV=penetrationLevels(pl-1)*100; end
            if mT>100&&HT==100, HT=penetrationLevels(pl-1)*100; end
            if mC>100&&HC==100, HC=penetrationLevels(pl-1)*100; end
        end
    end
    ovHC=min([HV HT HC]);
    cs={'Voltage','Transformer','Cable'}; [~,bi]=min([HV HT HC]);
    fprintf('HC: V=%d%% TX=%d%% Cable=%d%% -> %d%% (%s)\n\n',HV,HT,HC,ovHC,cs{bi});
    Results.(cL).hostingCapacity=ovHC;
    Results.(cL).HC_voltage=HV; Results.(cL).HC_transformer=HT;
    Results.(cL).HC_cable=HC; Results.(cL).HC_binding=cs{bi};
end

hasSC=exist('ResultsSmart','var')&&isstruct(ResultsSmart)&&~isempty(fieldnames(ResultsSmart));
if hasSC
    fprintf('=== SMART CHARGING ===\n');
    for cp=1:length(chargerPowers)
        cL=sprintf('P%dkW',chargerPowers(cp));
        if ~isfield(ResultsSmart,cL), continue; end
        sHC=100;
        for pl=1:length(penetrationLevels)
            numEVs=round(penetrationLevels(pl)*numCustomers);
            pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
            if numEVs==0||~isfield(ResultsSmart.(cL),pL), continue; end
            Rs=ResultsSmart.(cL).(pL); nI=getNmc(Rs);
            pctVs=sum(Rs.numCustViolated>0)/nI*100;
            if sHC==100&&pctVs/100>violThr
                if pl>1, sHC=penetrationLevels(pl-1)*100; else, sHC=0; end
            end
        end
        fprintf('  %d kW: Smart HC=%d%% (was %d%%)\n',chargerPowers(cp),sHC,Results.(cL).hostingCapacity);
        ResultsSmart.(cL).hostingCapacity=sHC;
    end
    fprintf('\n');
end

sv={'Results','chargerPowers','penetrationLevels','numMC','numCustomers',...
    'transformerRating_kVA','Vmin_pu','Vmax_pu','primarySeason','primaryDay'};
if hasSC, sv{end+1}='ResultsSmart'; end
if exist('convergenceLog','var'), sv{end+1}='convergenceLog'; end
save('SimulationResults.mat',sv{:});
fprintf('Analysis complete.\n');