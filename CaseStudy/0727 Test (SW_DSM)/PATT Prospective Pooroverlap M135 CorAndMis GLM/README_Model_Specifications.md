# PATT Prospective Goodoverlap M135 with Model Specifications

## Overview
This folder contains the enhanced version of the PATT comparison scripts that now handle **model misspecification scenarios** in addition to multiple M values (M=1, 3, 5).

## Model Specification Scenarios

The simulation now tests 4 different model specification scenarios:

1. **CorCor**: Both PS and PGS models are correctly specified (include X1:X2 interaction)
2. **MisCor**: PS model misspecified (no X1:X2), PGS model correct (has X1:X2)
3. **CorMis**: PS model correct (has X1:X2), PGS model misspecified (no X1:X2)
4. **MisMis**: Both PS and PGS models misspecified (no X1:X2 in both)

## Key Changes from BothCorrect Version

### 1. Main Script (`comprehensive_patt_comparison_mccleary.R`)
- Added `model_spec` parameter to `run_single_replicate_M()` function
- Updated all 5 matching methods to handle model specifications:
  - **DSM (Unweighted)**: Separate PS and PGS model specifications
  - **PG (Unweighted)**: PGS model specification only
  - **PS (Unweighted)**: PS model specification only
  - **PS Full (Survey-Weighted)**: PS model specification only
  - **WDSM (Survey-Weighted)**: Both PS and PGS model specifications
- Modified `run_single_replicate()` to loop over all 4 model specifications
- Updated results structure: `all_results[[replicate]][[model_spec]][[M]][[method]]`
- Enhanced results processing to handle nested structure with model specifications

### 2. Submission Script (`run_patt_comparison_mccleary.sh`)
- Increased time allocation to 24 hours (was 12 hours)
- Changed partition from `day` to `week` for longer runtime
- Updated job name to `patt_M135_CorAndMis`
- Added model specification information to echo statements

### 3. Quick Commands (`mccleary_patt_quick_commands.sh`)
- Updated remote directory naming to include `CorAndMis`
- Modified file patterns for downloads to match new naming convention

## Expected Computation Load

With the addition of model specifications, the computation load increases by 4x:
- **Original**: 1000 replicates × 3 M values × 5 methods = 15,000 computations
- **New**: 1000 replicates × 4 model specs × 3 M values × 5 methods = 60,000 computations

## Output Files

The script will generate:
- `comprehensive_patt_comparison_M135_CorAndMis_results.RData`: Main results file
- `comprehensive_patt_comparison_M135_CorAndMis_plot.pdf`: Summary plots
- `comprehensive_patt_comparison_M135_CorAndMis_boxplot.pdf`: Boxplots of estimates
- `patt_M135_CorAndMis_*.out`: SLURM output log
- `patt_M135_CorAndMis_*.err`: SLURM error log

## Results Structure

The results are stored in a nested list structure:
```R
all_results[[replicate]][[model_spec]][[M]][[method]]
```

Where:
- `replicate`: 1 to 1000
- `model_spec`: "CorCor", "MisCor", "CorMis", or "MisMis"
- `M`: "M1", "M3", or "M5"
- `method`: "dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", or "dsm_weighted"

Each method contains:
- `estimate`: Point estimate
- `se`: Standard error
- `ci_lower`: Lower CI bound
- `ci_upper`: Upper CI bound

## How to Submit

Use the quick commands script:
```bash
# Upload and submit in one command
./mccleary_patt_quick_commands.sh all

# Or step by step:
./mccleary_patt_quick_commands.sh upload
./mccleary_patt_quick_commands.sh submit
./mccleary_patt_quick_commands.sh status
./mccleary_patt_quick_commands.sh download
```

## Analysis Goals

This simulation helps us understand:
1. **Robustness**: How sensitive are different matching methods to model misspecification?
2. **Double Robustness**: Do DSM methods show better performance when either PS or PGS is correct?
3. **Interaction Effects**: Impact of missing the X1:X2 interaction term
4. **M Value Effects**: How does the number of matches interact with model misspecification?

## Notes

- The true data generating process includes the X1:X2 interaction
- Misspecified models omit this interaction term
- All methods use the same sample for fair comparison within each replicate
- Survey weights are handled consistently across all methods
