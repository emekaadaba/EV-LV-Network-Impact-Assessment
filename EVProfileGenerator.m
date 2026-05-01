function [EVp, EVt, Random_Values] = EVProfileGenerator(N, P, E, ...
Opt_Season, Opt_Day, Random_Values)
%% This function randomly simulates an EV charging profile for a single day

% V03: Seasonal profiles, including SoC outputs

%(1 minute resolution)
%
% Data taken from 
% https://ieeexplore.ieee.org/abstract/document/7381196
% http://myelectricavenue.info/sites/default/files/documents/9.8%20-%20vol%201.pdf
%
% The Nissan LEAF 24kWh) represents the SOC in 12 units/segments (2kWh per
% segment. A segment is filled in about 40 mins.
%
% INPUTS
% N: Number of EVs to simulate
% P: Peak demand of each EV (3.6 for slow charging)
% E: Efficiency (e.g. 0.8333)
% Opt_Season: 1;% 0:Generic 1:Winter 2:Spring 3:Summer 4:Autumn
% Opt_Day: 1;% 0;Generic 1:Weekday 2:Weekend
% Random_Values rand(N,6) used to replicate previous simulations
%
% OUTPUTS
% EVp: zeros(1440, N) Demand (kW) profiles 1min resolution for selected day
% EVt: zeros(N, 6) 1)time of connection 1 2)time of connection 2 
%                  3)length of connection 1 4)length of connection 2
%                  5)SoC1 6)SoC2


%% Check/select inptut values

% Produce a new set of random numbers?
if exist('Vals','var')==0
    Random_Values = rand(N,6);%Random numbers
end
% Is efficiency provided?
if exist('E','var') == 0
    E = 0.83333; %Efficiency
end
% Is a peak demand provided?
if exist('P','var') == 0
    P = 3.6;%Default slow charging
end

% Use generic profiles is the season or day data is missing
if exist('Opt_Season','var')==0
    Opt_Season = 0;
    Opt_Day = 0;
elseif exist('Opt_Day','var')==0
    Opt_Season = 0;
    Opt_Day = 0;
end

% Get PDFs
%Assumptions (up to two connections)
%Probability of of different SoC
[SOC_Initial, SOC_Final,Connection_Time] = getEVCDF(Opt_Season,Opt_Day);

% Based on literature charging a unit (2kWh) using a slow charger 
% requires 40mins
% Minutes required to charge a unit (2 kWh)
% Charge = Power*Efficiency*Minutes/60
% setting charge to 2 kWh
% 2 = Power*Efficiency*Minutes/60
Mns = 60 * 2 /(E*P); 

%EV profile
EVp=zeros(1440, N);
EVt=zeros(N, 6);
t1=zeros(N,1);
t2=zeros(N,1);
ct1=zeros(N,1);
ct2=zeros(N,1);

for n=1:N
    % First connection
    Connection = 1;
    
    %Get initial connection time
    [t1(n),v]=axInterp(Connection_Time(Connection,:),Random_Values(n,1));
    t1(n)=ceil((t1(n)-2+v)*60);%Minute when the EV is connected
    
    %Get time that the EV will remain connected the first time
    [soc1,v]=axInterp(SOC_Initial(Connection,:),Random_Values(n,2));
    soc1 = soc1-2 + v;
    
    [soc2,v]=axInterp(SOC_Final(Connection,:),Random_Values(n,3));
    soc2 = soc2-3 + v;
    
    if soc2<soc1
        %Enforce minimum connection time of 15 mins
        ct1(n) = max(ceil(min(Mns, 15)), 1);
        soc2 = soc1 + 15/Mns;
