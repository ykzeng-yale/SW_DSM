# Weighted Double Score Matching (WDSM) Simulation Study

## PATE bootstrap correction (2026-09-09)

The [provenance and inference audit](audit/PATE_bootstrap_audit_20260909.md) links the paper's saved results to the local publication files and Tong's Bouchet production runs. Those PATE intervals used a bootstrap with an omitted residual correction and percentile endpoints. The original results are retained as the comparison baseline.

Use `Simulations/rerun_pate_wald.R` and `Simulations/submit_pate_wald.sbatch` for the corrected PATE rerun. They explicitly select retrospective/prospective score weighting, freeze original weighted reuse, use B-divisor replication variance and Wald intervals, and save full bootstrap draws and provenance. Run a pilot first in a separate output directory. `Rscript Simulations/rerun_pate_wald.R --help` lists the options.

The older per-scenario scripts and plotting/table scripts retain historical deployment paths and are preserved for provenance; they are not the new rerun entrypoint. This correction retains the mathematical point estimator and joint ten-term sieve, with a stable propensity-model initialization that repairs observed failures in the original numerical fits. Point estimates can consequently change. See the audit for the remaining manuscript-specification and theoretical-validation boundaries. New numerical results must not be claimed complete until the cluster output checks pass.

## Full 0727 experiment folder

- [Browse `0727 Test (SW_DSM)`](0727%20Test%20%28SW_DSM%29/)
- [Download the complete folder, including large data and saved results](https://github.com/ykzeng-yale/SW_DSM/releases/tag/0727-full-snapshot-20260907)
- [Restore instructions, complete inventory, and checksums](0727-snapshot/README.md)

The browsable copy contains code and files up to 10 MB. The release archive preserves every original file, symbolic link, and subdirectory.

Reproducibility package for the simulation study comparing WDSM against standard matching methods under survey-weighted observational data.

## Directory Structure

```
Publication_Package/
├── R/                          # Core estimator functions
│   ├── wdsm_ci_functions.R               # PATE WDSM: point estimate + Method 1 bootstrap
│   ├── wdsm_method2_multinomial_bootstrap.R  # PATE WDSM: Method 2 multinomial bootstrap
│   ├── wdsm_patt_ci_functions.R          # PATT WDSM: point estimate + bootstrap (10-term sieve)
│   └── dsmatch/                          # Unweighted matching package (DSM, PSM, PGM)
│       ├── dsmatchATE.R                  # ATE double score matching
│       ├── dsmatchATT.R                  # ATT double score matching
│       └── ...                           # Bootstrap helpers
│
├── Data/                       # Super-population data (symlinks)
│   ├── SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData  (delta_z = 0.6)
│   └── SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData  (delta_z = 2.0)
│
├── Simulations/                # Per-scenario simulation scripts
│   ├── compare_methods_pate.R            # PATE comparison driver (all methods)
│   ├── Retrospective/
│   │   ├── PATE/
│   │   │   ├── GoodOverlap/
│   │   │   │   ├── CorCor/              # Both PS and PGS correctly specified
│   │   │   │   │   ├── run_m135.sh      # SLURM submission script
│   │   │   │   │   └── preprocess_and_run.R
│   │   │   │   ├── CorMis/              # PS correct, PGS misspecified
│   │   │   │   ├── MisCor/              # PS misspecified, PGS correct
│   │   │   │   └── MisMis/              # Both misspecified
│   │   │   └── PoorOverlap/
│   │   │       └── {CorCor,CorMis,MisCor,MisMis}/
│   │   └── PATT/
│   │       ├── GoodOverlap/{...}/
│   │       └── PoorOverlap/{...}/
│   └── Prospective/
│       ├── PATE/{...}/
│       └── PATT/{...}/
│
├── Results/                    # Simulation output (symlinks to .RData)
│   ├── PATE/                   # 16 files: {Retro,Prosp}_{Good,Poor}_{4 scenarios}
│   └── PATT/                   # 16 files: same structure (10-term sieve)
│
├── Tables/
│   ├── All_12_Simulation_Tables.txt      # LaTeX tables (4 tables x PATE+PATT)
│   └── generate_tables.R                # R script to regenerate tables from results
│
└── Figures/
    ├── generate_figures.R                # Vertical layout figure generator
    ├── generate_figures_transposed.R     # Horizontal layout figure generator
    ├── Retrospective/
    │   ├── horizontal/{png,pdf}/         # 3 rows (metrics) x 4 cols (estimand/overlap)
    │   │   ├── lines.{png,pdf}
    │   │   ├── dots_solid.{png,pdf}
    │   │   └── dots_hollow.{png,pdf}     # Faded for unaffected method-scenarios
    │   └── vertical/{png,pdf}/           # 4 rows (estimand/overlap) x 3 cols (metrics)
    └── Prospective/
        ├── horizontal/{png,pdf}/
        └── vertical/{png,pdf}/
```

## Methods Compared

| Method | Abbreviation | Score(s) Used | Survey Weights |
|--------|-------------|---------------|----------------|
| Propensity Score Matching | PSM | PS only | No |
| Prognostic Score Matching | PGM | PGS only | No |
| Double Score Matching | DSM | PS + PGS | No |
| Survey-Weighted PS Full Matching | SW-PSM | PS | Yes (MatchIt) |
| **Weighted Double Score Matching** | **WDSM** | **PS + PGS** | **Yes** |

## Simulation Design

- **Estimands**: PATE (population average treatment effect), PATT (population average treatment effect on the treated)
- **Sampling**: Retrospective (treatment-dependent), Prospective (multi-stage)
- **Overlap**: Good (delta_z = 0.6), Poor (delta_z = 2.0)
- **Model specification**: 4 patterns (Cor|Cor, Mis|Cor, Cor|Mis, Mis|Mis)
- **Matching ratios**: M = 1, 3, 5 for WDSM
- **Replications**: 1,000
- **Bootstrap**: B = 200 (multinomial, linearization-based)
- **Sieve**: 10-term polynomial basis for PATE; 10-term for PATT
- **Total scenarios**: 2 sampling x 2 overlap x 2 estimand x 4 misspec = 32

## HPC Configuration

Simulations run on Yale Bouchet HPC cluster:
- Partition: `day_amd`
- CPUs: 64 per job
- Memory: 5G per CPU
- R version: 4.4.2-gfbf-2024a
- Account: `pi_gt353`

## Reproducing Results

1. Place population data in each scenario folder (or adjust paths in `preprocess_and_run.R`)
2. Copy R functions to each scenario folder (or adjust `source()` paths)
3. Submit SLURM jobs: `sbatch run_m135.sh`
4. After completion, collect `raw_results_*.RData` files into `Results/`
5. Run `generate_tables.R` and `generate_figures.R` from the `Tables/` and `Figures/` directories
