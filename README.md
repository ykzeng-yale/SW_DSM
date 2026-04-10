# Weighted Double Score Matching for Survey-Weighted Causal Inference

Simulation study reproducibility package for:

> **Zeng, Y., Li, F., and Hong, G. (2026).** *Weighted Double Score Matching for Causal Inference with Survey-Weighted Observational Data.*

## Overview

Double score matching combines propensity scores and prognostic scores to achieve dimension reduction and model robustness in causal inference. This paper develops **weighted double score matching (WDSM)** that incorporates survey design weights throughout score estimation, matching, and outcome analysis for population-level causal inference under complex survey designs.

Key contributions:
- Unified framework for survey weights in double score matching under **retrospective** (treatment-dependent) and **prospective** (treatment-independent) sampling
- **Double robustness**: consistent when either the propensity score or prognostic score model is correctly specified
- **Linearization-based multinomial bootstrap** for variance estimation preserving survey-weighted matching structure
- Polynomial sieve bias correction for improved finite-sample performance

## R Package

The WDSM estimator is implemented in the [`wdsmatch`](https://github.com/ykzeng-yale/wdsmatch) R package:

```r
remotes::install_github("ykzeng-yale/wdsmatch")

library(wdsmatch)
fit <- wdsmatchATE(Y, X, Z, weights, M = 5, sampling = "retrospective")
fit <- wdsmatchATT(Y, X, Z, weights, M = 5, sampling = "retrospective")
```

## Repository Structure

```
├── R/                          Core estimator functions
│   ├── wdsm_ci_functions.R               PATE: point estimation + bootstrap
│   ├── wdsm_method2_multinomial_bootstrap.R  PATE: Method 2 multinomial bootstrap
│   ├── wdsm_patt_ci_functions.R          PATT: point estimation + bootstrap
│   └── dsmatch/                          Unweighted DSM/PSM/PGM (Zhang & Yang)
│
├── Data/                       Super-population data (see Data/README.md)
│
├── Simulations/                32 scenario simulation scripts
│   ├── {Retrospective,Prospective}/
│   │   └── {PATE,PATT}/
│   │       └── {GoodOverlap,PoorOverlap}/
│   │           └── {CorCor,CorMis,MisCor,MisMis}/
│   │               ├── compare_methods.R    Simulation driver
│   │               ├── preprocess_and_run.R Data wrapper
│   │               └── run_m135.sh          SLURM submission
│
├── Results/                    1,000-replication output
│   ├── PATE/ (16 .RData)
│   └── PATT/ (16 .RData)
│
├── Tables/
│   ├── All_12_Simulation_Tables.txt
│   └── generate_tables.R
│
└── Figures/
    ├── generate_figures.R
    ├── generate_figures_transposed.R
    └── {Retrospective,Prospective}/{horizontal,vertical}/{png,pdf}/
```

## Simulation Design

**Estimands**: PATE = E[Y(1) - Y(0)], PATT = E[Y(1) - Y(0) | Z = 1]

| Factor | Levels |
|--------|--------|
| Sampling | Retrospective (π_z(X) depends on Z), Prospective (π(X) independent of Z) |
| Overlap | Good (δ_z = 0.6), Poor (δ_z = 2.0) |
| Model spec | Cor\|Cor, Mis\|Cor, Cor\|Mis, Mis\|Mis (PS\|PGS) |
| Replications | 1,000 |
| Bootstrap | B = 200, multinomial with linearization |
| Sieve | 10-term polynomial basis in (Ψ_0, Ψ_1, logit(e)) |

**Methods compared**: PSM, PGM, DSM, SW-PSM (MatchIt), **WDSM** (M = 1, 3, 5)

**Metrics**: Relative bias (%), relative efficiency (variance ratio to PSM Cor|Cor), coverage of 95% CI

## Score Estimation

| Component | Retrospective | Prospective |
|-----------|--------------|-------------|
| Propensity score e(X) | Survey-weighted GLM | Unweighted GLM |
| Prognostic score Ψ_z(X) | Unweighted OLS | Unweighted OLS |

## Reproducing Results

1. Obtain population data (contact authors; see `Data/README.md`)
2. Install dependencies: `install.packages(c("MatchIt", "marginaleffects", "survey", "sampling", "parallel", "foreach", "doParallel", "R.utils"))`
3. Place population data in scenario folders
4. Submit SLURM jobs: `sbatch run_m135.sh`
5. Regenerate outputs: `Rscript generate_tables.R` and `Rscript generate_figures.R`

## HPC

Yale Bouchet cluster: `day_amd` partition, 64 CPUs, R 4.4.2, ~1.5 hrs/scenario

## Contact

Yukang Zeng — ykzeng2019@gmail.com

## License

GPL-3
