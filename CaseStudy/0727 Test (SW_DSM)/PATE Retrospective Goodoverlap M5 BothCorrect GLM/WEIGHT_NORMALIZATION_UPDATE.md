# Survey Weight Normalization Update

## Date: 2025-02-04

## Issue Identified
Survey weights were not being normalized in the comparison script. The raw inverse probability weights (1/prob) were being used directly.

## Fix Applied
Added weight normalization using the formula: **w × length(w)/sum(w)**

This normalization ensures:
1. Weights sum to the sample size (n)
2. Variance estimates are properly scaled
3. Standard errors are correctly computed

## Changes Made

### In `compare_methods_pate_retrospective_mccleary.R` (lines 96-99):
```r
# Normalize survey weights: w × length(w)/sum(w)
# This ensures weights sum to sample size for proper variance estimation
w <- sample$survey_weight
w <- w * length(w) / sum(w)
```

### In `compare_methods_pate_retrospective.R` (lines 59-62):
```r
# Normalize survey weights: w × length(w)/sum(w)
# This ensures weights sum to sample size for proper variance estimation
w <- sample$survey_weight
w <- w * length(w) / sum(w)
```

## Impact
This normalization affects:
- **Method 4**: PS Full (Survey-Weighted) using MatchIt
- **Method 5**: WDSM (Weighted Double Score Matching)

Both methods now use properly normalized survey weights, which should:
- Improve variance estimation accuracy
- Potentially improve coverage rates
- Ensure consistent weight scaling across methods

## Submission Details
- Job name: `pate_norm_1000`
- Remote directory: `/gpfs/gibbs/project/tong/yz2324/pate_retro_norm_TIMESTAMP`
- 1000 replicates with normalized weights