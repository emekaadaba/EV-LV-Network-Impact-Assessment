%% MCConfidenceAnalysis.m
% =======================================================================
% 4 figures. All legends OUTSIDE. No text inside plots.
% close(fig) after each for memory.
%
% Fig 13: Peak Demand Distributions (histograms)
% Fig 14: P95 Demand Envelopes
% Fig 15: CoV Convergence
% Fig 16: Running Mean Convergence
% =======================================================================

if ~exist('Results','var')
    if exist('SimulationResults.mat','file'), load('SimulationResults.mat');
    else, error('No data'); end
end
outputDir='Figures'; if ~exist(outputDir,'dir'), mkdir(outputDir); end
nPen=length(penetrationLevels); nCP=length(chargerPowers);
timeHours=(0:1439)/60;
set(groot,'defaultAxesFontName','Calibri','defaultTextFontName','Calibri');
FA=12;FL=12;FT=13;FG=10;FS=14;LW=1.5;
clrs=[0 .45 .74;.93 .69 .13;.85 .33 .10];
getNmc=@(R)length(R.peakDemand_kW);
midP=round(nPen/2);

%% FIG 13: Peak Demand Distributions
fprintf('Fig13: Peak Demand Distributions\n');
penTgt=[0.30 0.50 1.00]; nT=length(penTgt);
fig=figure('Position',[50 50 400*nCP 270*nT]);
pI=0;
for pt=1:nT
    [~,plI]=min(abs(penetrationLevels-penTgt(pt)));
    pL=sprintf('Pen%d',round(penetrationLevels(plI)*100));
    for cp=1:nCP
        pI=pI+1; cL=sprintf('P%dkW',chargerPowers(cp));
        pk=Results.(cL).(pL).peakDemand_kW; nI=length(pk);
        ax=subplot(nT,nCP,pI);
        histogram(pk,30,'FaceColor',clrs(cp,:),'FaceAlpha',0.7,'EdgeColor','w','DisplayName',sprintf('N=%d',nI));
        hold on;
        xline(mean(pk),'k-','LineWidth',2,'DisplayName',sprintf('Mean=%.0f kW',mean(pk)));
        xline(prctile(pk,95),'r--','LineWidth',2,'DisplayName',sprintf('P95=%.0f kW',prctile(pk,95)));
        hold off;
        xlabel('Peak Demand (kW)','FontSize',FL);
        if cp==1, ylabel(sprintf('%d%%',round(penetrationLevels(plI)*100)),'FontSize',FL);
        else, ylabel('Count','FontSize',FL); end
        if pt==1, title(sprintf('%d kW',chargerPowers(cp)),'FontSize',FT); end
        legend('Location','northeastoutside','FontSize',FG-1);
        set(ax,'FontSize',FA); grid on; box on;
    end
end
sgtitle('Peak Demand Distributions','FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig13_PeakDemand_MC_Distribution.png'),'Resolution',300);
fprintf('  Done\n'); close(fig);

%% FIG 14: P95 Demand Envelopes (zoomed evening)
fprintf('Fig14: P95 Envelopes\n');
pL=sprintf('Pen%d',round(penetrationLevels(midP)*100));
fig=figure('Position',[100 100 380*nCP 380]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); R=Results.(cL).(pL);
    ax=subplot(1,nCP,cp);
    if isfield(R,'sampleDemandProfile')&&~isempty(R.sampleDemandProfile)
        agg=sum(R.sampleDemandProfile,2); pk0=max(agg);
        if pk0>0
            s95=prctile(R.peakDemand_kW,95)/pk0;
            s05=prctile(R.peakDemand_kW,5)/pk0;
            sMn=mean(R.peakDemand_kW)/pk0;
        else, s95=1;s05=1;sMn=1; end
        hold on;
        fill([timeHours fliplr(timeHours)],[agg'*s05 fliplr(agg'*s95)],clrs(cp,:),...
            'FaceAlpha',0.2,'EdgeColor','none','DisplayName','P5–P95 range');
        plot(timeHours,agg*sMn,'-','Color',clrs(cp,:),'LineWidth',1,'DisplayName','Mean');
        plot(timeHours,agg*s95,'--','Color',clrs(cp,:)*0.6,'LineWidth',2,'DisplayName','P95');
        hold off;
    end
    xlabel('Time (hours)','FontSize',FL); ylabel('Demand (kW)','FontSize',FL);
    title(sprintf('%d kW – %d%%',chargerPowers(cp),round(penetrationLevels(midP)*100)),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA,'XTick',14:2:26); xlim([14 26]); grid on; box on;