%         fprintf('1) %d\n',n);
    else
        %Connection time assuming that charging a unit (2kWh) requires 40mins
        ct1(n)=ceil((soc2-soc1)*Mns);
    end
    ax=t1(n)+ct1(n);
    if ax>1440
        EVp(t1(n):1440,n)=P;%Update profile
        EVp(1:ax-1440,n)=P;%Update profile
    else
        EVp(t1(n):ax,n)=P;%Update profile
    end
    EVt(n,5:6) = [soc1 soc2]/12;

    % Second connection
    Connection = 2;

    %Check for a second connection
    if t1(n)+ct1(n)<1440
        [t2(n),v]=axInterp(Connection_Time(Connection,:),Random_Values(n,4));
        t2(n)=ceil((t2(n)-2+v)*60);%Minute when the EV is connected
        if t2(n)<t1(n)+ct1(n)
            t2(n)=0;
            ct2(n)=0;
        else
            [soc1,v]=axInterp(SOC_Initial(Connection,:),Random_Values(n,5));
            soc1 = soc1-2 + v;

            [soc2,v]=axInterp(SOC_Final(Connection,:),Random_Values(n,6));
            soc2 = soc2-3 + v;

            if soc2<soc1
                %Enforce minimum connection time of 15 mins
                ct2(n) = max(ceil(min(Mns, 15)), 1);
                soc2 = soc1 + 15/Mns;
%                 fprintf('2) %d\n',n);
            else
                %Connection time assuming that charging a unit (2kWh) requires 40mins
                ct2(n)=ceil((soc2-soc1)*Mns);
            end
            
            ax=t2(n)+ct2(n);
            if ax>1440
                EVp(t2(n):1440,n)=P;%Update profile
                EVp(1:ax-1440,n)=P;%Update profile
            else
                EVp(t2(n):ax,n)=P;%Update profile
            end
        end
    else
        t2(n)=0;
        ct2(n)=0;
    end
    EVt(n,7:8) = [soc1 soc2]/12;
end
EVt(:,1:4) =[t1 t2 ct1 max(0, ct2)];


%% Auxiliar for the interpolations
function [x,v]=axInterp(vec,var)
x=2;
while vec(x)<var
    x=x+1;
end
v = (vec(x)-var)/(vec(x)-vec(x-1));

%% EV CDFs 
function [SOC_Initial, SOC_Final,Connection_Time] = getEVCDF(Opt_Season,Opt_Day)
% Default CDFs taken from:
%J. Quirós-Tortós, L. F. Ochoa and B. Lees, "A statistical analysis of EV
%charging behavior in the UK," 2015 IEEE PES ISGT LATAM, Montevideo, 2015, 
%pp. 445-449.

%Probability of of different SoC
SOC_Initial=[
    0 0.0057 0.0409 0.1247 0.2422 0.3608 0.4695 0.5857 0.7078 0.8024 ...
    0.8680 0.9288 0.9691 1.0000 1.0000001
    0 0.0091 0.0514 0.1269 0.2228 0.3179 0.4113 0.5230 0.6281 0.7135 ...
    0.7814 0.8605 0.9299 1.0000 1.0000001
    ];
SOC_Final=[
    0 0 0.0015 0.0054 0.0128 0.0206 0.0333 0.0540 0.0798 0.1153 0.1858 ...
    0.2592 0.3108 1.0000 1.0000001
    0 0.0005 0.0033 0.0129 0.0218 0.0339 0.0481 0.0729 0.1047 0.1410 ...
    0.2041 0.2989 0.3635 1.0000 1.0000001
    ];
%Probability of EVs connecting at a given time
Connection_Time=[
    0 0.0265 0.0364 0.0444 0.0527 0.0645 0.0863 0.1299 0.1945 0.2576 ...
    0.3022 0.3358 0.3672 0.3979 0.4299 0.4661 0.5161 0.5855 0.6743 ...
    0.7664 0.8395 0.8953 0.9387 0.9686 1.0000 1.0000001
    0 0.0013 0.0023 0.0033 0.0046 0.0059 0.0079 0.0121 0.0221 0.0395 ...
    0.0602 0.0857 0.1223 0.1703 0.2204 0.2713 0.3378 0.4243 0.5245 ...
    0.6269 0.7257 0.8200 0.8988 0.9581 1.0000 1.0000001
    ];

