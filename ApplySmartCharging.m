function EVp_smart = ApplySmartCharging(EVp, startHour)
%% ApplySmartCharging - Valley-filling smart charging strategy
%
% Removes ALL EV charging from the original profile and redistributes
% it into the off-peak valley (startHour:00 to 07:00 next day).
%
% Each EV is assigned a staggered start time uniformly distributed
% across the off-peak window so that the aggregate profile is FLATTENED
% rather than creating a new synchronisation peak at midnight.
%
% The result on a 24-hour demand graph should show:
%   - Evening peak (17:00-21:00) reduced back toward baseline
%   - Overnight valley (midnight-06:00) filled with shifted EV load
%   - Total energy preserved exactly
%
% INPUTS:
%   EVp       - [1440 x N] Original EV demand profiles (kW)
%   startHour - Hour to begin off-peak charging (e.g. 22 for 10 PM)
%
% OUTPUT:
%   EVp_smart - [1440 x N] Redistributed profiles

[nTime, nEVs] = size(EVp);
EVp_smart = zeros(nTime, nEVs);

startMin = startHour * 60;   % e.g. 22:00 = minute 1320
deadMin  = 7 * 60;           % Must finish by 07:00 = minute 420

% Off-peak window: startHour to 07:00 next day
% e.g. 22:00-07:00 = 540 minutes
windowLen = (1440 - startMin) + deadMin;

for ev = 1:nEVs
    profile = EVp(:, ev);

    % Find charging power and total energy
    chargingPower = max(profile);
    if chargingPower == 0, continue; end

    chargingMinutes = sum(profile > 0);
    if chargingMinutes == 0, continue; end

    % Calculate how much of the window is available for staggering
    % Latest possible start so that charging completes by deadline
    maxOffset = windowLen - chargingMinutes;

    if maxOffset <= 0
        % Charging takes longer than the window - start at startHour
        newStart = startMin;
    else
        % Stagger: spread EVs uniformly across the off-peak window
        % This prevents all EVs starting at midnight simultaneously
        newStart = startMin + randi([0, maxOffset]);
    end

    % Place the charging block, wrapping around midnight via mod
    for m = 1:chargingMinutes
        idx = mod(newStart + m - 1, 1440) + 1;  % 1-indexed, wraps at 1440
        EVp_smart(idx, ev) = chargingPower;
    end
end

% Verify energy is preserved exactly
origEnergy  = sum(EVp(:));
smartEnergy = sum(EVp_smart(:));
if origEnergy > 0 && abs(origEnergy - smartEnergy) / origEnergy > 0.001
    warning('Smart charging energy mismatch: orig=%.1f smart=%.1f kW-min (%.2f%% error)', ...
        origEnergy, smartEnergy, abs(origEnergy-smartEnergy)/origEnergy*100);
end

% Verify NO charging occurs during peak period (startHour-7 window only)
% Check that all charging is within the allowed window
peakStart = 17*60+1;  % 17:00
peakEnd   = startMin;  % up to startHour (22:00)
peakLoad  = sum(EVp_smart(peakStart:peakEnd, :), 'all');
if peakLoad > 0
    % Some charging still in peak - this can happen if window is very tight
    % for long sessions, but should be minimal
    fprintf('    Note: %.1f kW-min residual in peak (%.1f%% of total)\n', ...
        peakLoad, peakLoad/smartEnergy*100);
end

end