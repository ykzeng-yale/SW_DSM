# PATT Prospective Good Overlap M=1,3,5 Comparison

## Overview
This directory contains the modified version of the comprehensive PATT comparison that tests multiple matching ratios (M=1, M=3, and M=5) in each replicate to evaluate the effect of the number of matches on method performance.

## Key Modifications from M=5 Version

### 1. Script Changes (`comprehensive_patt_comparison_mccleary.R`)
- **Multiple M values**: Now loops over M=1, 3, 5 within each replicate
- **Nested results structure**: Results are organized by M value, then by method
- **Enhanced visualization**: Plots are faceted by M value to show comparisons
- **Separate outputs**: Each M value gets its own results table and summary statistics

### 2. Main Changes:
- `run_single_replicate_M()`: Handles a single M value for a replicate
- `run_single_replicate()`: Wrapper that loops over all M values (1, 3, 5)
- Results stored as `summary_stats_all[["M1"]]`, `summary_stats_all[["M3"]]`, `summary_stats_all[["M5"]]`
- Output files named with M value: `comprehensive_patt_comparison_M1_table.csv`, etc.

### 3. SLURM Configuration Updates
- **Job name**: `patt_M135_comparison`
- **Runtime**: Increased to 12 hours (3x longer due to 3 M values)
- **Output files**: Named with M135 prefix
- All other resources (CPUs, memory) remain the same

## Methods Compared
For each M value (1, 3, 5), the following methods are compared:
1. **Unweighted DSM** (dsmatch-master with bootstrap, GLM logit PS + linear outcome)
2. **Unweighted PG matching** (dsmatch-master with bootstrap, linear outcome model)
3. **Unweighted PS matching** (dsmatch-master with bootstrap, GLM logit PS)
4. **Survey-weighted PS full matching** (MatchIt with marginaleffects, quasibinomial PS)
5. **Survey-weighted DSM** (Version 1 WDSM - Simplified with all updates)

## Configuration
- **Replicates**: 1000
- **M values**: 1, 3, 5 (number of matches per treated unit)
- **Bootstrap iterations**: 200
- **Parallel processing**: 20 cores (FORK cluster)
- **Batch size**: 100 replicates
- **Timeout per replicate**: 5 minutes (covers all M values)

## Files
- `comprehensive_patt_comparison_mccleary.R`: Main R script with M=1,3,5 loop
- `run_patt_comparison_mccleary.sh`: SLURM submission script
- `submit_patt_comparison_mccleary.sh`: Automated submission script
- `mccleary_patt_quick_commands.sh`: Quick command utilities

## Expected Output Files
- `comprehensive_patt_comparison_M135_results.RData`: All results
- `comprehensive_patt_comparison_M1_table.csv`: Results for M=1
- `comprehensive_patt_comparison_M3_table.csv`: Results for M=3
- `comprehensive_patt_comparison_M5_table.csv`: Results for M=5
- `comprehensive_patt_comparison_M135_plot.pdf`: Comparison plots
- `comprehensive_patt_comparison_M135_boxplot.pdf`: Distribution plots

## How to Submit to McCleary HPC

### Option 1: Automated submission
```bash
./submit_patt_comparison_mccleary.sh
```

### Option 2: Manual submission
```bash
# Upload files
./mccleary_patt_quick_commands.sh upload

# Submit job (will ask for directory)
./mccleary_patt_quick_commands.sh submit

# Check status
./mccleary_patt_quick_commands.sh status

# Download results when complete
./mccleary_patt_quick_commands.sh download
```

## Expected Runtime
- Approximately 3-4 hours on McCleary HPC (20 cores)
- 3x longer than single M version due to testing M=1,3,5

## Notes
- The M parameter is passed to dsmatchATT functions via the `...` argument
- For MatchIt PS Full matching, the method doesn't use M (uses full matching)
- WDSM doesn't use M parameter directly (uses all available data)