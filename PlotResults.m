%% PlotResults.m
% =======================================================================
% 12 figures. No text inside graphs. All legends OUTSIDE plot area.
% Calibri 12pt. 300 DPI PNG. close(fig) after each export for memory.
%
% Fig 1:  EV Demand Profiles (zoomed evening)
% Fig 2:  Combined Network Demand
% Fig 3:  Voltage Profiles
% Fig 4:  Min Voltage vs Penetration
% Fig 5:  TX Loading vs Penetration
% Fig 6:  Cable Loading vs Penetration
% Fig 7:  Network Losses vs Penetration
% Fig 8:  Hosting Capacity
% Fig 9:  Smart Charging Demand
% Fig 10: Smart Charging TX Loading
% Fig 11: 4-Panel Charger Comparison (V, TX, Cable, Losses)
% Fig 12: Voltage Violation Probability
% =======================================================================

if ~exist('Results','var')
    if exist('SimulationResults.mat','file'), load('SimulationResults.mat');
    else, error('No results.'); end
end
outputDir='Figures'; if ~exist(outputDir,'dir'), mkdir(outputDir); end

timeHours=(0:1439)/60; penPct=penetrationLevels*100;
nPen=length(penetrationLevels); nCP=length(chargerPowers);

set(groot,'defaultAxesFontName','Calibri','defaultTextFontName','Calibri');
FA=12; FL=12; FT=13; FG=10; FS=14; LW=1.5; MS=5;
clrs=[0 .45 .74; .93 .69 .13; .85 .33 .10];
CC=struct(); for cp=1:nCP, CC.(sprintf('P%dkW',chargerPowers(cp)))=clrs(min(cp,3),:); end
mkL=@(P)sprintf('%d kW',P);
getNmc=@(R)length(R.peakDemand_kW);
midP=round(nPen/2);

%% FIG 1: EV Demand Profiles (zoomed 14:00-02:00)
fig=figure('Position',[100 100 380*nCP 380]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); pL=sprintf('Pen%d',round(penetrationLevels(midP)*100));
    R=Results.(cL).(pL); ax=subplot(1,nCP,cp);
    if isfield(R,'sampleEVProfile')&&~isempty(R.sampleEVProfile)
        evP=R.sampleEVProfile; hold on;
        for c=1:size(evP,2)
            if max(evP(:,c))>0, plot(timeHours,evP(:,c),'Color',[.78 .78 .93],'LineWidth',0.3,'HandleVisibility','off'); end
        end
        plot(timeHours,sum(evP,2),'Color',CC.(cL),'LineWidth',LW+0.5,'DisplayName','Aggregate EV');
        hold off;
    end
    xlabel('Time (hours)','FontSize',FL); ylabel('Power (kW)','FontSize',FL);
    title(sprintf('%d kW – %d%%',chargerPowers(cp),round(penetrationLevels(midP)*100)),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA,'XTick',14:2:26); xlim([14 26]); grid on; box on;
end
sgtitle('EV Charging Demand (Winter Weekday)','FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig1_EV_Demand_Profiles.png'),'Resolution',300);
fprintf('  Fig1\n'); close(fig);

%% FIG 2: Combined Network Demand
fig=figure('Position',[100 100 380*nCP 380]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp));
    pIdx=unique(round(linspace(1,nPen,4))); cols=lines(length(pIdx));
    ax=subplot(1,nCP,cp); hold on;
    for pp=1:length(pIdx)
        idx=pIdx(pp); pL=sprintf('Pen%d',round(penetrationLevels(idx)*100));
        R=Results.(cL).(pL);
        if isfield(R,'sampleDemandProfile')&&~isempty(R.sampleDemandProfile)
            plot(timeHours,sum(R.sampleDemandProfile,2),'Color',cols(pp,:),'LineWidth',LW,...
                'DisplayName',sprintf('%d%%',round(penetrationLevels(idx)*100)));
        end
    end
    plot([0 24],[transformerRating_kVA transformerRating_kVA],'r--','LineWidth',LW,'DisplayName','TX Rating');
    hold off;
    xlabel('Time (hours)','FontSize',FL); ylabel('Demand (kW)','FontSize',FL);
    title(sprintf('%d kW',chargerPowers(cp)),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA,'XTick',0:4:24); xlim([0 24]); grid on; box on;
