function RunSingle(P_charger)
%% RunSingle - Adaptive MC (max 200) + Smart (fixed 100)
% =======================================================================
% Memory-safe COM handling:
%   - DSSObj.Text.Command='Clear' flushes OpenDSS internal circuit data
%   - COM fully destroyed (delete + clear) every 10 iterations
%   - java.lang.System.gc() + pause(0.5) after every COM destroy
%   - Fresh COM created for every penetration level
%   - Full GC + 1s pause between penetration levels
%   - All large temp variables cleared every iteration
%
% Uncontrolled: adaptive (min=50, max=200, eps=0.0075, consec=2)
% Smart:        fixed 100 iterations
% =======================================================================

fprintf('=== EV Impact: %d kW === %s\n', P_charger, datetime("now"));

penetrationLevels = [0 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00];
minMC=50; maxMC=200; checkEvery=25; epsilon=0.0075; reqConsec=2;
numMC=maxMC;
smartMC=100;
comRefresh=10;

primarySeason=1; primaryDay=1; numCustomers=33;
transformerRating_kVA=500; chargerEfficiency=0.90; smartChargingDelay=22;
dssFilePath=fullfile(pwd,'UK_LV_Network.dss');
Vmin_pu=0.90; Vmax_pu=1.10;

cL=sprintf('P%dkW',P_charger);
outFile=sprintf('Results_%dkW.mat',P_charger);
fprintf('  Uncontrolled: min=%d max=%d eps=%.4f consec=%d\n',minMC,maxMC,epsilon,reqConsec);
fprintf('  Smart: %d iters | COM refresh: every %d\n\n',smartMC,comRefresh);

baselineLoad=GenerateBaselineLoad(numCustomers,primarySeason,primaryDay);
fprintf('  Baseline peak: %.1f kW\n\n',max(sum(baselineLoad,2)));

%% Initialise
Results=struct(); convergenceLog=struct();
for pl=1:length(penetrationLevels)
    pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
    Results.(cL).(pL).minVoltage=zeros(maxMC,1);
    Results.(cL).(pL).maxVoltage=zeros(maxMC,1);
    Results.(cL).(pL).voltageViolations=zeros(maxMC,1);
    Results.(cL).(pL).numCustViolated=zeros(maxMC,1);
    Results.(cL).(pL).peakTransformerLoad_kVA=zeros(maxMC,1);
    Results.(cL).(pL).peakTransformerLoad_pct=zeros(maxMC,1);
    Results.(cL).(pL).peakCableLoad_pct=zeros(maxMC,1);
    Results.(cL).(pL).totalLosses_kWh=zeros(maxMC,1);
    Results.(cL).(pL).peakDemand_kW=zeros(maxMC,1);
    Results.(cL).(pL).totalEVEnergy_kWh=zeros(maxMC,1);
    Results.(cL).(pL).sampleVoltageProfile=[];
    Results.(cL).(pL).sampleDemandProfile=[];
    Results.(cL).(pL).sampleEVProfile=[];
    Results.(cL).(pL).sampleBaselineProfile=[];
end

