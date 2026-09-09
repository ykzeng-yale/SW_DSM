# Comprehensive Verification Report: Poor Overlap Simulation

## Executive Summary
**Critical Issues Found**: 3 major problems identified that explain the failures

## 1. ✅ CORRECT: Population Data
- **File**: `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData` ✅
- **True PATE**: 0.8664 (correct for poor overlap with δ_z = 2) ✅
- **Sample size**: n = 5000 ✅

## 2. ✅ CORRECT: Retrospective Sampling
- **Function**: `retrospective_sample` from `wdsm_ci_functions.R` ✅
- **Method**: Probability-based sampling with `1/Prob` weights ✅
- **Coefficients**: Using correct c0-c6 and delta_z_in_s values ✅

## 3. ✅ CORRECT: Function Sourcing
Both globally and within parallel workers:
- **Global sourcing**: Lines 26-45 ✅
- **Worker sourcing**: Lines 64-82 ✅
- **WDSM functions**: Properly sourced ✅
- **Export list**: All required functions exported ✅

## 4. ❌ CRITICAL ISSUE: dsmatchATE Return Value Extraction

### The Problem
**Poor Overlap Script** (WRONG):
```r
estimate = dsm_result$treatment.effect  # ❌ WRONG FIELD
se = dsm_result$standard.error         # ❌ WRONG FIELD  
ci_lower = dsm_result$CI[1]           # ❌ WRONG FIELD
```

**Good Overlap Script** (CORRECT):
```r
estimate = dsm_result$est.ds           # ✅ CORRECT
se = sqrt(dsm_result$bootvar[1,1])     # ✅ CORRECT
ci_lower = dsm_result$est.ds - qnorm(1-alpha/2) * sqrt(dsm_result$bootvar[1,1])  # ✅
```

### Impact
- This causes ALL unweighted methods (DSM, PG, PS) to fail
- Methods try to access non-existent fields → NA results

## 5. ✅ CORRECT: Model Specifications
- **CorCor**: Both PS and PG include interaction ✅
- **MisCor**: PS no interaction, PG has interaction ✅
- **CorMis**: PS has interaction, PG no interaction ✅
- **MisMis**: Neither has interaction ✅

## 6. ✅ CORRECT: No Individual Method Timeouts
- No `setTimeLimit` or `withTimeout` on individual methods ✅
- Only job-level 4-hour limit in SLURM ✅

## 7. ⚠️ MINOR ISSUE: WDSM CI Construction
- Using normal approximation (qnorm) ✅
- Has bias correction ✅
- But coverage is 90% instead of 95% (calibration issue)

## 8. ⚠️ MINOR ISSUE: WDSM Bias in CorCor
- **Observed**: -3.22% bias
- **Expected**: <1% bias
- **Possible causes**:
  - Only 20 replications (need more for stability)
  - Potential issue in WDSM implementation under poor overlap

## 9. ✅ CORRECT: Relative Efficiency Calculation
- Using empirical SE across replications ✅
- SE ratio = mean_se / empirical_se ✅

## Required Fixes

### Fix 1: Correct dsmatchATE Field Extraction
For each unweighted method, change:
```r
# FROM:
estimate = dsm_result$treatment.effect
se = dsm_result$standard.error
ci_lower = dsm_result$CI[1]
ci_upper = dsm_result$CI[2]

# TO:
estimate = dsm_result$est.ds  # or est.pg, est.ps
se = sqrt(dsm_result$bootvar[1,1])
ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * se
ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * se
```

### Fix 2: Increase Replications
- Current: 20 reps (insufficient)
- Recommended: 1000 reps (like good overlap)

### Fix 3: Verify WDSM Implementation
- Check λ_ij calculation
- Check bootstrap weight calibration
- Check score space construction

## Verification Against User's Checklist

| Item | Status | Details |
|------|--------|---------|
| 1. Correct population data | ✅ | Poor overlap data with PATE=0.8664 |
| 2. Correct sampling mechanism | ✅ | Retrospective with 1/Prob weights |
| 3. External functions sourced | ✅ | Both globally and in workers |
| 4. Methods calling correctly | ❌ | Wrong field extraction for unweighted |
| 5. Model specs passing | ✅ | Correctly differentiated by scenario |
| 6. Metrics setup | ✅ | Rel bias, SE ratio, coverage correct |
| 7. No individual timeouts | ✅ | Only job-level timeout |
| 8. WDSM normal CI | ✅ | Using qnorm, not quantile |
| 9. WDSM bias correction | ✅ | Polynomial sieve on scores |

## Conclusion
**Main Issue**: dsmatchATE field extraction mismatch
**Solution**: Fix field names to match actual return structure
**Expected Result**: All 5 methods should produce results after fix