if Opt_Season ~= 0
%     Connection_Time(1,:) = buildEVCDF_Raw(Opt_Season,Opt_Day);
    Connection_Time(1,:) = buildEVCDF_HardCoded(Opt_Season,Opt_Day);
end

%% Outputs from buildEVCDF(Opt_Season,Opt_Day)
function Connection_TimeCDF = buildEVCDF_HardCoded(Opt_Season,Opt_Day)
switch Opt_Season
    case 1%Winter
        if Opt_Day == 1 %Weekday
            Connection_TimeCDF = [0 0.0329 0.0434 0.0505 0.0535 0.0580 ...
                0.0683 0.0947 0.1420 0.2017 0.2453 0.2724 0.3065 0.3483 ...
                0.3918 0.4284 0.4752 0.5430 0.6307 0.7287 0.8053 0.8627 ...
                0.9200 0.9678 1.0000 1.00001];
        else %Weekend
            Connection_TimeCDF = [0 0.0287 0.0399 0.0495 0.0558 0.0606 ...
                0.0682 0.0806 0.0943 0.1233 0.1625 0.2093 0.2757 0.3493 ...
                0.4180 0.4821 0.5530 0.6370 0.7214 0.7930 0.8425 0.8840 ...
                0.9295 0.9684 1.0000 1.00001];
        end
    case 2% Spring
        if Opt_Day == 1 %Weekday
            Connection_TimeCDF = [0 0.0096 0.0130 0.0174 0.0223 0.0317 ...
                0.0545 0.0941 0.1429 0.1842 0.2111 0.2382 0.2759 0.3184 ...
                0.3585 0.3971 0.4513 0.5360 0.6382 0.7364 0.8099 0.8735 ...
                0.9297 0.9636 1.0000 1.00001];
        else %Weekend
            Connection_TimeCDF = [0 0.0156 0.0247 0.0311 0.0405 0.0520 ...
                0.0642 0.0839 0.1156 0.1590 0.2040 0.2552 0.3160 0.3738 ...
                0.4343 0.4954 0.5613 0.6410 0.7189 0.7863 0.8403 0.8876 ...
                0.9309 0.9645 1.0000 1.00001];
        end
    case 3% Summer
        if Opt_Day == 1 %Weekday
            Connection_TimeCDF = [0 0.0056 0.0116 0.0176 0.0226 0.0303 ...
                0.0490 0.0898 0.1455 0.1892 0.2158 0.2465 0.2851 0.3236 ...
                0.3637 0.4051 0.4583 0.5382 0.6371 0.7335 0.8057 0.8680 ...
                0.9261 0.9652 1.0000 1.00001];
        else %Weekend
            Connection_TimeCDF = [0 0.0126 0.0248 0.0334 0.0379 0.0420 ...
                0.0503 0.0679 0.0997 0.1432 0.1921 0.2526 0.3175 0.3803 ...
                0.4443 0.5018 0.5654 0.6371 0.7062 0.7771 0.8395 0.8917 ...
                0.9370 0.9695 1.0000 1.00001];
        end
    case 4% Autumn
        if Opt_Day == 1 %Weekday
            Connection_TimeCDF = [0 0.0199 0.0273 0.0346 0.0413 0.0497 ...
                0.0614 0.0910 0.1439 0.1991 0.2344 0.2629 0.2973 0.3346 ...
                0.3733 0.4092 0.4586 0.5323 0.6260 0.7266 0.8033 0.8640 ...
                0.9218 0.9652 1.0000 1.00001];
        else %Weekend
            Connection_TimeCDF=[0 0.0205 0.0298 0.0379 0.0438 0.0491 ...
                0.0550 0.0694 0.0929 0.1285 0.1704 0.2200 0.2845 0.3525 ...
                0.4157 0.4733 0.5437 0.6352 0.7203 0.7873 0.8396 0.8877 ...
                0.9342 0.9702 1.0000 1.00001];
        end