end
sgtitle('Aggregate Network Demand','FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig2_Combined_Demand.png'),'Resolution',300);
fprintf('  Fig2\n'); close(fig);

%% FIG 3: Voltage Profiles
fig=figure('Position',[100 100 380*nCP 380]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); pL=sprintf('Pen%d',round(penetrationLevels(midP)*100));
    R=Results.(cL).(pL); ax=subplot(1,nCP,cp);
    if isfield(R,'sampleVoltageProfile')&&~isempty(R.sampleVoltageProfile)
        hold on;
        for c=1:size(R.sampleVoltageProfile,2)
            plot(timeHours,R.sampleVoltageProfile(:,c),'Color',[.6 .6 .85],'LineWidth',0.3,'HandleVisibility','off');
        end
        plot([0 24],[Vmin_pu Vmin_pu],'r--','LineWidth',LW,'DisplayName',sprintf('%.1f p.u. limit',Vmin_pu));
        hold off;
    end
    xlabel('Time (hours)','FontSize',FL); ylabel('Voltage (p.u.)','FontSize',FL);
    title(sprintf('%d kW – %d%%',chargerPowers(cp),round(penetrationLevels(midP)*100)),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA,'XTick',0:6:24); xlim([0 24]); ylim([0.88 1.03]); grid on; box on;
end
sgtitle(sprintf('Voltage Profiles at %d%% Penetration',round(penetrationLevels(midP)*100)),'FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig3_Voltage_Profiles.png'),'Resolution',300);
fprintf('  Fig3\n'); close(fig);

%% FIGS 4-6: Metrics vs Penetration
mF={'minVoltage','peakTransformerLoad_pct','peakCableLoad_pct'};
mY={'Min Voltage (p.u.)','Peak TX Loading (%)','Peak Cable Loading (%)'};
mT={'Minimum Voltage','Transformer Loading','Cable Loading'};
mLv={Vmin_pu,100,100}; mLN={sprintf('%.1f p.u.',Vmin_pu),'100% rated','100% ampacity'};
fN=[4 5 6];
for mi=1:3
    fig=figure('Position',[100 100 420*nCP 380]);
    for cp=1:nCP
        cL=sprintf('P%dkW',chargerPowers(cp)); ax=subplot(1,nCP,cp);
        mn=zeros(nPen,1);sd=zeros(nPen,1);lo=zeros(nPen,1);hi=zeros(nPen,1);
        for pl=1:nPen
            d=Results.(cL).(sprintf('Pen%d',round(penetrationLevels(pl)*100))).(mF{mi});
            mn(pl)=mean(d);sd(pl)=std(d);lo(pl)=min(d);hi(pl)=max(d);
        end
        hold on;
        fill([penPct fliplr(penPct)],[lo' fliplr(hi')],CC.(cL),'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
        errorbar(penPct,mn,sd,'-o','LineWidth',LW,'Color',CC.(cL),'MarkerFaceColor',CC.(cL),'MarkerSize',MS,'DisplayName','Mean +/- 1\sigma');
        plot([0 100],[mLv{mi} mLv{mi}],'r--','LineWidth',LW,'DisplayName',mLN{mi});
        hold off;
        xlabel('Penetration (%)','FontSize',FL); ylabel(mY{mi},'FontSize',FL);
        title(sprintf('%d kW',chargerPowers(cp)),'FontSize',FT);
        legend('Location','northeastoutside','FontSize',FG);
        set(ax,'FontSize',FA,'XTick',0:20:100); grid on; box on;
    end
    sgtitle(sprintf('%s vs Penetration',mT{mi}),'FontSize',FS);
    exportgraphics(fig,fullfile(outputDir,sprintf('Fig%d_%s.png',fN(mi),strrep(mT{mi},' ',''))),'Resolution',300);
    fprintf('  Fig%d\n',fN(mi)); close(fig);
end

%% FIG 7: Network Losses
fig=figure('Position',[100 100 650 400]);
hold on;
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp));
    mn=zeros(nPen,1);sd=zeros(nPen,1);
    for pl=1:nPen
        d=Results.(cL).(sprintf('Pen%d',round(penetrationLevels(pl)*100))).totalLosses_kWh;
        mn(pl)=mean(d);sd(pl)=std(d);
    end
    errorbar(penPct,mn,sd,'-o','LineWidth',LW,'Color',CC.(cL),'MarkerFaceColor',CC.(cL),'MarkerSize',MS,'DisplayName',mkL(chargerPowers(cp)));
