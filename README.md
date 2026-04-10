# Weighted Double Score Matching: Simulation Study

Reproducibility package for the simulation study in:

> **Zeng, Y., Li, F., and Hong, G. (2026).** *Weighted Double Score Matching for Causal Inference with Survey-Weighted Observational Data.*

## Overview

This repository contains all code, scripts, and results for the Monte Carlo simulation study comparing weighted double score matching (WDSM) against existing matching methods for causal inference under complex survey designs.

## Repository Structure

```
├── R/                          Core estimator functions
│   ├── wdsm_ci_functions.R               PATE WDSM point estimation + Method 1 bootstrap
│   ├── wdsm_method2_multinomial_bootstrap.R  PATE Method 2 multinomial bootstrap
│   ├── wdsm_patt_ci_functions.R          PATT WDSM (10-term sieve)
│   └── dsmatch/                          Unweighted matching (DSM/PSM/PGM)
│
├── Data/                       Super-population data (not in repo; see Data/README.md)
│
├── Simulations/                Per-scenario simulation scripts
│   ├── Retrospective/
│   │   ├── PATE/{GoodOverlap,PoorOverlap}/{CorCor,CorMis,MisCor,MisMis}/
│   │   └── PATT/{GoodOverlap,PoorOverlap}/{CorCor,CorMis,MisCor,MisMis}/
│   └── Prospective/
│       ├── PATE/...
│       └── PATT/...
│   Each scenario folder contains:
│     - compare_methods.R    Main simulation driver
│     - preprocess_and_run.R Data loading wrapper
│     - run_m135.sh          SLURM job submission script
│
├── Results/                    Simulation output (1,000 replications)
│   ├── PATE/                   16 .RData files
│   └── PATT/                   16 .RData files
│
├── Tables/
│   ├── All_12_Simulation_Tables.txt   LaTeX tables (4 tables × PATE + PATT)
│   └── generate_tables.R             Script to regenerate from Results/
│
└── Figures/
    ├── generate_figures.R             Vertical layout figure generator
    ├── generate_figures_transposed.R  Horizontal layout figure generator
    ├── Retrospective/{horizontal,vertical}/{png,pdf}/
    └── Prospective/{horizontal,vertical}/{png,pdf}/
```

## Simulation Design

| Factor | Levels |
|--------|--------|
| **Estimand** | PATE, PATT |
| **Sampling** | Retrospective (treatment-dependent), Prospective (multi-stage) |
| **Overlap** | Good (δ_z = 0.6), Poor (δ_z = 2.0) |
| **Model specification** | Cor\|Cor, Mis\|Cor, Cor\|Mis, Mis\|Mis |
| **Matching ratio** | M = 1, 3, 5 (for WDSM) |
| **Replications** | 1,000 |
| **Bootstrap** | B = 200 (multinomial, linearization-based) |

**Total: 32 scenarios** (2 × 2 × 2 × 4)

## Methods Compared

| Method | Abbreviation | Scores Used | Survey Weights |
|--------|-------------|-------------|----------------|
| Propensity Score Matching | PSM | PS only | No |
| Prognostic Score Matching | PGM | PGS only | No |
| Double Score Matching | DSM | PS + PGS | No |
| Survey-Weighted PS Full Matching | SW-PSM | PS | Yes (MatchIt) |
| **Weighted Double Score Matching** | **WDSM** | **PS + PGS** | **Yes** |

## R Package

The WDSM estimator is available as an R package:

```r
remotes::install_github("ykzeng-yale/wdsmatch")
```

See [wdsmatch repository](https://github.com/ykzeng-yale/wdsmatch) for documentation and usage.

## HPC Configuration

Simulations were run on the Yale Bouchet HPC cluster:
- **Partition**: `day_amd` (64 CPUs per job)
- **R version**: 4.4.2 (gfbf-2024a)
- **Runtime**: ~1.5 hours per scenario (1,000 reps)

## Reproducing Results

1. Obtain population data files (contact authors; see `Data/README.md`)
2. Install R dependencies: `install.packages(c("MatchIt", "marginaleffects", "survey", "sampling", "parallel", "foreach", "doParallel"))`
3. Install WDSM package: `remotes::install_github("ykzeng-yale/wdsmatch")`
4. Place population data in each scenario's folder
5. Submit SLURM jobs: `cd Simulations/.../CorCor && sbatch run_m135.sh`
6. After completion, collect results into `Results/`
7. Regenerate tables: `cd Tables && Rscript generate_tables.R`
8. Regenerate figures: `cd Figures && Rscript generate_figures.R && Rscript generate_figures_transposed.R`

## License

GPL-3

## Contact

Yukang Zeng — ykzeng2019@gmail.com
