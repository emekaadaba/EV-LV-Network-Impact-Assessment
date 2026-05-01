function [voltages, txLoading, cableLoading, losses, txPower] = ...
    RunOpenDSS(totalLoad, dssFilePath, numCustomers, DSSObj)
%% RunOpenDSS - Execute time-series power flow in OpenDSS via COM interface
%
% INPUTS:
%   totalLoad     - [1440 x numCustomers] load matrix in kW
%   dssFilePath   - Path to the UK_LV_Network.dss file
%   numCustomers  - Number of customers
%   DSSObj        - OpenDSS COM object (managed by caller)
%
% OUTPUTS:
%   voltages      - [1440 x numCustomers] voltage in p.u.
%   txLoading     - [1440 x 1] transformer loading in kVA
%   cableLoading  - [1440 x 1] max cable loading as % of rating
%   losses        - [1440 x 1] total network losses in kW
%   txPower       - [1440 x 1] transformer active power in kW

%% Get COM sub-objects and re-compile network (resets state)
DSSText = DSSObj.Text;
DSSText.Command = sprintf('Compile "%s"', dssFilePath);

DSSCircuit = DSSObj.ActiveCircuit;
DSSSolution = DSSCircuit.Solution;

DSSText.Command = 'Set Mode=Snapshot';
DSSText.Command = 'Set ControlMode=Static';

%% Cable ampacity
mainCableAmpacity = 275;  % 185mm² Al CNE (A)

%% Build customer load/bus name mapping
loadNames = cell(numCustomers, 1);
custBusNames = cell(numCustomers, 1);
idx = 1;
for i = 1:20
    if idx > numCustomers, break; end
    loadNames{idx} = sprintf('Customer_F1_%d', i);
    custBusNames{idx} = sprintf('Cust_F1_%d', i);
    idx = idx + 1;
end
for i = 1:18
    if idx > numCustomers, break; end
    loadNames{idx} = sprintf('Customer_F2_%d', i);
    custBusNames{idx} = sprintf('Cust_F2_%d', i);
    idx = idx + 1;
end
for i = 1:17
    if idx > numCustomers, break; end
    loadNames{idx} = sprintf('Customer_F3_%d', i);
    custBusNames{idx} = sprintf('Cust_F3_%d', i);
    idx = idx + 1;
end

%% Feeder lines for cable loading check
feederLines = {'Feeder1_Main', 'Feeder2_Main', 'Feeder3_Main', ...
               'F1_Seg1', 'F1_Seg2', 'F1_Seg3', ...
               'F2_Seg1', 'F2_Seg2', ...
               'F3_Seg1', 'F3_Seg2'};

%% Pre-allocate output arrays
nPts = 1440;
voltages = zeros(nPts, numCustomers);
txLoading = zeros(nPts, 1);
txPower = zeros(nPts, 1);
cableLoading = zeros(nPts, 1);
losses = zeros(nPts, 1);

%% Time-series power flow (snapshot per timestep)
for t = 1:nPts
    % Update each customer load
    for c = 1:numCustomers
        DSSText.Command = sprintf('Load.%s.kW=%.4f', loadNames{c}, totalLoad(t,c));
    end
    
    % Solve
    DSSSolution.Solve;
    
    % Retry on non-convergence
    if ~DSSSolution.Converged
        DSSText.Command = 'Set Tolerance=0.001';
        DSSText.Command = 'Set Maxiterations=300';
        DSSSolution.Solve;
        DSSText.Command = 'Set Tolerance=0.0001';
        DSSText.Command = 'Set Maxiterations=100';
    end
    
    % --- Voltages ---
    for c = 1:numCustomers
        try
            DSSCircuit.SetActiveBus(custBusNames{c});
            busV = DSSCircuit.ActiveBus.puVoltages;
            if length(busV) >= 2
                voltages(t,c) = sqrt(busV(1)^2 + busV(2)^2);
            end
        catch
            if t > 1, voltages(t,c) = voltages(t-1,c);
            else, voltages(t,c) = 1.0; end
        end
    end
    
    % --- Transformer ---
    try
        DSSCircuit.SetActiveElement('Transformer.MainTX');
        txP = DSSCircuit.ActiveCktElement.Powers;
        if length(txP) >= 6
            P = abs(txP(1)) + abs(txP(3)) + abs(txP(5));
            Q = abs(txP(2)) + abs(txP(4)) + abs(txP(6));
            txLoading(t) = sqrt(P^2 + Q^2);
            txPower(t) = P;
        end
    catch
        if t > 1, txLoading(t) = txLoading(t-1); txPower(t) = txPower(t-1); end
    end
    
    % --- Cable loading ---
    maxUtil = 0;
    for fl = 1:length(feederLines)
        try
            DSSCircuit.SetActiveElement(sprintf('Line.%s', feederLines{fl}));
            lineI = DSSCircuit.ActiveCktElement.CurrentsMagAng;
            if ~isempty(lineI)
                maxI = max(lineI(1:2:end));
                maxUtil = max(maxUtil, maxI / mainCableAmpacity * 100);
            end
        catch
        end
    end
    cableLoading(t) = maxUtil;
    
    % --- Losses ---
    try
        L = DSSCircuit.Losses;
        losses(t) = L(1) / 1000;
    catch
        if t > 1, losses(t) = losses(t-1); end
    end
end

end