end
hold off;
xlabel('Penetration (%)','FontSize',FL); ylabel('Daily Losses (kWh)','FontSize',FL);
title('Network Energy Losses','FontSize',FT);
legend('Location','northeastoutside','FontSize',FG);
set(gca,'FontSize',FA,'XTick',0:20:100); grid on; box on;
exportgraphics(fig,fullfile(outputDir,'Fig7_NetworkLosses.png'),'Resolution',300);
fprintf('  Fig7\n'); close(fig);

%% FIG 8: Hosting Capacity
fig=figure('Position',[100 100 700 420]);
hcD=zeros(nCP,3); labs={};
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); HV=100;HT=100;HC2=100;
    for pl=2:nPen
        R=Results.(cL).(sprintf('Pen%d',round(penetrationLevels(pl)*100)));
        nI=getNmc(R);
        if sum(R.numCustViolated>0)/nI>0.05&&HV==100, HV=penetrationLevels(pl-1)*100; end
        if mean(R.peakTransformerLoad_pct)>100&&HT==100, HT=penetrationLevels(pl-1)*100; end
        if mean(R.peakCableLoad_pct)>100&&HC2==100, HC2=penetrationLevels(pl-1)*100; end
    end
    hcD(cp,:)=[HV HT HC2]; labs{cp}=sprintf('%d kW',chargerPowers(cp));
end
b=bar(hcD); b(1).FaceColor=[.2 .6 .9]; b(2).FaceColor=[.9 .6 .2]; b(3).FaceColor=[.5 .8 .5];
set(gca,'XTickLabel',labs,'FontSize',FA);
legend('Voltage','Transformer','Cable','Location','northeastoutside','FontSize',FG);
xlabel('Charger Rating','FontSize',FL); ylabel('Hosting Capacity (%)','FontSize',FL);
title('Hosting Capacity by Constraint','FontSize',FT); ylim([0 110]); grid on; box on;
exportgraphics(fig,fullfile(outputDir,'Fig8_HostingCapacity.png'),'Resolution',300);
fprintf('  Fig8\n'); close(fig);

%% FIG 9-10: Smart Charging
hasSC=exist('ResultsSmart','var')&&isstruct(ResultsSmart)&&~isempty(fieldnames(ResultsSmart));
if hasSC
    % Fig 9: Demand comparison
    fig=figure('Position',[100 100 380*nCP 380]);
    pL=sprintf('Pen%d',round(penetrationLevels(midP)*100));
    for cp=1:nCP
        cL=sprintf('P%dkW',chargerPowers(cp)); ax=subplot(1,nCP,cp);
        if isfield(ResultsSmart,cL)&&isfield(ResultsSmart.(cL),pL)
            p0=sprintf('Pen%d',round(penetrationLevels(1)*100));
            hold on;
            plot(timeHours,sum(Results.(cL).(p0).sampleDemandProfile,2),'k-','LineWidth',1,'DisplayName','No EVs');
            plot(timeHours,sum(Results.(cL).(pL).sampleDemandProfile,2),'r-','LineWidth',LW,'DisplayName','Uncontrolled');
            plot(timeHours,sum(ResultsSmart.(cL).(pL).sampleDemandProfile,2),'b-','LineWidth',LW,'DisplayName','Smart');
            hold off;
        end
        xlabel('Time (hours)','FontSize',FL); ylabel('Demand (kW)','FontSize',FL);
        title(sprintf('%d kW – %d%%',chargerPowers(cp),round(penetrationLevels(midP)*100)),'FontSize',FT);
        legend('Location','northeastoutside','FontSize',FG);
        set(ax,'FontSize',FA,'XTick',0:4:24); xlim([0 24]); grid on; box on;
    end
    sgtitle('Uncontrolled vs Smart Charging','FontSize',FS);
    exportgraphics(fig,fullfile(outputDir,'Fig9_SmartCharging_Demand.png'),'Resolution',300);
    fprintf('  Fig9\n'); close(fig);

    % Fig 10: TX Loading comparison
    fig=figure('Position',[100 100 380*nCP 380]);
    for cp=1:nCP
        cL=sprintf('P%dkW',chargerPowers(cp)); ax=subplot(1,nCP,cp);
        mU=[];mS=[];pP=[];
        for pl=2:nPen
            pL2=sprintf('Pen%d',round(penetrationLevels(pl)*100));
            if isfield(ResultsSmart,cL)&&isfield(ResultsSmart.(cL),pL2)
                mU(end+1)=mean(Results.(cL).(pL2).peakTransformerLoad_pct);
                mS(end+1)=mean(ResultsSmart.(cL).(pL2).peakTransformerLoad_pct);
                pP(end+1)=penPct(pl);
            end
        end
        hold on;
        plot(pP,mU,'r-o','LineWidth',LW,'MarkerFaceColor','r','MarkerSize',MS,'DisplayName','Uncontrolled');
        plot(pP,mS,'b-s','LineWidth',LW,'MarkerFaceColor','b','MarkerSize',MS,'DisplayName','Smart');
        hold off;
        xlabel('Penetration (%)','FontSize',FL); ylabel('TX Loading (%)','FontSize',FL);
        title(sprintf('%d kW',chargerPowers(cp)),'FontSize',FT);
        legend('Location','northeastoutside','FontSize',FG);
        set(ax,'FontSize',FA); grid on; box on;
    end
    sgtitle('TX Loading: Uncontrolled vs Smart','FontSize',FS);
    exportgraphics(fig,fullfile(outputDir,'Fig10_SmartCharging_TXLoading.png'),'Resolution',300);
    fprintf('  Fig10\n'); close(fig);