end


%% Build CDFs using raw data
% This function is only included to show how the CDFs were produced, but
% it is not used as its outputs have been hard-coded in thims model
%
% Raw data taken from 
% http://myelectricavenue.info/sites/default/files/documents/9.8%20-%20vol%201.pdf
function Connection_TimeCDF = buildEVCDF_Raw(Opt_Season,Opt_Day)
switch Opt_Season
    case 1%Winter
        if Opt_Day == 1 %Weekday
            Connection_TimeRaw = [
                120 250 070 110 007 047 028 010 007 088 001 018 002 010 ...
                003 009 002 010 003 020 013 030 010 030 015 033 070 077 ...
                070 082 140 074 140 170 170 244 130 134 105 089 079 070 ...
                060 077 077 077 080 117 098 080 099 110 110 124 105 093 ...
                099 110 105 093 110 135 140 150 180 150 170 190 210 240 ...
                250 250 253 230 240 225 227 215 213 147 147 134 124 140 ...
                150 160 170 095 100 093 067 099 080 050 045 095];
        else %Weekend
            Connection_TimeRaw = [
                093 249 093 040 008 040 032 001 007 050 010 070 010 009 ...
                001 030 010 023 020 019 001 013 007 069 008 018 030 023 ...
                016 045 033 030 040 032 047 130 053 120 110 123 103 120 ...
                103 126 173 160 156 220 133 217 160 202 187 153 130 197 ...
                140 163 189 197 227 167 193 153 250 217 197 216 237 230 ...
                180 140 220 230 103 126 159 140 100 102 160 100 110 093 ...
                120 130 083 086 093 090 077 076 077 050 086 064];
        end
    case 2% Spring
        if Opt_Day == 1 %Weekday
            Connection_TimeRaw = [
                065 065 010 017 001 017 001 010 004 023 001 010 001 017 ...
                020 010 010 017 010 010 020 057 060 050 050 087 120 103 ...
                094 147 120 154 117 117 097 100 064 077 079 070 060 074 ...
                060 084 090 090 097 086 110 117 104 113 107 093 067 087 ...
                097 113 120 123 145 130 173 165 200 243 230 267 240 230 ...
                280 260 240 234 240 220 208 194 170 167 167 190 207 143 ...
                120 077 073 117 080 063 050 080 080 213 060 083];
        else %Weekend
            Connection_TimeRaw = [
                070 087 030 010 014 020 007 070 010 009 010 040 001 013 ...
                020 023 007 010 030 080 013 050 037 036 040 038 028 040 ...
                063 080 063 100 093 087 100 120 110 150 096 153 123 135 ...
                143 130 159 167 156 100 190 154 130 147 140 123 160 186 ...
                177 130 172 197 183 186 182 210 170 208 220 197 200 210 ...
                183 170 147 156 170 137 157 170 156 120 110 147 127 103 ...
                090 093 080 103 086 053 064 093 073 242 070 020];
        end
    case 3% Summer
        if Opt_Day == 1 %Weekday
            Connection_TimeRaw = [
                040 012 007 010 003 012 007 020 003 017 030 026 001 018 ...
                012 010 037 004 007 010 027 026 040 053 052 100 070 089 ...
                117 160 161 201 140 117 110 087 063 062 080 090 067 073 ...
                072 100 092 110 093 099 100 093 110 102 080 081 100 118 ...
                080 118 140 127 130 120 190 140 200 220 243 218 240 250 ...
                270 263 240 215 210 218 230 180 190 177 160 159 210 150 ...
                137 120 087 119 090 070 052 093 077 200 050 053];
        else %Weekend
            Connection_TimeRaw = [
                063 039 010 013 007 014 010 094 020 019 028 050 001 013 ...
                020 019 006 013 010 009 009 013 020 006 024 050 043 040 ...
                050 074 063 120 110 060 113 093 110 157 100 140 226 145 ...
                160 166 194 170 160 117 167 152 167 160 173 150 153 154 ...
                147 167 150 220 150 167 217 153 204 203 147 180 153 200 ...
                167 190 130 230 160 210 120 193 146 179 117 193 123 085 ...
                093 100 080 108 070 056 063 074 086 177 060 020];
        end
    case 4% Autumn
        if Opt_Day == 1 %Weekday
            Connection_TimeRaw = [
                090 150 027 089 010 013 007 010 007 057 023 020 007 010 ...
                007 013 020 023 023 030 037 020 013 030 027 050 057 063 ...
                080 120 160 157 130 173 167 153 110 101 105 090 068 074 ...
                070 094 070 100 080 090 088 090 100 097 100 096 100 090 ...
                089 097 117 120 100 133 193 150 167 180 223 218 200 236 ...
                237 273 294 236 240 250 230 207 200 160 160 170 153 156 ...
                140 138 120 110 120 077 060 097 070 110 057 100];
        else %Weekend
            Connection_TimeRaw=[
                110 187 017 026 020 013 005 027 007 040 023 050 001 013 ...
                010 017 010 018 017 030 001 020 010 009 017 037 023 033 ...
                030 063 073 056 070 060 080 156 063 130 090 152 120 119 ...
                123 150 170 147 194 190 160 143 170 160 176 153 130 183 ...
                137 143 150 170 227 176 210 214 247 250 277 220 219 250 ...
                177 160 132 164 177 140 127 128 150 149 143 137 120 125 ...
                086 110 095 105 086 077 057 097 060 100 073 040];
        end
