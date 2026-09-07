# PATE Retrospective Good Overlap - Model Misspecification Analysis

## Overview

This analysis extends the PATE retrospective sampling comparison to include model misspecification scenarios. We examine how different methods perform when the propensity score (PS) and/or prognostic score (PGS) models are misspecified by omitting the X1:X2 interaction term.

## Model Specification Scenarios

The analysis includes 4 scenarios:

1. **CorCor**: Both PS and PGS models are correctly specified (include X1:X2 interaction)
2. **MisCor**: PS model is misspecified (no X1:X2), PGS model is correct (has X1:X2)
3. **CorMis**: PS model is correct (has X1:X2), PGS model is misspecified (no X1:X2)
4. **MisMis**: Both PS and PGS models are misspecified (no X1:X2)

## Methods Compared

For each scenario and M value (1, 3, 5), we compare:

1. **Unweighted DSM**: Double score matching without survey weights
2. **Unweighted PG**: Prognostic score matching without survey weights
3. **Unweighted PS**: Propensity score matching without survey weights
4. **Survey-weighted PS**: PS full matching with survey weights (MatchIt)
5. **WDSM**: Weighted double score matching with multinomial bootstrap

## Simulation Parameters

- **Sample size**: n = 5000
- **Replicates**: 1000
- **Bootstrap iterations**: B = 200
- **M values**: 1, 3, 5 (number of matches per unit)
- **Significance level**: α = 0.05
- **Data**: Good overlap population
- **Parallel cores**: 20 (FORK cluster)

## File Structure

### Main Scripts
- `compare_methods_pate_retrospective_mccleary.R`: Main comparison script with misspecification loop
- `wdsm_method2_multinomial_bootstrap.R`: Updated WDSM with model specification parameters
- `wdsm_ci_functions.R`: Updated WDSM functions with model specification parameters

### Submission Scripts
- `run_comparison_mccleary_optimized.sh`: SLURM submission script
- `submit_to_mccleary.sh`: Helper script to upload and submit job
- `check_and_download_results.sh`: Script to check status and download results

### Expected Output
- `pate_retrospective_comparison_results_misspec.RData`: Complete simulation results
- `pate_retrospective_comparison_table_misspec.csv`: Summary statistics table

## How to Run

### Local Testing
```bash
# Run a small test locally (edit n_reps to 10 first)
Rscript compare_methods_pate_retrospective_mccleary.R
```

### Submit to McCleary HPC
```bash
# Upload and submit
./submit_to_mccleary.sh

# Check status and download results
./check_and_download_results.sh
```

## Key Modifications from Original

1. **Scenario Loop**: Added loop over 4 model specification scenarios in `run_single_replicate()`
2. **Flexible Model Formulas**: PS and PGS models now conditionally include/exclude X1:X2 interaction
3. **Parameter Passing**: Added `use_interaction_ps` and `use_interaction_pg` parameters throughout
4. **Results Structure**: Results now stored by scenario and M value (e.g., "CorCor_M1", "MisCor_M3")
5. **Extended Runtime**: Timeout increased to 60 minutes per replicate (4 scenarios × 3 M values)

## Expected Results Structure

Results are organized as:
```
results_by_scenario_m[["Scenario_M"]]
  - dsm_unweighted
  - pg_unweighted  
  - ps_unweighted
  - ps_weighted
  - wdsm_multinomial
```

Each method contains:
- `estimate`: Point estimate
- `se`: Standard error
- `ci_lower`: Lower CI bound
- `ci_upper`: Upper CI bound

## Performance Metrics

For each scenario-M-method combination, we calculate:
- Mean estimate
- Bias and relative bias
- Empirical SE
- Mean SE and SE ratio
- Coverage probability
- RMSE

## Notes

- The CorCor scenario should match results from the "BothCorrect" analysis
- Model misspecification is expected to increase bias and reduce coverage
- PS methods should be most affected by PS misspecification
- PG methods should be most affected by PGS misspecification
- DSM methods may show robustness to single model misspecification