else, fprintf('  Skip Fig9-10 (no smart data)\n'); end

%% FIG 11: 4-Panel Charger Comparison
fig=figure('Position',[100 100 950 750]);
sM={'minVoltage','peakTransformerLoad_pct','peakCableLoad_pct','totalLosses_kWh'};
sY={'Min Voltage (p.u.)','TX Loading (%)','Cable Loading (%)','Losses (kWh)'};
sT={'Min Voltage','TX Loading','Cable Loading','Losses'};
sLim=[Vmin_pu 100 100 NaN];
for si=1:4
    subplot(2,2,si); hold on;
    for cp=1:nCP
        cL=sprintf('P%dkW',chargerPowers(cp)); v=zeros(nPen,1);
        for pl=1:nPen, v(pl)=mean(Results.(cL).(sprintf('Pen%d',round(penetrationLevels(pl)*100))).(sM{si})); end
        plot(penPct,v,'-o','LineWidth',LW,'Color',CC.(cL),'MarkerFaceColor',CC.(cL),'MarkerSize',MS,'DisplayName',mkL(chargerPowers(cp)));
    end
    if ~isnan(sLim(si)), plot([0 100],[sLim(si) sLim(si)],'r--','LineWidth',1,'DisplayName','Limit'); end
    hold off;
    xlabel('Penetration (%)','FontSize',FL-1); ylabel(sY{si},'FontSize',FL-1);
    title(sT{si},'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG-1);
    set(gca,'FontSize',FA-1,'XTick',0:20:100); grid on; box on;
end
sgtitle('Charger Power Comparison','FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig11_Charger_Comparison.png'),'Resolution',300);
fprintf('  Fig11\n'); close(fig);

%% FIG 12: Voltage Violation Probability
fig=figure('Position',[100 100 650 400]);
mkrs={'o','s','d'}; hold on;
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); pV=zeros(nPen,1);
    for pl=1:nPen
        R=Results.(cL).(sprintf('Pen%d',round(penetrationLevels(pl)*100)));
        pV(pl)=sum(R.numCustViolated>0)/getNmc(R)*100;
    end
    plot(penPct,pV,['-' mkrs{min(cp,3)}],'LineWidth',LW,'Color',CC.(cL),'MarkerFaceColor',CC.(cL),'MarkerSize',MS+1,'DisplayName',mkL(chargerPowers(cp)));
end
plot([0 100],[5 5],'r--','LineWidth',1,'DisplayName','5% threshold');
hold off;
xlabel('Penetration (%)','FontSize',FL); ylabel('Violation Prob. (%)','FontSize',FL);
title('Voltage Violation Probability','FontSize',FT);
legend('Location','northeastoutside','FontSize',FG);
set(gca,'FontSize',FA,'XTick',0:20:100); grid on; box on;
exportgraphics(fig,fullfile(outputDir,'Fig12_VoltageViolationProb.png'),'Resolution',300);
fprintf('  Fig12\n'); close(fig);

set(groot,'defaultAxesFontName','remove','defaultTextFontName','remove');
fprintf('\nAll 12 figures saved to %s/\n',outputDir);