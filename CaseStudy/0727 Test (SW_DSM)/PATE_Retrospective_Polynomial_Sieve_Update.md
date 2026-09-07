# WDSM Polynomial Sieve Method Update

## Summary
Updated our WDSM implementation to use the polynomial sieve method for bias correction, matching the approach used in the original dsmatch-master package.

## Changes Made

### 1. **wdsm_ci_functions.R** - Point Estimation
- Replaced simple neighbor-based bias correction with polynomial sieve method
- Added polynomial expansion of scores: `cbind(mu0, mu1, mu0^2, mu1^2, mu0*mu1, ps, ps^2, ps*mu0, ps*mu1, ps*mu0*mu1)`
- Fits weighted regression on these polynomial terms to get bias-corrected predictions

### 2. **wdsm_method2_multinomial_bootstrap.R** - Bootstrap Estimation
- Added polynomial sieve bias correction after re-estimating scores in each bootstrap iteration
- Uses the same polynomial expansion as point estimation
- Updates all residual calculations to use bias-corrected scores (`mu0_star_bc`, `mu1_star_bc`)

## Technical Details

### Previous Approach
```r
# Direct prognostic score fitting
prog0_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, ...)
```

### New Approach (Polynomial Sieve)
```r
# Step 1: Fit prognostic and propensity scores
mu0, mu1, ps <- ... (same as before)

# Step 2: Create polynomial expansion
sieve.vars <- cbind(mu0, mu1, mu0^2, mu1^2, mu0*mu1, 
                    ps, ps^2, ps*mu0, ps*mu1, ps*mu0*mu1)

# Step 3: Bias correction via regression on polynomial terms
bc1.fit <- lm(Y ~ sieve.vars, weights = w, subset = (A == 1))
mu1.bc <- cbind(1, sieve.vars) %*% bc1.fit$coefficients
```

## Benefits
1. **Consistency**: Matches the methodology used in dsmatch-master package
2. **Flexibility**: Polynomial expansion captures non-linear relationships between scores
3. **Survey Weights**: Properly incorporates survey weights in the bias correction step

## Files Updated
- `wdsm_ci_functions.R` (in main directory)
- `wdsm_method2_multinomial_bootstrap.R` (in main directory)
- `PATE Retrospective Goodoverlap M5 BothCorrect GLM/wdsm_ci_functions.R`
- `PATE Retrospective Goodoverlap M5 BothCorrect GLM/wdsm_method2_multinomial_bootstrap.R`

## Next Steps
The updated scripts are ready for submission to the server. No changes are needed to the submission scripts since we modified the existing files in place.