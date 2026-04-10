# Supplementary Code and Data for: Where to Weight?

**Online supplementary materials** for:

> Zeng, Y., Tong, G., Tong, J., Lu, H., Mukherjee, B., and Li, F. (2026). **Where to weight? Estimating population causal effects with weighted double score matching in complex surveys.** *Manuscript under review.*

This repository contains all simulation code, results, and figures for the Monte Carlo study evaluating weighted double score matching (WDSM) and alternative methods for causal inference under complex survey designs.

## R Package

The WDSM estimator is available as the [`wdsmatch`](https://github.com/ykzeng-yale/wdsmatch) R package:

```r
remotes::install_github("ykzeng-yale/wdsmatch")

library(wdsmatch)
data(survey_obs)
fit <- wdsmatchATE(Y = survey_obs$Y, X = survey_obs[, 3:8],
                   Z = survey_obs$Z, weights = survey_obs$survey_weight,
                   M = 5, sampling = "retrospective", varest = TRUE, boots = 200)
fit
```

## Repository Structure

```
├── R/                          Core estimator functions
│   ├── wdsm_ci_functions.R               PATE: point estimation + bootstrap
│   ├── wdsm_method2_multinomial_bootstrap.R  PATE: Method 2 multinomial bootstrap
│   ├── wdsm_patt_ci_functions.R          PATT: point estimation + bootstrap
│   └── dsmatch/                          Unweighted DSM/PSM/PGM (Zhang & Yang, 2023)
│
├── Data/                       Super-population data (contact authors)
│
├── Simulations/                32 scenario simulation scripts
│   ├── {Retrospective,Prospective}/
│   │   └── {PATE,PATT}/
│   │       └── {GoodOverlap,PoorOverlap}/
│   │           └── {CorCor,CorMis,MisCor,MisMis}/
│   │               ├── compare_methods.R    Simulation driver (all methods)
│   │               ├── preprocess_and_run.R Data loading wrapper
│   │               └── run_m135.sh          SLURM job submission script
│
├── Results/                    Simulation output (1,000 replications each)
│   ├── PATE/   (16 scenarios)
│   └── PATT/   (16 scenarios)
│
├── Tables/
│   ├── All_12_Simulation_Tables.txt   LaTeX tables for the paper
│   └── generate_tables.R
│
└── Figures/
    ├── generate_figures.R
    ├── generate_figures_transposed.R
    └── {Retrospective,Prospective}/{horizontal,vertical}/{png,pdf}/
```

## Simulation Design

**Estimands:**
- PATE: τ\_PATE = E[Y(1) − Y(0)]
- PATT: τ\_PATT = E[Y(1) − Y(0) | Z = 1]

| Factor | Levels |
|--------|--------|
| Sampling design | Retrospective (π\_z(X) depends on Z), Prospective (π(X) ⊥ Z) |
| Propensity score overlap | Good (δ\_z = 0.6), Poor (δ\_z = 2.0) |
| Model specification | Cor\|Cor, Mis\|Cor, Cor\|Mis, Mis\|Mis (PS model \| PGS model) |
| Monte Carlo replications | 1,000 |
| Bootstrap replicates | B = 200 (multinomial, linearization-based) |
| Sieve basis | 10-term polynomial in (Ψ\_0, Ψ\_1, logit(e)) |
| Total scenarios | 2 × 2 × 2 × 4 = 32 |

**Methods compared:**

| Method | Abbreviation | Scores | Survey Weights | Reference |
|--------|-------------|--------|----------------|-----------|
| Propensity Score Matching | PSM | PS | No | Rosenbaum & Rubin (1983) |
| Prognostic Score Matching | PGM | PGS | No | Hansen (2008) |
| Double Score Matching | DSM | PS + PGS | No | Yang & Zhang (2023) |
| Survey-Weighted PS Full Matching | SW-PSM | PS | Yes | MatchIt (Ho et al., 2011) |
| **Weighted Double Score Matching** | **WDSM** | **PS + PGS** | **Yes** | **This paper** |

**Performance metrics:** Relative bias (%), relative efficiency (variance ratio to PSM under Cor|Cor), coverage of nominal 95% confidence intervals.

## Score Estimation Under Different Sampling Designs

| Score | Retrospective Sampling | Prospective Sampling |
|-------|----------------------|---------------------|
| Propensity score e(X) | Survey-weighted GLM | Unweighted GLM |
| Prognostic score Ψ\_z(X) | Unweighted OLS | Unweighted OLS |

See Table 1 in the main paper for complete survey weight requirements.

## Reproducing Results

1. **Data**: Contact the authors for super-population data files (see `Data/README.md`)
2. **Dependencies**: `install.packages(c("MatchIt", "marginaleffects", "survey", "sampling", "parallel", "foreach", "doParallel", "R.utils"))`
3. **WDSM package**: `remotes::install_github("ykzeng-yale/wdsmatch")`
4. **Run simulations**: Place population data in scenario folders, then `sbatch run_m135.sh`
5. **Generate tables**: `cd Tables && Rscript generate_tables.R`
6. **Generate figures**: `cd Figures && Rscript generate_figures.R && Rscript generate_figures_transposed.R`

## Computational Environment

- **Cluster**: Yale Bouchet HPC (SLURM)
- **Partition**: `day_amd`, 64 CPUs per job, 5G memory per CPU
- **Software**: R 4.4.2 (gfbf-2024a toolchain)
- **Runtime**: ~1.5 hours per 1,000-replicate scenario

## Contact

- Yukang Zeng — [ykzeng2019@gmail.com](mailto:ykzeng2019@gmail.com)
- Fan Li — [fan.f.li@yale.edu](mailto:fan.f.li@yale.edu)

## License

GPL-3
