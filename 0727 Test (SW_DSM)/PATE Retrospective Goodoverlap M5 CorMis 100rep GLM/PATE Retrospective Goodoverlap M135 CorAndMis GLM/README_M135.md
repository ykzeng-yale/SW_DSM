# PATE Retrospective Comparison with Varying M (1, 3, 5)

## Overview
This folder contains an enhanced version of the PATE retrospective sampling comparison that varies the number of matches (M) across three values: 1, 3, and 5. This allows us to understand how the matching count affects the performance of different methods.

## Key Modifications from M5 Version
1. **Loop over M values**: Each replicate now tests M=1, 3, and 5
2. **Nested results structure**: Results are organized by M value then by method
3. **Extended runtime**: Increased time limit to 23:59 hours (day partition for faster allocation)
4. **Enhanced visualization**: Plots show results for all M values in a grid
5. **Comprehensive output**: Results include comparisons across all M values

## Weight Treatment (CURRENT VERSION - Testing Hypothesis)
- **PS Full (Survey-Weighted)**: Uses NORMALIZED weights: w * length(w) / sum(w)
- **WDSM (Multinomial Bootstrap)**: Uses RAW weights (no normalization)
- **Purpose**: Testing whether WDSM requires weight normalization like PS Full

## Methods Compared
For each M value, we compare:
1. **DSM (Unweighted)**: Double Score Matching without survey weights
2. **PG (Unweighted)**: Prognostic Score Matching without survey weights
3. **PS (Unweighted)**: Propensity Score Matching without survey weights
4. **PS Full (Survey-Weighted)**: Full matching with survey weights using MatchIt
5. **WDSM (Multinomial Bootstrap)**: Weighted DSM with proper retrospective bootstrap

## Configuration
- **Sample size**: 5000 (retrospective sampling)
- **Replicates**: 1000
- **M values**: 1, 3, 5
- **Bootstrap iterations**: 200
- **Parallel cores**: 20 (FORK cluster)
- **Memory**: 8GB per CPU (~176GB total)
- **Partition**: day (for faster allocation)
- **Expected runtime**: ~23:59 hours

## Key Files
- `compare_methods_pate_retrospective_mccleary.R`: Main comparison script (modified for M loop)
- `submit_pate_retrospective_mccleary.sh`: SLURM submission script (23:59h, day partition)
- `wdsm_method2_multinomial_bootstrap.R`: WDSM implementation with multinomial bootstrap
- `wdsm_ci_functions.R`: WDSM confidence interval functions
- `SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData`: Good overlap population data

## Output Files
- `pate_retrospective_comparison_results_mccleary_M135_rawWDSM.RData`: Complete results for all M values
- `pate_retrospective_comparison_plot_mccleary_M135_rawWDSM.pdf`: Comparison plots (grid by M and metric)
- `pate_retrospective_comparison_table_mccleary_M135_rawWDSM.csv`: Detailed results table
- `pate_retro_M135_rawWDSM_*.out/err`: SLURM output and error logs

## How to Submit
```bash
sbatch submit_pate_retrospective_mccleary.sh
```

## Expected Results Structure
```R
all_results[[replicate]][[M_label]][[method]]
# Where:
# - replicate: 1 to 1000
# - M_label: "M1", "M3", or "M5"
# - method: "dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial"
```

## Analysis Features
- Coverage rates for each method and M value
- Bias and variance comparisons
- Relative efficiency calculations (vs PS Unweighted)
- Complete case analysis (removes replicates with any failed methods)

## Notes
- The timeout per replicate is increased to 900 seconds (15 minutes) to accommodate 3 M values
- Results are saved after each M value to prevent data loss
- The script sources all necessary functions inside parallel workers for PSOCK compatibility