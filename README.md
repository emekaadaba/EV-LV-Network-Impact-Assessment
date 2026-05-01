# EV Impact on UK LV Distribution Networks

## Introduction

MATLAB simulation framework assessing the impact of residential EV fast charging (3 kW, 7 kW, 22 kW) on UK low-voltage distribution networks. Couples a stochastic Monte Carlo EV demand model with three-phase unbalanced power flow analysis via OpenDSS.


## System Overview

The workflow proceeds as:
1. Generate baseline household load profiles for each customer
2. Superimpose stochastic EV charging profiles at each penetration level (0–100%)
3. Pass combined load to OpenDSS minute-by-minute via COM interface
4. Extract voltage, transformer loading, cable loading and loss metrics
5. Repeat across Monte Carlo iterations with adaptive convergence checking
6. Optionally apply smart charging (off-peak redistribution) and re-simulate

## File Descriptions

| File | Purpose |
| --- | --- |
| `RunSingle.m` | Main driver. Runs adaptive MC (max 200) uncontrolled and fixed (100) smart charging for one charger rating. |
| `MergeAndPlot.m` | Merges per-charger `.mat` files, calls analysis and plotting scripts. |
| `GenerateBaselineLoad.m` | 1-minute domestic load profiles with seasonal/day-type variation. |
| `EVProfileGenerator.m` | Stochastic EV profile generator. **Third-party: Dr Eduardo Martinez Cesena.** |
| `ApplySmartCharging.m` | Valley-filling strategy: redistributes EV load to 22:00–07:00 window. |
| `RunOpenDSS.m` | Minute-by-minute snapshot power flow via OpenDSS COM. |
| `AnalyseResults.m` | Computes hosting capacity per charger rating. |
| `PlotResults.m` | Generates 12 figures (300 DPI PNG). |
| `MCConfidenceAnalysis.m` | 4 Monte Carlo validation figures. |
| `UK_LV_Network.dss` | OpenDSS network: 500 kVA TX, 3 feeders, 55 customer buses. |

## Installation

### Prerequisites
- **MATLAB** R2023b or later (Statistics Toolbox required)
- **OpenDSS** v9.x with COM server registered — download from [EPRI](https://www.epri.com/pages/sa/opendss)
- **Windows** 10/11 (required for COM interface)

### Setup
1. Clone or download this repository
2. Install OpenDSS — ensure "Register COM server" is ticked during installation
3. Open MATLAB, set current directory to the project folder

## How to Run

Each charger rating must be run one at a time. After each run completes, **close MATLAB entirely and reopen it** before starting the next to release OpenDSS COM memory.

```matlab
% Stage 1: Run each charger rating sequentially (~4-8 hours each)
RunSingle(3);    % produces Results_3kW.mat — then close and reopen MATLAB
RunSingle(7);    % produces Results_7kW.mat — then close and reopen MATLAB
RunSingle(22);   % produces Results_22kW.mat

% Stage 2: Merge results and generate figures
MergeAndPlot;

% Stage 3 (optional): Monte Carlo validation figures
MCConfidenceAnalysis;
```

## Third-Party Code

`EVProfileGenerator.m` was authored by **Dr Eduardo Martinez Cesena** (project supervisor) and is used without modification. All other code is original work.

## Known Issues

- **Windows-only** due to OpenDSS COM interface
- **Runtime:** full run across 3 charger ratings takes 12–24 hours; must be run sequentially with MATLAB restarted between each
- **Memory:** COM object refreshed every 10 iterations to prevent leaks; reduce `comRefresh` to 5 in `RunSingle.m` if crashes persist
- Seeds are set deterministically for reproducibility