%% ===================== UNCONTROLLED (adaptive, max 200) =====================
fprintf('========== Uncontrolled: %d kW ==========\n',P_charger);
tic;
for pl=1:length(penetrationLevels)
    penLevel=penetrationLevels(pl);
    numEVs=round(penLevel*numCustomers);
    pL=sprintf('Pen%d',round(penLevel*100));
    fprintf('\n--- %d%% (%d EVs) ---\n',round(penLevel*100),numEVs);

    if numEVs==0, iterLimit=minMC; else, iterLimit=maxMC; end

    java.lang.System.gc(); pause(1);
    DSSObj=createDSS();
    prevCoV=Inf; consecPasses=0; convergedAt=iterLimit;

    for mc=1:iterLimit
        % COM refresh every 10 iterations
        if mc>1 && mod(mc,comRefresh)==0
            DSSObj=refreshDSS(DSSObj);
        end
        if mod(mc,50)==0, fprintf('  MC %d/%d\n',mc,iterLimit); end

        try
            rng(mc*10000+P_charger*100+pl);
            if numEVs>0
                [EVp,~,~]=EVProfileGenerator(numEVs,P_charger,chargerEfficiency,primarySeason,primaryDay);
                evIdx=sort(randperm(numCustomers,numEVs));
                evLoad=zeros(1440,numCustomers);
                for ev=1:numEVs, evLoad(:,evIdx(ev))=EVp(:,ev); end
            else
                evLoad=zeros(1440,numCustomers);
            end
            totalLoad=baselineLoad+evLoad;
            [voltages,txL,cableL,losses,~]=RunOpenDSS(totalLoad,dssFilePath,numCustomers,DSSObj);

            Results.(cL).(pL).minVoltage(mc)=min(voltages(:));
            Results.(cL).(pL).maxVoltage(mc)=max(voltages(:));
            vl=voltages<Vmin_pu; vh=voltages>Vmax_pu;
            Results.(cL).(pL).voltageViolations(mc)=sum(any(vl(:)|vh(:)));
            Results.(cL).(pL).numCustViolated(mc)=sum(any(vl|vh,1));
            Results.(cL).(pL).peakTransformerLoad_kVA(mc)=max(txL);
            Results.(cL).(pL).peakTransformerLoad_pct(mc)=max(txL)/transformerRating_kVA*100;
            Results.(cL).(pL).peakCableLoad_pct(mc)=max(cableL);
            Results.(cL).(pL).totalLosses_kWh(mc)=sum(losses)/60;
            Results.(cL).(pL).peakDemand_kW(mc)=max(sum(totalLoad,2));
            Results.(cL).(pL).totalEVEnergy_kWh(mc)=sum(evLoad(:))/60;
            if mc==1
                Results.(cL).(pL).sampleVoltageProfile=voltages;
                Results.(cL).(pL).sampleDemandProfile=totalLoad;
                Results.(cL).(pL).sampleEVProfile=evLoad;
                Results.(cL).(pL).sampleBaselineProfile=baselineLoad;
            end
            clear EVp evIdx evLoad totalLoad voltages txL cableL losses vl vh;
        catch ME
            fprintf('  WARN MC%d: %s\n',mc,ME.message);
            clear EVp evIdx evLoad totalLoad voltages txL cableL losses vl vh;
            DSSObj=refreshDSS(DSSObj);
        end

        % Convergence check
        if numEVs>0 && mc>=minMC && mod(mc,checkEvery)==0
            d=Results.(cL).(pL).peakDemand_kW(1:mc);
            mu=mean(d);
            if mu>0, CoV=std(d)/mu; else, CoV=0; end
            delta=abs(CoV-prevCoV);
            if delta<epsilon
                consecPasses=consecPasses+1;
            else
                consecPasses=0;
            end
            if consecPasses>=reqConsec
                convergedAt=mc;
                fprintf('  *** CONVERGED at %d (CoV=%.4f) ***\n',mc,CoV);
                break;
            end
            prevCoV=CoV;
        end
    end

    % Trim arrays
    actualN=min(mc,iterLimit);
    fns=fieldnames(Results.(cL).(pL));
    for f=1:length(fns)
        v=Results.(cL).(pL).(fns{f});
        if isnumeric(v)&&length(v)==maxMC
            Results.(cL).(pL).(fns{f})=v(1:actualN);
        end
    end
    if numEVs>0, pk=Results.(cL).(pL).peakDemand_kW; fCoV=std(pk)/mean(pk);
    else, fCoV=0; end
    convergenceLog.(cL).(pL).N=actualN;
    convergenceLog.(cL).(pL).convergedAt=convergedAt;
    convergenceLog.(cL).(pL).finalCoV=fCoV;

    destroyDSS(DSSObj); clear DSSObj;
    java.lang.System.gc(); pause(1);

    fprintf('  N=%d MinV=%.4f TX=%.1f%% CoV=%.4f\n',actualN,...
        mean(Results.(cL).(pL).minVoltage),...
        mean(Results.(cL).(pL).peakTransformerLoad_pct),fCoV);

    save(outFile,'Results','convergenceLog','P_charger','penetrationLevels',...
        'numMC','numCustomers','transformerRating_kVA','Vmin_pu','Vmax_pu',...
        'primarySeason','primaryDay','smartMC');
end

allN=[];
for pl=1:length(penetrationLevels)
    pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
    allN(end+1)=convergenceLog.(cL).(pL).N;
end
numMC=max(allN);
fprintf('\nUncontrolled done %.1f min (iters %d-%d)\n',toc/60,min(allN),max(allN));

%% ===================== SMART CHARGING (fixed 100) =====================
fprintf('\n========== Smart Charging: %d kW (100 iters) ==========\n',P_charger);
ResultsSmart=struct();

