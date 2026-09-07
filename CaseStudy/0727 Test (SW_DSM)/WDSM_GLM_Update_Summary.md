# WDSM Updated to Use Standard GLM Models

## Summary of Changes
We have updated the WDSM implementation to use standard GLM models instead of ridge regression for propensity score estimation. The prognostic score models remain as weighted linear models (`lm`).

## Files Modified

### 1. `wdsm_ci_functions.R`
- **Propensity Score**: Changed from `cv.glmnet` (ridge) to standard `glm`
- **Prognostic Score**: Remains as `lm` (no change)
- Removed `glmnet` library dependency

### 2. `wdsm_method2_multinomial_bootstrap.R`
- **Propensity Score**: Changed from `cv.glmnet` (ridge) to standard `glm`
- **Prognostic Score**: Remains as `lm` (no change)
- Removed `glmnet` library dependency

### 3. `compare_methods_pate_retrospective.R`
- Removed `glmnet` library loading
- Removed `glmnet` from parallel processing package list

## Model Specifications

### Before (Ridge Regression):
```r
# Propensity Score
cv_ps <- cv.glmnet(X, y, family = "binomial", 
                   weights = w, 
                   alpha = 0,  # Ridge regression
                   nfolds = 10)
e_score <- predict(cv_ps, newx = X, s = "lambda.min", type = "response")[,1]
```

### After (Standard GLM):
```r
# Propensity Score
ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                data = data,
                family = binomial(link = "logit"),
                weights = w)
e_score <- ps_model$fitted.values
```

### Prognostic Score (Unchanged):
```r
# For control units (A=0)
prog0_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = data[data$A == 0,],
                  weights = w[data$A == 0])

# For treated units (A=1)  
prog1_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                  data = data[data$A == 1,],
                  weights = w[data$A == 1])
```

## Updated Method Comparison

| Method | PS Model | PGS Model | Survey Weights |
|--------|----------|-----------|----------------|
| WDSM | **Standard GLM** | Standard LM | Yes |
| DSM Unweighted | Standard GLM | Standard LM | No |
| PG Unweighted | Standard GLM | Standard LM | No |
| PS Unweighted | Standard GLM | N/A | No |
| MatchIt SW | Ridge GLM | N/A | Yes |

## Key Differences from Before
1. **No Regularization**: WDSM now uses standard maximum likelihood estimation without ridge penalty
2. **Simpler Implementation**: No need for cross-validation or lambda selection
3. **Consistent with Baseline**: WDSM now uses the same model types as the unweighted methods
4. **Survey Weights**: Still incorporated in both PS and PGS estimation

## Expected Impact
- **Computation**: Faster (no cross-validation needed)
- **Stability**: May be less stable with high-dimensional covariates or near-separation
- **Comparability**: More directly comparable to unweighted methods

## Next Steps
Re-run the comparison simulation to evaluate the performance of WDSM with standard GLM models.