# Comprehensive Setup Verification for Poor Overlap WDSM Simulation
## Date: 2025-08-26

## ✅ VERIFICATION CHECKLIST

### 1. Population Data ✅
- **File**: `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`
- **Source**: Matches `SW_PSW-main/Super_Population_PoorOverlap.R` with delta_z = 2
- **Size**: N = 1,000,000
- **Sample Size**: n = 5000 (NOT 1000)
- **Columns**: Renamed x1→X1, x2→X2, etc., z→A, y→Y
- **Interaction**: X1X2 added after loading
- **True PATE**: Calculated from y1 - y0 potential outcomes

### 2. Sampling Mechanism ✅
- **Type**: Retrospective (treatment-dependent)
- **Method**: Probability-based, NOT stratified
- **Coefficients**: 
  - Control: γ0 = (-0.8, 0.2, 0.3, 0.1, -0.3, 0.3, -0.1, 0.0)
  - Treated: γ1 = (-0.8, 0.1, -0.1, 0.5, -0.3, -0.3, 0.0, 0.0)
- **Weights**: Properly calculated as 1/selection_probability

### 3. Model Specifications ✅
#### Scenario Definitions:
- **CorCor**: Both PS and PGS include X1:X2 interaction
- **MisCor**: PS misspecified (no X1:X2), PGS correct (has X1:X2)
- **CorMis**: PS correct (has X1:X2), PGS misspecified (no X1:X2)
- **MisMis**: Both PS and PGS misspecified (no X1:X2)

#### Implementation:
- DSM uses SEPARATE matrices: X for PS, lp.pg for PGS
- Model types: ALWAYS "logit" for PS, "glm"/"linpred" for PGS
- PS Full outcome model: ALWAYS correctly specified for bias correction

### 4. External Function Sourcing ✅
#### Global Level:
```r
# dsmatch functions (in order)
source("dsmatch-master/R/bisect.R")
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")  # LAST!

# WDSM functions  
source("wdsm_method2_multinomial_bootstrap_WALD.R")
source("wdsm_ci_functions.R")
```

#### Inside Parallel Workers:
- Re-source ALL dsmatch files (PSOCK clusters don't inherit)
- Re-source WDSM functions
- Export data and functions via .export parameter

### 5. Method Calls ✅
#### Unweighted Methods (DSM, PG, PS):
- Use dsmatchATE with weights = rep(1, n)
- No M parameter passed (uses default)
- Bootstrap manually for SE calculation

#### Survey-Weighted PS Full:
- Normalize weights: sw_norm = sw * n / sum(sw)
- Use MatchIt with s.weights = sw_norm
- Outcome model always correctly specified
- Use avg_comparisons with vcov = ~subclass

#### WDSM:
- Uses compute_wdsm_method2_ci function
- Normal Wald CI (NOT quantile)
- Bias correction enabled
- M = 5

### 6. Performance Metrics ✅
- **Relative Bias**: (mean(estimate) - true_pate) / true_pate
- **SE Ratio**: mean(se) / sd(estimate)
- **Coverage**: mean(ci_lower <= true_pate & ci_upper >= true_pate)
- **Relative Efficiency**: var(reference_method) / var(method)
- **Reference Method**: ps_unweighted

### 7. Time Limits ✅
- **Job Level**: 23 hours for day partition
- **Method Level**: NONE (no withTimeout)
- **Bootstrap**: Run to completion

### 8. WDSM Implementation Details ✅
- **CI Construction**: Normal Wald (estimate ± 1.96*SE)
- **Bootstrap**: Multinomial with uniform weights
- **Bias Correction**: Polynomial sieve on scores
- **Score Transformation**: Logit transformation applied
- **λij Calculation**: Fixed (includes donor weight)
- **Score Spaces**: Separate S0/S1 spaces
- **Outcome Model**: Fitted on scores, not X

### 9. Parallel Processing ✅
- **Cluster Type**: FORK on local, PSOCK on HPC
- **Cores**: 12 for 100 reps, can increase for larger runs
- **Memory**: 5GB per CPU
- **Export**: All necessary functions and data

### 10. File Structure ✅
```
Poor Overlap Scenarios/
├── CorCor/
│   ├── compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R
│   ├── wdsm_method2_multinomial_bootstrap_WALD.R
│   ├── wdsm_ci_functions.R
│   ├── SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData
│   └── dsmatch-master/
├── MisCor/
├── CorMis/
└── MisMis/
```

## ⚠️ CRITICAL REMINDERS

1. **Sample Size**: Always n=5000, NOT 1000
2. **Weights**: Must be normalized for MatchIt
3. **dsmatchATE**: Returns treatment.effect, standard.error, CI fields
4. **Bootstrap**: Uniform multinomial for WDSM
5. **CI Type**: Normal Wald for WDSM coverage
6. **Source Order**: dsmatchATE.R must be sourced LAST
7. **Memory**: Monitor usage, especially for 1000 reps
8. **Accounts**: Use li_fan or tong based on fairshare

## 🎯 EXPECTED RESULTS

### Theoretical Expectations:
- CorCor and CorMis: Identical for PS-based methods
- CorCor and MisCor: Identical for PG-based methods
- WDSM: Should show improved performance over unweighted methods

### Performance Targets:
- Coverage: 93-97% for all methods
- Bias: < 3% for correctly specified models
- SE Ratio: 0.85-1.15 for well-calibrated methods

## 🚀 SUBMISSION COMMANDS

### McCleary:
```bash
sbatch --account=li_fan --partition=day --time=23:00:00 script.sh
sbatch --account=tong --partition=day --time=23:00:00 script.sh
```

### Bouchet:
```bash
sbatch --account=default --partition=day --time=24:00:00 script.sh
```

## ✓ FINAL CHECK
All components verified and ready for production runs.
