# Survey-Weighted Standardization Correction

## Critical Issue Found and Fixed

### ❌ Previous Implementation
```r
# Used standard scale() which ignores survey weights
double_score_0_std <- scale(double_score_0)
double_score_1_std <- scale(double_score_1)
```

### ✅ Corrected Implementation
```r
# Now uses survey-weighted standardization
double_score_0_std <- standardize_with_weights(double_score_0, w)
double_score_1_std <- standardize_with_weights(double_score_1, w)
```

## Added Function
```r
standardize_with_weights <- function(S, weights) {
  w_sum <- sum(weights)
  
  # Weighted mean
  S_mean <- colSums(weights * S) / w_sum
  
  # Weighted standard deviation
  S_centered <- sweep(S, 2, S_mean, "-")
  S_var <- colSums(weights * S_centered^2) / w_sum
  S_sd <- sqrt(S_var)
  
  # Avoid division by zero
  S_sd[S_sd < 1e-10] <- 1
  
  # Standardize
  S_std <- sweep(S_centered, 2, S_sd, "/")
  
  return(S_std)
}
```

## Why This Matters

1. **Survey Design Consistency**: The double scores must be standardized using the same weights that represent the population
2. **Correct Distance Calculation**: Unweighted standardization could distort the matching space
3. **Alignment with PATT**: The PATT retrospective code correctly uses weighted standardization

## Impact on Results

- This affects how distances are calculated for matching
- May improve the quality of matches, especially when survey weights vary substantially
- Ensures the standardization respects the sampling design throughout

## Files Updated
- `wdsm_ci_functions.R` (main directory)
- `PATE Retrospective Goodoverlap M5 BothCorrect GLM/wdsm_ci_functions.R`

## Next Steps
This correction should be included in the next server submission to ensure proper handling of survey weights in the matching process.