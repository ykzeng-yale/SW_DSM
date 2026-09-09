# PATT Retrospective Goodoverlap M5 BothCorrect GLM

This folder contains all files submitted to McCleary HPC on August 4, 2025.

## Job Information
- **Job ID**: 57079650
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_1302/`
- **Submission Time**: August 4, 2025, 14:05
- **Configuration**: 20 cores, 1000 replicates, M=5, B=200

## Files Included

### Main Scripts
- `compare_methods_patt_retrospective_mccleary.R` - HPC-adapted comparison script
- `compare_methods_patt_retrospective_local.R` - Local version (for reference)
- `wdsm_patt_v2_standard.R` - WDSM implementation with standard GLM/LM

### Data
- `SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData` - Super population data

### Dependencies
- `dsmatch-master/` - Double score matching package

### Submission Scripts
- `submit_patt_retrospective_mccleary.sh` - SLURM submission script
- `submit_to_mccleary_patt_retrospective.sh` - One-click submission script
- `mccleary_quick_commands.sh` - Utility commands for monitoring

## Key Features
1. **"BothCorrect"** refers to:
   - Propensity score: GLM with `quasibinomial` family for survey weights
   - Prognostic score: Standard `lm()` with survey weights
   - Both models include x1:x2 interaction term

2. **GLM** indicates:
   - Using standard GLM instead of Ridge regression
   - Fast linear model instead of slow loess for mu_0 approximation

3. **Methods Compared**:
   - Unweighted DSM, PS, PG (dsmatch-master)
   - Survey-weighted PS full matching (MatchIt)
   - Survey-weighted DSM V2 with standard GLM/LM

## Expected Results
Results will include:
- `comprehensive_patt_retrospective_results.RData`
- `comprehensive_patt_retrospective_table.csv`
- `comprehensive_patt_retrospective_plot.pdf`
- `comprehensive_patt_retrospective_boxplot.pdf`

## Monitoring Commands
```bash
# Check status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57079650'

# View output
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_1302/patt_retrospective_*.out'

# Download results when complete
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_1302/comprehensive_patt_retrospective_* .
```