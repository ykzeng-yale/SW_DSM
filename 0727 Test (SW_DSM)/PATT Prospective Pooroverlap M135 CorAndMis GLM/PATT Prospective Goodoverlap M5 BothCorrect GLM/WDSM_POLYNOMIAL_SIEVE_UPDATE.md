# WDSM Polynomial Sieve Update Summary

## Critical Changes Made (August 4, 2025)

### 1. **Polynomial Sieve Method for Bias Correction**
- **Changed from**: Simple linear model `Y ~ s1 + s2 + s1:s2`
- **Changed to**: Polynomial sieve `Y ~ mu0 + mu0^2 + ps + ps^2 + ps*mu0`
- **Reason**: Aligns with dsmatch-master methodology, provides more flexible approximation

### 2. **Re-fitting Polynomial Sieve in Bootstrap** (CRITICAL FIX)
Based on insights from PATT retrospective analysis:

#### Previous (INCORRECT) Implementation:
```r
# Used FIXED mu0_model from initial estimation
mu0_star <- predict(mu0_model, newdata = predict_data_boot)
```

#### New (CORRECT) Implementation:
```r
# Re-fit polynomial sieve model with bootstrap weights
mu0_model_b <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, data = lm_data_b,
                  weights = w_b[relevant_controls_b] * K_M_w[relevant_controls_b])
mu0_star <- predict(mu0_model_b, newdata = predict_data_boot)
```

### 3. **Complete Re-estimation in Bootstrap**
Now correctly re-estimates ALL components in each bootstrap iteration:
- ✅ PS model re-estimated with bootstrap weights
- ✅ PG model re-estimated with bootstrap weights  
- ✅ Polynomial sieve re-fitted with bootstrap weights

## Impact on Results

### Before Update (Server Run):
- **370/1000 bootstrap failures** (37% failure rate)
- Convergence issues with quasibinomial GLM

### After Update (Local Tests):
- **0 bootstrap failures** in all tests
- More stable estimation process
- Correctly captures all sources of uncertainty

## Key Insight from PATT Retrospective
dsmatch-master does NOT use fixed models in bootstrap. They perform complete re-estimation of all components, ensuring proper variance estimation that accounts for all sources of uncertainty.

## Files Updated
1. `WDSM/R/wdsm_patt_prospective_v1_simplified.R`
2. `PATT Prospective Goodoverlap M5 BothCorrect GLM/WDSM/R/wdsm_patt_prospective_v1_simplified.R`

## Note on Standard Errors
The standard errors may be larger with the correct implementation because it properly accounts for the uncertainty in estimating the polynomial sieve model. This is the statistically correct approach.

## Additional Update: Weighted Standardization (August 4, 2025)

### 4. **Weighted Standardization for Double Scores**
Based on the retrospective WDSM implementation, we now use weighted standardization:

```r
# Previous (unweighted):
S_mean <- colMeans(S)
S_sd <- apply(S, 2, sd)

# New (weighted):
S_mean <- colSums(weights * S) / sum(weights)
S_sd <- sqrt(colSums(weights * (S - S_mean)^2) / sum(weights))
```

This ensures proper handling of survey weights in the matching distance calculation, making the implementation more theoretically sound for survey-weighted data.