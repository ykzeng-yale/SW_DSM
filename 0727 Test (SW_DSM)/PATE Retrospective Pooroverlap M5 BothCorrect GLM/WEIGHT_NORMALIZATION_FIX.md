# Critical Fix: Survey Weight Normalization

## Issue Identified
Survey weights were not normalized in the previous submission (Job ID: 57117031).
The raw survey weights (1/sampling_probability) can sum to very large values, which can affect variance estimation and stability.

## Solution Implemented
Added proper survey weight normalization: **w_normalized = w_raw × n / sum(w_raw)**

This ensures that:
- Weights sum to the sample size (n)
- Proper variance estimation for survey-weighted methods
- Consistent weight scaling across all methods

## Code Changes

### Location: compare_methods_pate_retrospective_mccleary.R (lines 95-99)
```r
# Old code:
w <- sample$survey_weight

# New code:
w_raw <- sample$survey_weight

# CRITICAL: Normalize survey weights to sum to sample size
# This is essential for proper variance estimation
w <- w_raw * length(w_raw) / sum(w_raw)
```

## Methods Affected
1. **PS Full (Survey-Weighted)**: Uses normalized weights in MatchIt
2. **WDSM (Multinomial Bootstrap)**: Uses normalized weights for all computations

## Expected Impact
- Better coverage for survey-weighted methods
- More stable variance estimates
- Improved performance for PS Full method especially

## Verification
The normalized weights will:
- Sum to exactly n (sample size)
- Maintain relative weight ratios
- Provide proper finite-sample corrections

## Resubmission Required
This fix requires rerunning the simulation to get accurate results with properly normalized weights.