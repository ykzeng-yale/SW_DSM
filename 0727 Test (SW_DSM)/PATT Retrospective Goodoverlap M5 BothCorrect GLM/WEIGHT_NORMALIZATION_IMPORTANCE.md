# Survey Weight Normalization - Essential for Proper Variance Estimation

## The Issue
Survey weights in retrospective sampling are calculated as inverse probability weights: `w = 1/Prob`. However, these raw weights need to be normalized for proper variance estimation in survey-weighted methods.

## The Solution
**Normalization formula**: `w_normalized = w × length(w) / sum(w)`

This ensures:
- `sum(w_normalized) = n` (sample size)
- `mean(w_normalized) = 1`

## Why It's Essential

### 1. **Variance Estimation**
Without normalization, the effective sample size is misrepresented, leading to:
- Incorrect standard errors
- Invalid confidence intervals
- Wrong coverage probabilities

### 2. **Methods Affected**
- **PS Full (Survey-Weighted)**: Uses survey weights in MatchIt
- **WDSM**: Uses survey weights throughout PS, PG, and bootstrap

### 3. **Statistical Properties**
Normalized weights ensure:
- Consistent estimators
- Proper finite-sample behavior
- Valid bootstrap procedures

## Implementation Details

### Before (Incorrect)
```r
sample$weights <- 1 / sample$Prob
w <- sample$weights  # Raw, unnormalized weights
```

### After (Correct)
```r
sample$weights <- 1 / sample$Prob
# ESSENTIAL: Normalize survey weights
sample$weights <- sample$weights * length(sample$weights) / sum(sample$weights)
w <- sample$weights  # Normalized weights
```

## Verification
After normalization:
- `sum(weights) == n`: ✓
- `mean(weights) == 1`: ✓

## Impact on Results
Normalization is expected to:
1. Improve standard error estimation
2. Achieve better coverage rates
3. Provide more reliable confidence intervals

## References
- Survey sampling literature emphasizes weight normalization
- MatchIt documentation recommends normalized weights
- Bootstrap theory requires proper weight scaling