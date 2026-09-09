# Critical WDSM Fix Summary - January 27, 2025

## The Problem
The WDSM implementation had **hardcoded X1:X2 interaction terms** in multiple places, making it incompatible with model misspecification scenarios. This would have caused incorrect results for MisCor, CorMis, and MisMis scenarios.

## Locations of Hardcoded Interactions (Before Fix)

### 1. `wdsm_method2_multinomial_bootstrap.R`
- **Lines 65, 81, 92**: Hardcoded `A/Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2`
- These were in the bootstrap resampling functions

### 2. `wdsm_ci_functions.R`  
- **Lines 127, 142**: PS and PG model formulas (point estimate function)
- **Lines 316, 321, 427, 432**: Bootstrap functions with hardcoded interactions

## The Fix
Added two parameters to all WDSM functions:
- `use_interaction_ps`: Controls whether PS model includes X1:X2
- `use_interaction_pg`: Controls whether PGS model includes X1:X2

### Modified Functions:
1. `wdsm_point_estimate()` - Now accepts interaction flags
2. `method2_multinomial_bootstrap_ci()` - Now accepts and uses interaction flags
3. `compute_wdsm_method2_ci()` - Wrapper now passes through interaction flags

## Scenario-Specific Settings

| Scenario | use_interaction_ps | use_interaction_pg | Description |
|----------|-------------------|-------------------|-------------|
| **CorCor** | TRUE | TRUE | Both models correct (with X1:X2) |
| **MisCor** | FALSE | TRUE | PS misspecified, PGS correct |
| **CorMis** | TRUE | FALSE | PS correct, PGS misspecified |
| **MisMis** | FALSE | FALSE | Both models misspecified |

## Jobs Resubmitted

### Cancelled Jobs (Had Bug)
- 57548318, 57548321, 57548324, 57548327

### New Jobs (Fixed)
- **CorCor**: 57567348
- **MisCor**: 57567349  
- **CorMis**: 57567351
- **MisMis**: 57567352

## Impact of the Fix
Without this fix, all scenarios would have used the same model specification (with interactions), making the misspecification analysis meaningless. The WDSM results would have been identical across all scenarios, defeating the purpose of studying model misspecification effects.

## Files Updated
1. `wdsm_method2_multinomial_bootstrap.R` - Fixed in all 4 scenario folders
2. `wdsm_ci_functions.R` - Fixed in all 4 scenario folders
3. Comparison scripts already had correct logic to set flags based on scenario

## Verification
The comparison scripts correctly set the flags:
```r
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
```

This ensures each scenario uses the appropriate model specification for studying misspecification effects under poor overlap conditions.

## Lessons Learned
- Always parameterize model specifications instead of hardcoding
- When adapting code for different scenarios, check ALL functions in the call chain
- Bootstrap/resampling functions often duplicate model fitting code that needs updating
