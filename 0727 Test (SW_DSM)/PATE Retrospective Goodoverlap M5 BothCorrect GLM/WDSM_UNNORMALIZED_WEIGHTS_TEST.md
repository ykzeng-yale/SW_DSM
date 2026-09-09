# WDSM with Unnormalized Weights Test

## Date: 2025-02-04

## Hypothesis
WDSM may not require weight normalization like PS Full (Survey-Weighted) does. The method might handle survey weights differently internally.

## Experimental Design
- **PS Full (Survey-Weighted)**: Uses normalized weights `w × length(w)/sum(w)`
- **WDSM**: Uses original unnormalized weights (inverse probability weights)
- **All other methods**: Unchanged from previous run

## Changes Made

### In `compare_methods_pate_retrospective_mccleary.R`:
1. Lines 96-101: Created two versions of weights:
   - `w`: Original survey weights for WDSM
   - `w_normalized`: Normalized weights for PS Full

2. Line 240: PS Full uses `w_normalized`
3. Line 300: WDSM uses original `w` (unnormalized)

### Configuration
- 1000 replicates
- Sample size: n=5000 (retrospective)
- Bootstrap: B=200
- Matching ratio: M=5
- 20 cores (FORK cluster)

## Expected Outcomes

### If WDSM doesn't need normalization:
- WDSM should maintain good coverage (~93-95%)
- PS Full should maintain good coverage (~94%) with normalization
- Both methods should have low bias

### If WDSM does need normalization:
- WDSM might show undercoverage
- SE/SD ratio might deteriorate
- Coverage might drop below nominal levels

## Previous Results (Both with normalization)
- PS Full: Coverage 93.900%, Rel Bias -0.632%, Rel Eff 1.803
- WDSM: Coverage 93.500%, Rel Bias -0.614%, Rel Eff 2.327

## Submission Details
- Job name: `pate_wdsm_unnorm`
- Remote directory: `/gpfs/gibbs/project/tong/yz2324/pate_wdsm_unnorm_TIMESTAMP`
