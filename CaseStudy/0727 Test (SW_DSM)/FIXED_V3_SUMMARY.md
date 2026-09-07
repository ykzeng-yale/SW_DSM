# FIXED v3 - Comprehensive Fixes Applied

## Issues Identified and Fixed

### 1. ✅ **Function Sourcing Structure (CRITICAL)**

**ISSUE**: The original scripts only sourced functions inside parallel workers, not globally

**FIX**: Now following the Good Overlap structure exactly:
- Source ALL functions globally first
- Re-source inside parallel workers for FORK clusters
- This ensures functions are available in all contexts

```r
# GLOBAL sourcing (at top of script)
for (file in dsmatch_files) {
  source(file)
}
source("wdsm_method2_multinomial_bootstrap.R")
source("wdsm_ci_functions.R")

# ALSO inside run_single_replicate for parallel workers
```

### 2. ✅ **Redundant retrospective_sample Definition**

**ISSUE**: The retrospective_sample function was defined in:
- Main script (lines 36-65) 
- wdsm_ci_functions.R (lines 35-65)
This caused confusion and potential conflicts

**FIX**: Removed redundant definition from main script, using only the one from wdsm_ci_functions.R

### 3. ✅ **dsmatchATE.R Sourcing Order**

**ISSUE**: dsmatchATE.R was being sourced before its dependencies

**FIX**: Now sourced LAST in the list:
```r
dsmatch_files <- c(
  "dsmatch-master/R/bisect.R",
  "dsmatch-master/R/is.lp.R",
  # ... other dependencies ...
  "dsmatch-master/R/dsmatchATE.R"  # LAST
)
```

### 4. ✅ **Data Loading Structure**

**ISSUE**: Inconsistent with Good Overlap version

**FIX**: Now follows exact pattern:
```r
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025
population <- data_sets[[1]]
# Rename columns consistently
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
# etc.
```

### 5. ✅ **Parallel Export List**

**ISSUE**: Missing key functions in .export list

**FIX**: Comprehensive export list:
```r
.export = c("run_single_replicate", "population", "true_pate",
           "n_sample", "M_values", "B", "alpha", "scenarios",
           "retrospective_sample", "wdsm_point_estimate",
           "method2_multinomial_bootstrap_ci",
           "compute_wdsm_method2_ci")
```

### 6. ✅ **Error Handling**

**ISSUE**: Silent failures made debugging difficult

**FIX**: Added detailed error messages:
```r
}, error = function(e) {
  cat("DSM error:", e$message, "\n")
  # ...
})
```

## Retrospective Sampling Verification

The retrospective sampling is now correctly implemented:

```r
# From wdsm_ci_functions.R
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients from SW_PSW-main
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05); c2 <- log(1.10); c3 <- log(1.15)
  c4 <- log(1.10); c5 <- log(1.05); c6 <- log(1.10)
  delta_z_in_s <- log(0.9)
  
  # Probability-based sampling
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 + ...
  
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$S <- rbinom(N, 1, prob_S)
  
  # Survey weights
  sample_data$survey_weight <- 1 / sample_data$Prob
}
```

## Expected Results After Fixes

With all fixes applied, we expect:

### Unweighted Methods (DSM, PS, PG)
- Should run successfully (were returning NULL before)
- Coverage around 93-95%
- Model specification patterns should hold

### Weighted Methods (PS Full, WDSM)
- **WDSM in CorCor**: 
  - Bias: <1% (was 3%)
  - Coverage: ~93-95% (was 79%)
  - SE Ratio: ~0.95-1.05 (was 0.63)

### Pattern Verification
- **PS methods**: Similar results for (CorCor, CorMis) and (MisCor, MisMis)
- **PG methods**: Similar results for (CorCor, MisCor) and (CorMis, MisMis)
- **DSM/WDSM**: Best in CorCor, worst in MisMis

## Files Created

- `compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R` - Main script for each scenario
- `run_job_v3.sh` - SLURM submission script
- Results will be saved as `raw_results_20reps_[scenario]_FIXED_V3.RData`

## Submission

To submit the fixed jobs:
```bash
chmod +x submit_fixed_v3_to_tong.sh
./submit_fixed_v3_to_tong.sh
```

Monitor with:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep FIXv3'
```
