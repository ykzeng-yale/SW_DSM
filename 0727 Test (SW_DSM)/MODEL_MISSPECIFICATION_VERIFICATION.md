# Model Misspecification Implementation Verification

## ✅ Implementation Verified

All WDSM functions and comparison scripts have been thoroughly checked and correctly handle model misspecification scenarios.

## 1. WDSM Function Signatures

### wdsm_point_estimate() - CORRECT ✅
```r
wdsm_point_estimate <- function(data, M = 3, use_bias_correction = FALSE, 
                               use_interaction_ps = TRUE, use_interaction_pg = TRUE)
```
- Correctly uses `use_interaction_ps` for propensity score formula
- Correctly uses `use_interaction_pg` for prognostic score formula
- No hardcoded interaction terms

### compute_wdsm_method2_ci() - CORRECT ✅
```r
compute_wdsm_method2_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
                                   alpha = 0.05, use_bias_correction = TRUE,
                                   return_samples = FALSE, 
                                   use_interaction_ps = TRUE, use_interaction_pg = TRUE)
```
- Properly passes parameters to `wdsm_point_estimate()`
- Properly passes parameters to `method2_multinomial_bootstrap_ci()`

### method2_multinomial_bootstrap_ci() - CORRECT ✅
```r
method2_multinomial_bootstrap_ci <- function(data, indices, point_estimate, n_bootstrap = 100, alpha = 0.05, 
                                            use_bias_correction = TRUE, return_samples = FALSE,
                                            use_interaction_ps = TRUE, use_interaction_pg = TRUE)
```
- Re-estimates models in each bootstrap iteration with correct formulas
- PS formula: `A ~ X1 + X2 + X3 + X4 + X5 + X6` or `A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2`
- PG formula: `Y ~ X1 + X2 + X3 + X4 + X5 + X6` or `Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2`

## 2. Scenario Configuration

Each scenario folder has the correct setting:

| Folder | Scenario | PS Model | PGS Model |
|--------|----------|----------|-----------|
| CorCor GLM | `scenarios <- c("CorCor")` | ✅ Has X1:X2 | ✅ Has X1:X2 |
| MisCor GLM | `scenarios <- c("MisCor")` | ❌ No X1:X2 | ✅ Has X1:X2 |
| CorMis GLM | `scenarios <- c("CorMis")` | ✅ Has X1:X2 | ❌ No X1:X2 |
| MisMis GLM | `scenarios <- c("MisMis")` | ❌ No X1:X2 | ❌ No X1:X2 |

## 3. Scenario Logic in Comparison Script

The comparison script correctly maps scenarios to model specifications:

```r
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
```

This produces the correct mapping:
- **CorCor**: `use_interaction_ps = TRUE`, `use_interaction_pg = TRUE`
- **MisCor**: `use_interaction_ps = FALSE`, `use_interaction_pg = TRUE`
- **CorMis**: `use_interaction_ps = TRUE`, `use_interaction_pg = FALSE`
- **MisMis**: `use_interaction_ps = FALSE`, `use_interaction_pg = FALSE`

## 4. Method-Specific Implementation

### Unweighted DSM (Method 1) ✅
- Uses appropriate X_ps and X_pg matrices based on scenario
- Correctly switches between "linpred" and "logit" models

### Unweighted PG Matching (Method 2) ✅
- Uses X_pg matrix with/without interaction based on `use_interaction_pg`

### Unweighted PS Matching (Method 3) ✅
- Uses X_ps matrix with/without interaction based on `use_interaction_ps`

### Survey-Weighted PS (Method 4) ✅
- PS formula: Correctly uses interaction based on `use_interaction_ps`
- Outcome model: Correctly uses interaction based on `use_interaction_pg`

### WDSM (Method 5) ✅
- Passes `use_interaction_ps` and `use_interaction_pg` to all functions
- Bootstrap iterations correctly re-estimate with appropriate formulas
- No hardcoded interaction terms anywhere

## 5. Job Submission Status

All 4 jobs successfully submitted:
- Job 57548129: CorCor (Both Correct)
- Job 57548131: MisCor (PS Misspecified)
- Job 57548133: CorMis (PGS Misspecified)
- Job 57548134: MisMis (Both Misspecified)

## Conclusion

✅ **All implementations are correct.** The WDSM functions and comparison scripts properly handle model misspecification scenarios without hardcoding interaction terms. Each scenario will correctly estimate models with or without the X1:X2 interaction term based on the scenario requirements.
