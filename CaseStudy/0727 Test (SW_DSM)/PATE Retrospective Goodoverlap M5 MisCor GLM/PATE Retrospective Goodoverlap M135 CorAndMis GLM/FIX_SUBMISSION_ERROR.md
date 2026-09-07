# Function Call Error Fix

## Issue Found:
The comparison scripts were calling `method2_multinomial_bootstrap_ci` directly instead of using the wrapper function `compute_wdsm_method2_ci`.

## Root Cause:
- `method2_multinomial_bootstrap_ci` expects `(data, indices, point_estimate, ...)` arguments
- The script was passing `(Y, X, A, weights, ...)` arguments
- The wrapper `compute_wdsm_method2_ci` converts between these interfaces

## Fix Applied:
1. Changed function call from `method2_multinomial_bootstrap_ci` to `compute_wdsm_method2_ci`
2. Removed redundant `point_estimate` calculation (wrapper handles this internally)
3. Updated to use results from `ci_results` directly:
   - `estimate = ci_results$estimate` (not `point_estimate$tau`)
   - `se = ci_results$se` (not `sd(ci_results$bootstrap_estimates)`)

## Files Updated:
- `compare_methods_pate_retrospective_mccleary.R`
- `compare_methods_pate_retrospective.R`

This should resolve the "unused arguments" error and allow all replicates to complete successfully.