end
saux = sum(Connection_TimeRaw);
Data_values = zeros(saux,1);
xDelta = 0.25;
xval = 0;
x1 = 0;
for x2=1:96
    xval = xval+xDelta;
    Data_values(x1+(1:Connection_TimeRaw(x2))) = xval * ...
        ones(Connection_TimeRaw(x2),1);
    x1 = x1+Connection_TimeRaw(x2);
end


T = 25; %Number of bins for PDF/CDF calculation (hours in a day)
[~, y]=getCDF(Data_values, T);
Connection_TimeCDF = [0 y 1.0000001];

Connection_TimeCDF';
error


function [x,y]=getCDF(dat,T)

%This function calculates the x and f(x) vector to plot the cumulative probability
%distribution of a vector 'dat', considering T ranges. This function is
%used with the plot function as:  [x,y]=plotaux(dat,T);plot(x,y);

if exist('T','var')==0
    T=101;
end

[x1,y1]=getPDF(dat,T);

y2=zeros(1,T);
for i=2:T
    y2(i)=(y1(i-1)+y1(i))*(x1(i)-x1(i-1));
end
y2=y2/2;

x=x1(2:T)-(x1(2)-x1(1))/2;
y=zeros(1,T-1);
aux=0;
for i=1:T-1
    aux=aux+y2(i);
    y(i)=aux+y2(i+1);
end

function [x,y]=getPDF(dat,T)
%This function calculates the x and f(x) vector to plot the probability
%distribution of a vector 'dat', considering T ranges. This function is
%used with the plot function as:  [x,y]=plotaux(dat,T);plot(x,y);
if exist('T','var')==0
    T=100;
end
s=size(dat);
if s(1)>s(2)
    au.d=[sort(dat);NaN];
else
    au.d=[sort(dat) NaN];
end

x=linspace(min(au.d),max(au.d),T+1);
y=zeros(1,T);
au.c=1;
for z=1:T
    while au.d(au.c)<=x(z+1)
        y(z)=y(z)+1;
        au.c=au.c+1;
    end
end
x=x-(x(2)-x(1))/2;
x=x(2:T+1);
y=y/funInteg(x,y);
