# Current WDSM Function Script Used in 1000 Replication Jobs

## Script Information
- **File**: `wdsm_patt_v2_standard.R`
- **Location**: `PATT Retrospective Goodoverlap M5 BothCorrect GLM/`
- **Version**: V2 Standard GLM/LM (Survey-Weighted)
- **Last Updated**: 2025-01-28

## Key Features Implemented

### 1. Survey-Weighted GLM for Propensity Score
- Uses `quasibinomial(link = "logit")` family (line 41)
- Correctly handles survey weights in GLM estimation
- Includes x1:x2 interaction term (lines 23-24)

### 2. Survey-Weighted LM for Prognostic Score  
- Standard linear model with survey weights
- Includes x1:x2 interaction term (line 135)
- No regularization (pure LM, not Ridge)

### 3. Polynomial Sieve Method for Bias Correction
- Implements polynomial sieve following dsmatch-master approach (lines 154-172)
- Model: `Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0`
- Uses sieve-based predictions (`mu_0_at_S`) instead of simple prognostic scores

### 4. Bootstrap with Full Re-estimation
- Re-estimates propensity score in each bootstrap iteration (line 253)
- Re-estimates prognostic score in each bootstrap iteration (line 276) 
- Re-estimates polynomial sieve model in each bootstrap iteration (`mu_0_model_b`, line 297)
- Correctly applies combined weights: bootstrap weights × survey weights

### 5. Correct Weight Handling
- Main estimation: Uses survey weights directly
- Bootstrap: Combines multinomial weights with survey weights (`m_star * weights`)
- No pre-normalization in the function (expects raw or normalized weights as input)

## Usage in Comparison Scripts

### Server Script (`compare_methods_patt_retrospective_mccleary.R`)
```r
# Line 53
source("wdsm_patt_v2_standard.R")

# Line 347-352 (in differential normalization experiment)
wdsm_result <- wdsm_patt_v2_standard(
  Y = Y, 
  X = X, 
  A = A, 
  weights = w_raw,  # Uses raw (unnormalized) weights
  B = 200,
  show_progress = FALSE
)
```

### Local Script (`compare_methods_patt_retrospective_local.R`)
```r
# Line 41
source("wdsm_patt_v2_standard.R")
```

## Key Improvements from Previous Versions

1. **Fixed PS Model**: Changed from `binomial` to `quasibinomial` for survey weights
2. **Added PGS Interaction**: Included x1:x2 interaction in prognostic score model
3. **Replaced loess**: Changed from `loess` to polynomial sieve for mu_0 approximation
4. **Fixed Bootstrap**: Ensures re-estimation of all models in each bootstrap iteration
5. **Corrected Bias Term**: Uses sieve-based predictions for bias correction
6. **Proper Weight Specification**: Explicitly uses `sieve_data$weights` in lm() calls

## Performance Characteristics

With 1000 replications (Job 57225723):
- **Relative Bias**: -0.800%
- **Coverage**: 0.938 (93.8%)
- **Relative Efficiency**: 2.705× (vs PS baseline)
- **SE Ratio**: 0.978 (closest to 1.0)
- **RMSE**: 0.051 (lowest among all methods)

## Notes

- This script expects raw survey weights (1/Prob) and handles them internally
- The polynomial sieve method aligns with dsmatch-master's theoretical approach
- All improvements ensure consistency with the theoretical framework of WDSM for PATT retrospective sampling
