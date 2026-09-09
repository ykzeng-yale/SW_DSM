# PATT Prospective Poor Overlap - M135 CorAndMis GLM

## Overview
This folder contains the complete set of files for the comprehensive PATT (Population Average Treatment Effect on the Treated) comparison study with Poor Overlap data, testing M=1,3,5 neighbors across 4 model specification scenarios.

## Key Features of This Version

### 1. **Model Specification Scenarios:**
- **CorCor**: Both PS and PGS models correct (include X1:X2 interaction)
- **MisCor**: PS misspecified (no X1:X2), PGS correct (has X1:X2)
- **CorMis**: PS correct (has X1:X2), PGS misspecified (no X1:X2)
- **MisMis**: Both PS and PGS misspecified (no X1:X2 in both)

### 2. **Method Specifications:**

#### Unweighted Methods (using dsmatch-master):
- **DSM**: GLM logit PS + linear outcome model
- **PG**: Linear outcome model 
- **PS**: GLM logit PS

#### Survey-Weighted Methods:
- **PS Full (MatchIt)**: Quasibinomial PS + marginaleffects for ATT
- **WDSM V1**: Quasibinomial PS + weighted LM (updated version)

### 3. **Key Parameters:**
- **M = 1, 3, 5**: Multiple numbers of matches per unit
- **B = 200**: Bootstrap iterations
- **n_reps = 1000**: Simulation replicates
- **n_cores = 20**: Parallel processing cores
- **Design**: Prospective sampling for PATT
- **Scenario**: Poor overlap (Scenario 1 from SuperPopGen)

## File Contents

1. **Main R Script**: 
   - `comprehensive_patt_comparison_mccleary.R` - HPC-adapted comparison script

2. **Method Implementations**:
   - `WDSM/` - Contains updated WDSM with quasibinomial GLM
   - `dsmatch-master/` - Original dsmatch package functions

3. **Data**:
   - `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData` - Population data

4. **Submission Scripts**:
   - `run_patt_comparison_mccleary.sh` - SLURM job script
   - `submit_patt_comparison_mccleary.sh` - Automated submission
   - `mccleary_patt_quick_commands.sh` - Quick command helpers

5. **Documentation**:
   - `PATT_McCleary_Submission_Guide.md` - Complete submission guide
   - This README file

## Important Updates in This Version

### WDSM Function (`WDSM/R/wdsm_patt_prospective_v1_simplified.R`):
- Changed from `family = binomial()` to `family = quasibinomial()` for PS estimation
- Better handles overdispersion from survey weights
- Consistent with MatchIt's automatic behavior

## HPC Submission Details

- **Job ID**: 57080035
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/patt_comparison_20250804_1316`
- **Expected Runtime**: 60-90 minutes
- **Resources**: 22 CPUs, 176GB RAM, FORK cluster

## Expected Outputs

1. `comprehensive_patt_comparison_results.RData` - All simulation results
2. `comprehensive_patt_comparison_table.csv` - Summary statistics
3. `comprehensive_patt_comparison_plot.pdf` - Comparison plots
4. `comprehensive_patt_comparison_boxplot.pdf` - Distribution plots

## Notes

- This is the "corrected" version with proper quasibinomial GLM for survey weights
- All methods handle interaction terms appropriately
- FORK cluster type used for better stability on HPC
- Bootstrap variance estimation ensures valid inference

## To Monitor/Download Results

```bash
# Check status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57080035'

# Download results
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_comparison_20250804_1316/comprehensive_patt_comparison_* .
```