function baselineLoad = GenerateBaselineLoad(numCustomers, season, dayType)
%% GenerateBaselineLoad - Generates realistic UK household demand profiles
%
% Creates 1-minute resolution load profiles for each customer based on
% typical UK residential demand patterns from the Low Carbon London dataset.
%
% INPUTS:
%   numCustomers - Number of customers (e.g., 55)
%   season       - 1:Winter, 2:Spring, 3:Summer, 4:Autumn
%   dayType      - 1:Weekday, 2:Weekend
%
% OUTPUT:
%   baselineLoad - [1440 x numCustomers] matrix of demand in kW
%
% The profiles are generated using a parameterised model that captures:
%   - Morning and evening peaks
%   - Overnight minimum demand
%   - Seasonal variation (higher demand in winter)
%   - Day-type variation (different weekend patterns)
%   - Customer-to-customer diversity

%% Define typical half-hourly profile shape (48 points)
% Based on Elexon Profile Class 1 (domestic unrestricted) scaled to
% typical UK annual consumption of ~3,100 kWh

% Time points (hours, 0.5hr resolution)
tHH = (0:47) * 0.5;

% Base profile shape (kW) - winter weekday (highest demand)
% Captures the characteristic double-peak pattern
profileWinterWD = [
    0.30 0.28 0.26 0.24 0.23 0.22 0.21 0.20 0.20 0.21 ...  % 00:00-04:30
    0.23 0.28 0.38 0.55 0.65 0.70 0.72 0.68 0.62 0.55 ...  % 05:00-09:30
    0.50 0.48 0.47 0.48 0.50 0.52 0.55 0.58 0.62 0.68 ...  % 10:00-14:30
    0.78 0.92 1.10 1.25 1.30 1.28 1.20 1.10 0.95 0.80 ...  % 15:00-19:30
    0.65 0.55 0.48 0.42 0.38 0.35 0.33 0.31              ...  % 20:00-23:30
    ];

% Seasonal scaling factors
switch season
    case 1  % Winter
        seasonScale = 1.00;
    case 2  % Spring
        seasonScale = 0.80;
    case 3  % Summer
        seasonScale = 0.65;
    case 4  % Autumn
        seasonScale = 0.85;
end

% Day-type adjustment
if dayType == 2  % Weekend
    % Shift morning peak later, spread evening peak
    profileBase = [
        0.32 0.30 0.28 0.25 0.23 0.22 0.21 0.21 0.22 0.25 ...
        0.32 0.42 0.55 0.62 0.65 0.63 0.60 0.58 0.55 0.52 ...
        0.50 0.50 0.52 0.55 0.58 0.62 0.68 0.75 0.82 0.90 ...
        0.98 1.05 1.10 1.12 1.08 1.00 0.90 0.80 0.70 0.60 ...
        0.52 0.46 0.42 0.38 0.35 0.33 0.32 0.32 ...
        ];
else
    profileBase = profileWinterWD;
end

% Apply seasonal scaling
profileBase = profileBase * seasonScale;

%% Interpolate to 1-minute resolution
tMin = (0:1439) / 60;  % Time in hours at 1-min resolution
profileHR = interp1(tHH, profileBase, tMin, 'pchip');

% Ensure non-negative
profileHR = max(profileHR, 0.05);

%% Generate individual customer profiles with diversity
baselineLoad = zeros(1440, numCustomers);

for c = 1:numCustomers
    % Each customer gets a randomly scaled and shifted version
    rng(c * 42 + season * 7 + dayType);  % Reproducible per customer
    
    % Scale factor: customers vary +/- 30% around mean
    scaleFactor = 0.7 + 0.6 * rand();
    
    % Time shift: +/- 15 minutes for peak timing diversity
    timeShift = round((rand() - 0.5) * 30);
    
    % Add noise: 10% random variation at each timestep
    noise = 1 + 0.10 * randn(1440, 1);
    noise = max(noise, 0.5);  % Prevent negative or very low
    
    % Apply shift
    shiftedProfile = circshift(profileHR', timeShift);
    
    % Apply scaling and noise
    customerProfile = shiftedProfile .* scaleFactor .* noise;
    
    % Add random spikes (kettle, oven, etc.) - occasional high loads
    numSpikes = randi([2, 8]);
    for s = 1:numSpikes
        spikeTime = randi([360, 1380]);  % Between 6am and 11pm
        spikeDuration = randi([2, 15]);  % 2-15 minutes
        spikePower = 1.0 + 2.0 * rand();  % 1-3 kW extra
        endTime = min(spikeTime + spikeDuration, 1440);
        customerProfile(spikeTime:endTime) = ...
            customerProfile(spikeTime:endTime) + spikePower;
    end
    
    % Ensure minimum load (standby appliances)
    customerProfile = max(customerProfile, 0.05);
    
    baselineLoad(:, c) = customerProfile;
end

% Verify aggregate is reasonable
aggPeak = max(sum(baselineLoad, 2));
fprintf('  Aggregate baseline peak: %.1f kW (%.1f kW per customer avg)\n', ...
    aggPeak, aggPeak/numCustomers);

end