end
sgtitle(sprintf('Demand Envelopes (%d%% Penetration)',round(penetrationLevels(midP)*100)),'FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig14_P95_Demand_Profiles.png'),'Resolution',300);
fprintf('  Done\n'); close(fig);

%% FIG 15: CoV Convergence
fprintf('Fig15: CoV Convergence\n');
hiP=max(2,round(nPen*0.7));
pL=sprintf('Pen%d',round(penetrationLevels(hiP)*100));
metrics={'peakDemand_kW','minVoltage','peakTransformerLoad_pct','peakCableLoad_pct'};
mNm={'Peak Demand','Min Voltage','TX Loading','Cable Loading'};
fig=figure('Position',[50 50 600 330*nCP]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); R=Results.(cL).(pL); nI=getNmc(R);
    ax=subplot(nCP,1,cp); hold on; mC=lines(4);
    for m=1:4
        d=R.(metrics{m}); Nv=10:nI; cv=zeros(length(Nv),1);
        for ni=1:length(Nv)
            sub=d(1:Nv(ni));
            if abs(mean(sub))>0, cv(ni)=std(sub)/abs(mean(sub))*100; end
        end
        plot(Nv,cv,'-','LineWidth',LW,'Color',mC(m,:),'DisplayName',mNm{m});
    end
    hold off;
    xlabel('Iterations','FontSize',FL); ylabel('CoV (%)','FontSize',FL);
    title(sprintf('%d kW – %d%% (N=%d)',chargerPowers(cp),round(penetrationLevels(hiP)*100),nI),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA); xlim([10 nI]); grid on; box on;
end
sgtitle(sprintf('MC Convergence (%d%% Penetration)',round(penetrationLevels(hiP)*100)),'FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig15_CoV_Convergence.png'),'Resolution',300);
fprintf('  Done\n'); close(fig);

%% FIG 16: Running Mean Convergence
fprintf('Fig16: Running Mean\n');
fig=figure('Position',[50 50 380*nCP 350]);
for cp=1:nCP
    cL=sprintf('P%dkW',chargerPowers(cp)); pk=Results.(cL).(pL).peakDemand_kW; nI=length(pk);
    ax=subplot(1,nCP,cp);
    rM=cumsum(pk)./(1:nI)'; rS=zeros(nI,1);
    for n=2:nI, rS(n)=std(pk(1:n)); end
    rSE=rS./sqrt((1:nI)'); rU=rM+1.96*rSE; rL=rM-1.96*rSE; vi=10:nI;
    hold on;
    fill([vi fliplr(vi)],[rL(vi)' fliplr(rU(vi)')],clrs(cp,:),'FaceAlpha',0.2,'EdgeColor','none','DisplayName','95% CI');
    plot(1:nI,rM,'-','Color',clrs(cp,:),'LineWidth',2,'DisplayName',sprintf('Mean (final=%.0f kW)',rM(end)));
    hold off;
    xlabel('Iteration','FontSize',FL); ylabel('Running Mean (kW)','FontSize',FL);
    title(sprintf('%d kW (N=%d)',chargerPowers(cp),nI),'FontSize',FT);
    legend('Location','northeastoutside','FontSize',FG);
    set(ax,'FontSize',FA); xlim([1 nI]); grid on; box on;
end
sgtitle(sprintf('Running Mean Convergence (%d%% Pen)',round(penetrationLevels(hiP)*100)),'FontSize',FS);
exportgraphics(fig,fullfile(outputDir,'Fig16_RunningMean_Convergence.png'),'Resolution',300);
fprintf('  Done\n'); close(fig);

set(groot,'defaultAxesFontName','remove','defaultTextFontName','remove');
fprintf('\nMC analysis complete (4 figures).\n');