for pl=1:length(penetrationLevels)
    penLevel=penetrationLevels(pl);
    numEVs=round(penLevel*numCustomers);
    pL=sprintf('Pen%d',round(penLevel*100));
    if numEVs==0, continue; end

    fprintf('Smart %d kW %d%%\n',P_charger,round(penLevel*100));

    java.lang.System.gc(); pause(1);
    DSSObj=createDSS();

    ResultsSmart.(cL).(pL).minVoltage=zeros(smartMC,1);
    ResultsSmart.(cL).(pL).peakTransformerLoad_pct=zeros(smartMC,1);
    ResultsSmart.(cL).(pL).peakCableLoad_pct=zeros(smartMC,1);
    ResultsSmart.(cL).(pL).totalLosses_kWh=zeros(smartMC,1);
    ResultsSmart.(cL).(pL).numCustViolated=zeros(smartMC,1);
    ResultsSmart.(cL).(pL).peakDemand_kW=zeros(smartMC,1);

    for mc=1:smartMC
        if mc>1 && mod(mc,comRefresh)==0
            DSSObj=refreshDSS(DSSObj);
        end

        try
            rng(mc*10000+P_charger*100+pl);
            [EVp,~,~]=EVProfileGenerator(numEVs,P_charger,chargerEfficiency,primarySeason,primaryDay);
            EVp_smart=ApplySmartCharging(EVp,smartChargingDelay);
            evIdx=sort(randperm(numCustomers,numEVs));
            evLoad=zeros(1440,numCustomers);
            for ev=1:numEVs, evLoad(:,evIdx(ev))=EVp_smart(:,ev); end
            totalLoad=baselineLoad+evLoad;

            [voltages,txL,cableL,losses,~]=RunOpenDSS(totalLoad,dssFilePath,numCustomers,DSSObj);

            ResultsSmart.(cL).(pL).minVoltage(mc)=min(voltages(:));
            ResultsSmart.(cL).(pL).peakTransformerLoad_pct(mc)=max(txL)/transformerRating_kVA*100;
            ResultsSmart.(cL).(pL).peakCableLoad_pct(mc)=max(cableL);
            ResultsSmart.(cL).(pL).totalLosses_kWh(mc)=sum(losses)/60;
            ResultsSmart.(cL).(pL).numCustViolated(mc)=sum(any((voltages<Vmin_pu)|(voltages>Vmax_pu),1));
            ResultsSmart.(cL).(pL).peakDemand_kW(mc)=max(sum(totalLoad,2));

            if mc==1
                ResultsSmart.(cL).(pL).sampleDemandProfile=totalLoad;
                ResultsSmart.(cL).(pL).sampleVoltageProfile=voltages;
            end

            clear EVp EVp_smart evIdx evLoad totalLoad voltages txL cableL losses;
        catch ME
            fprintf('  WARN Smart MC%d: %s\n',mc,ME.message);
            clear EVp EVp_smart evIdx evLoad totalLoad voltages txL cableL losses;
            DSSObj=refreshDSS(DSSObj);
        end
    end

    destroyDSS(DSSObj); clear DSSObj;
    java.lang.System.gc(); pause(1);
    fprintf('  Done\n');

    save(outFile,'Results','ResultsSmart','convergenceLog','P_charger',...
        'penetrationLevels','numMC','numCustomers','transformerRating_kVA',...
        'Vmin_pu','Vmax_pu','primarySeason','primaryDay','smartMC');
end

%% Convergence Summary
fprintf('\n=== CONVERGENCE: %d kW ===\n',P_charger);
fprintf('%-6s %-6s %-6s %-8s\n','Pen','N','Conv@','CoV');
fprintf('%s\n',repmat('-',1,30));
for pl=1:length(penetrationLevels)
    pL=sprintf('Pen%d',round(penetrationLevels(pl)*100));
    ci=convergenceLog.(cL).(pL);
    fprintf('%-6s %-6d %-6d %-8.4f\n',...
        sprintf('%d%%',round(penetrationLevels(pl)*100)),ci.N,ci.convergedAt,ci.finalCoV);
end
fprintf('\n=== %d kW complete ===\n',P_charger);
end

%% ===================== HELPER FUNCTIONS =====================

function DSSObj = createDSS()
%% Create a fresh OpenDSS COM object
    DSSObj = actxserver('OpenDSSEngine.DSS');
    if ~DSSObj.Start(0)
        error('OpenDSS failed to start');
    end
    DSSObj.AllowForms = false;
end

function DSSObj = refreshDSS(DSSObj)
%% Fully destroy and recreate the COM object to release all memory
    % Flush OpenDSS internal circuit data
    try
        DSSObj.Text.Command = 'Clear';
    catch
    end
    % Destroy COM object
    try
        delete(DSSObj);
    catch
    end
    clear DSSObj;
    % Force Java and Windows garbage collection
    java.lang.System.gc();
    pause(0.5);
    % Create fresh COM
    DSSObj = actxserver('OpenDSSEngine.DSS');
    if ~DSSObj.Start(0)
        error('OpenDSS failed to restart');
    end
    DSSObj.AllowForms = false;
end

function destroyDSS(DSSObj)
%% Final cleanup of COM object
    try
        DSSObj.Text.Command = 'Clear';
    catch
    end
    try
        delete(DSSObj);
    catch
    end
end