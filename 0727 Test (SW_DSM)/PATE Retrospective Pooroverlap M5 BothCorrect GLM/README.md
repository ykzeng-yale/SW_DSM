# PATE Retrospective Pooroverlap M5 BothCorrect GLM

This folder contains all files for the PATE retrospective sampling comparison study with the following key improvements:

## Key Features:
1. **Correct GLM specification for PS models**:
   - All methods use `model.ps = "logit"` with interaction term included in X
   - Consistent with prospective sampling implementation

2. **Quasibinomial GLM for WDSM**:
   - Updated to use `quasibinomial` instead of `binomial` for survey-weighted PS estimation
   - Properly handles overdispersion in weighted data

3. **M=5 matches** for all matching methods

4. **Poor overlap scenario** from population data

## Files Included:

### Main Scripts:
- `compare_methods_pate_retrospective_mccleary.R` - Main comparison script for McCleary HPC
- `compare_methods_pate_retrospective.R` - Local version for reference

### WDSM Functions (with quasibinomial update):
- `wdsm_ci_functions.R` - Core WDSM functions with quasibinomial PS estimation
- `wdsm_method2_multinomial_bootstrap.R` - Multinomial bootstrap implementation

### Submission Scripts:
- `submit_pate_retrospective_mccleary.sh` - SLURM submission script
- `mccleary_submit_retrospective.sh` - Convenient upload and submission tool

### Data and Dependencies:
- `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData` - Population data
- `dsmatch-master/` - dsmatch package directory

## Methods Compared:
1. **DSM (Unweighted)** - Double Score Matching
2. **PG (Unweighted)** - Prognostic Score Matching
3. **PS (Unweighted)** - Propensity Score Matching
4. **PS Full (Survey-Weighted)** - MatchIt with survey weights
5. **WDSM (Multinomial Bootstrap)** - Weighted DSM with retrospective sampling

## Configuration:
- Sample size: 5000 (retrospective)
- Replicates: 1000
- Bootstrap iterations: 200
- Matches per unit: M=5
- Interaction term: X1:X2 included in all models

## Latest Submission:
- Job ID: 57161953 (WITH WEIGHT NORMALIZATION)
- Previous Job: 57117031 (without weight normalization)
- Submitted: 2025-08-07 11:30
- Directory: `/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/`

## Key Improvements in This Version:
1. ✅ All PS models use `model.ps = "logit"` with interaction in X
2. ✅ WDSM uses `quasibinomial` for survey-weighted PS estimation
3. ✅ Consistent model specification across all methods
4. ✅ Proper handling of overdispersion in weighted regression
5. ✅ **CRITICAL FIX: Survey weights normalized to sum to sample size (w × n/sum(w))**