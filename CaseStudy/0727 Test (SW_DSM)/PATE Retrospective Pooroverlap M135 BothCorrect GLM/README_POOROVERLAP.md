# PATE Retrospective Poor Overlap Analysis (M=1,3,5)

## Overview
This folder contains the comprehensive comparison of matching methods for PATE estimation under retrospective sampling with **POOR OVERLAP** between treatment and control groups.

## Key Differences from Good Overlap
- **Poor Overlap Configuration**: `delta_z = 2` in the propensity score model
  - Creates greater separation between treatment and control groups
  - Makes matching more challenging due to limited overlap region
  - Tests robustness of methods under difficult conditions

## Data Generation
Unlike the good overlap version, this script **generates the poor overlap population directly** in the R script rather than loading pre-generated data. The population is created with:
- N = 1,000,000 total population size
- 10 strata × 20 clusters structure
- 6 covariates with interaction term (X1*X2)
- Propensity score model with `delta_z = 2` (creates poor overlap)
- Outcome model with heterogeneous treatment effects

## Methods Compared (M = 1, 3, 5)
1. **Unweighted DSM** (dsmatch-master with bootstrap)
2. **Unweighted PG matching** (dsmatch-master with bootstrap)
3. **Unweighted PS matching** (dsmatch-master with bootstrap)
4. **Survey-weighted PS full matching** (MatchIt with design-based inference)
   - Uses NORMALIZED weights: w × length(w)/sum(w)
5. **WDSM with Multinomial Bootstrap**
   - Uses RAW weights (testing hypothesis that WDSM doesn't require normalization)

## Configuration
- Sample size: 5000 (retrospective sampling)
- Replicates: 1000
- Bootstrap iterations: 200
- M values: 1, 3, 5 (number of matches per unit)
- Significance level: 0.05

## Expected Outputs
- `pate_retrospective_pooroverlap_comparison_results_mccleary_M135_rawWDSM.RData`
- `pate_retrospective_pooroverlap_comparison_plot_mccleary_M135_rawWDSM.pdf`
- `pate_retrospective_pooroverlap_comparison_table_mccleary_M135_rawWDSM.csv`
- `pate_retrospective_pooroverlap_bias_variance_plot_mccleary.pdf`

## HPC Submission
To submit to McCleary HPC:
```bash
./mccleary_submit_retrospective.sh
```

This will:
1. Create a timestamped directory on HPC
2. Upload all necessary files (except data, which is generated)
3. Submit the SLURM job
4. Provide download commands for results

## Expected Runtime
- Approximately 1.5-2 hours on McCleary HPC with 20 cores
- Based on 8.84 minutes for 100 replicates

## Notes
- Poor overlap scenarios typically show larger bias and variance
- Some methods may fail or perform poorly with severe overlap violations
- PS full matching and WDSM should be more robust to poor overlap
