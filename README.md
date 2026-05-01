## ASSESSING THE IMPACT OF THE GROWING RESIDENTIAL FAST-CHARGING DEMAND FOR ELECTRIC VEHICLES ON THE UK LOW-VOLTAGE DISTRIBUTION NETWORKS

## Introduction

This repository contains the MATLAB simulation framework developed for the Individual 3rd Year Project (EEEN30330) at the Department of Electrical and Electronic Engineering, University of Manchester, 2025/26. Student ID is 11437384. Project supervisor is Dr. Eduardo Martinez Cesena.

The software implements a stochastic Monte Carlo simulation that couples a probabilistic electric vehicle (EV) charging demand model with three-phase unbalanced power flow analysis to quantify the impact of residential fast charging (3 kW, 7 kW and 22 kW) on UK low-voltage (LV) distribution networks. It evaluates four network performance indicators, namely voltage compliance (BS EN 50160), transformer thermal loading, cable ampacity utilisation and daily energy losses, across EV penetration levels from 0% to 100%. It also determines network hosting capacity and evaluates a time-delay smart charging mitigation strategy. The framework executes approximately 6,600 power-flow simulations in total and produces 16 publication-quality figures.

## Contextual Overview

The simulation workflow proceeds through three stages:

**Stage 1 (`RunSingle.m`)** is executed once per charger rating and performs the following steps for each Monte Carlo iteration:

1. `GenerateBaselineLoad.m` creates 1-minute resolution household demand profiles for all customers.
2. `EVProfileGenerator.m` samples random EV arrival times and states of charge to generate stochastic EV charging profiles.
3. The baseline and EV profiles are summed to produce the total network load.
4. For smart charging scenarios, `ApplySmartCharging.m` redistributes the EV load into the off-peak window before summing.
5. `RunOpenDSS.m` passes the total load to the `UK_LV_Network.dss` model via the COM interface, solving a power flow at each minute and extracting voltage, loading and loss metrics.
6. Results are saved to a per-charger output file (e.g. `Results_3kW.mat`).

**Stage 2 (`MergeAndPlot.m`)** merges the three per-charger result files into a single `SimulationResults.mat`, then calls `AnalyseResults.m` to compute hosting capacities and `PlotResults.m` to generate Figures 1 to 12.

**Stage 3 (`MCConfidenceAnalysis.m`)** reads `SimulationResults.mat` and generates Figures 13 to 16 (Monte Carlo validation).

## File Descriptions

| File | Purpose |
| --- | --- |
| `RunSingle.m` | Main simulation driver. Runs adaptive Monte Carlo uncontrolled and fixed smart charging simulations for one charger rating. |
| `MergeAndPlot.m` | Merges per-charger `.mat` files, then calls `AnalyseResults.m` and `PlotResults.m`. |
| `GenerateBaselineLoad.m` | Generates 1-minute domestic load profiles with seasonal/day-type variation and customer diversity. |
| `EVProfileGenerator.m` | Stochastic EV charging profile generator. **Third-party code** (see attribution below). |
| `ApplySmartCharging.m` | Valley-filling smart charging strategy redistributing EV load to a 22:00–07:00 off-peak window. |
| `RunOpenDSS.m` | Executes minute-by-minute snapshot power flow via the OpenDSS COM interface. |
| `AnalyseResults.m` | Computes hosting capacity per charger rating from Monte Carlo results. |
| `PlotResults.m` | Generates 12 publication-quality figures (300 DPI PNG). |
| `MCConfidenceAnalysis.m` | Generates 4 Monte Carlo validation figures (distributions, envelopes, convergence). |
| `UK_LV_Network.dss` | OpenDSS network model: 500 kVA Dyn11 transformer, 3 feeders, 55 customer buses. |

## Installation

### Prerequisites

- **MATLAB** R2023b or later with the Statistics and Machine Learning Toolbox
- **OpenDSS** version 9.x — download free from [EPRI](https://www.epri.com/pages/sa/opendss)
- **Windows** 10 or 11 (required for the OpenDSS COM interface; the simulation cannot run on macOS or Linux)

### Setup

1. Download or clone this repository to a local directory (e.g. `C:\EV_Impact_Study`).
2. Install OpenDSS. During installation, ensure the **Register COM server** option is selected.
3. Verify the COM interface by opening MATLAB and running:
   ```matlab
   DSSObj = actxserver('OpenDSSEngine.DSS');
   disp(DSSObj.Version);
   ```
   If a version string is displayed, the installation is correct. If an error occurs, re-run the OpenDSS installer with administrator privileges.
4. In MATLAB, set the current directory to the project folder:
   ```matlab
   cd('C:\EV_Impact_Study');
   ```
5. Ensure all `.m` files and `UK_LV_Network.dss` are in the same directory.

## How to Run

### Stage 1 — Simulate each charger rating

Each charger rating must be run **one at a time**. After each run completes and saves its output file, **close MATLAB entirely and reopen it** before starting the next run. This is necessary to fully release OpenDSS COM server memory. Each run takes approximately 4–8 hours.

```matlab
RunSingle(3);    % produces Results_3kW.mat
```
Close MATLAB. Reopen MATLAB and navigate back to the project folder.
```matlab
RunSingle(7);    % produces Results_7kW.mat
```
Close MATLAB. Reopen MATLAB and navigate back to the project folder.
```matlab
RunSingle(22);   % produces Results_22kW.mat
```

### Stage 2 — Merge results and generate figures

Once all three result files are present in the working directory:

```matlab
MergeAndPlot;
```

This merges the results into `SimulationResults.mat`, prints hosting capacity tables to the console, and saves 12 figures to a `Figures/` subdirectory.

### Stage 3 — Monte Carlo validation figures (optional)

```matlab
MCConfidenceAnalysis;
```

Adds 4 further figures to the `Figures/` directory.

## Technical Details

### EV Demand Model
EV charging profiles are generated stochastically for each Monte Carlo iteration. Home-arrival times are sampled from a Gaussian distribution and state of charge at connection from a beta distribution, both parameterised from empirical UK data (National Travel Survey, Electric Nation trial). Each EV is assigned a constant-power charging session at the specified charger rating (3 kW, 7 kW or 22 kW) with a charger efficiency of 0.90. Profiles are generated at 1-minute resolution (1,440 timesteps per day).

### Baseline Load Model
Household demand profiles are based on Elexon Profile Class 1 (domestic unrestricted), interpolated to 1-minute resolution. Each customer receives a randomly scaled and time-shifted version of the base profile with added random load spikes (representing kettles, ovens, etc.) to create realistic customer diversity.

### Power Flow
The combined household-plus-EV load is passed to OpenDSS at each minute via the COM interface in snapshot mode. OpenDSS solves a three-phase unbalanced power flow for the full LV network at each timestep, returning per-customer voltages, transformer apparent power, line currents and network losses.

### Hosting Capacity
Hosting capacity is defined as the maximum EV penetration at which fewer than 5% of Monte Carlo iterations violate any operational limit (voltage, transformer or cable). The binding constraint is the limit that is breached first as penetration increases.

### Smart Charging
The smart charging strategy removes all EV charging from the original profile and redistributes it into an off-peak window (22:00–07:00). Each EV is assigned a staggered start time uniformly distributed across the window to prevent synchronisation peaks. Total energy is preserved exactly.

### Convergence Criterion
Adaptive convergence uses the coefficient of variation (CoV) of peak demand. Iterations continue until the change in CoV between consecutive checks falls below ε = 0.0075 for two consecutive checks, with a minimum of 50 and maximum of 200 iterations.

## Known Issues and Future Improvements

### Known Issues
- **Windows-only:** the simulation requires the OpenDSS COM interface, which is only available on Windows.
- **Long runtime:** a full three-charger run takes 12–24 hours. Each rating must be run sequentially with MATLAB restarted between each.
- **Memory management:** the COM object is refreshed every 10 iterations to prevent OpenDSS memory leaks. If MATLAB still crashes, reduce `comRefresh` to 5 in `RunSingle.m`.
- **Customer count:** `RunSingle.m` actively loads 33 of the 55 customers defined in the OpenDSS network file. This is an intentional simplification discussed in the project report.

### Future Improvements
- Extend to multiple UK LV network topologies for generalisation of hosting capacity results.
- Implement optimisation-based smart charging (e.g. optimal power flow) rather than time-delay scheduling.
- Add vehicle-to-grid (V2G) capability for active network support.
- Integrate heat pump and solar PV demand for multi-technology impact assessment.

## Third-Party Code and Academic Integrity

`EVProfileGenerator.m` was authored by **Dr Eduardo Martinez Cesena** (project supervisor, University of Manchester) and is used **without modification**. The function generates stochastic EV charging profiles using empirical UK behavioural data from:

- J. Quirós-Tortós, L. F. Ochoa and B. Lees, "A statistical analysis of EV charging behaviour in the UK," *IEEE PES ISGT Latin America*, 2015. ([IEEE Xplore](https://ieeexplore.ieee.org/document/7381196))
- My Electric Avenue / Electric Nation customer trial data.

**All other MATLAB code in this repository is original work by the student (ID: 11437384).** All submitted software complies with the University of Manchester's regulations on academic integrity.

## Licence

MIT
