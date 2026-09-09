# WDSM Propensity Score Failure Analysis

## Executive Summary

The WDSM implementation is experiencing systematic propensity score model failure in the retrospective sampling design. **100% of samples** show GLM non-convergence, with many having all propensity scores collapse to essentially 0. Despite this, the Yang & Zhang transformations allow the matching to proceed and produce estimates, but the fundamental instability remains.

## Key Findings

### 1. Systematic GLM Failure
- **100% failure rate** across all tested samples
- GLM warnings: "algorithm did not converge", "fitted probabilities numerically 0 or 1"
- In ~31% of samples, all propensity scores = 2.22e-16 (machine epsilon)

### 2. Impact on Estimates
- Point estimates vary wildly: from -2.28 to 2.19 (true = 0.866)
- Bootstrap standard errors severely underestimated: ~0.054 vs empirical SD ~1.09
- Coverage drops to 65% (nominal 95%)

### 3. Yang & Zhang Transformations Help But Don't Solve
- The logit transformation and standardization allow matching to proceed
- However, when all propensity scores are identical (e.g., all 0), the propensity component of the double score provides no information
- The matching essentially becomes based only on prognostic scores

## Root Cause Analysis

### Why GLM Fails in Retrospective Sampling

1. **Selection Bias**: Retrospective sampling with treatment-dependent selection creates extreme covariate imbalance
2. **Complete Separation**: Some covariate patterns perfectly predict treatment in the weighted sample
3. **Survey Weights**: The combination of survey weights and separation exacerbates numerical instability

### Mathematical Insight

When fitting:
```
glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
    family = binomial, weights = survey_weight)
```

The weighted likelihood can have no finite maximum when certain weighted covariate patterns perfectly separate treatment groups.

## Recommended Solutions

### 1. **Regularized Propensity Score Estimation** (Recommended)
Replace standard GLM with penalized regression:
```R
library(glmnet)
# Use ridge or elastic net penalty
ps_model <- cv.glmnet(X, A, family = "binomial", 
                      weights = survey_weight,
                      alpha = 0.5)  # elastic net
e_score <- predict(ps_model, X, type = "response")
```

### 2. **Simplified Model Specification**
Remove interaction term that may cause separation:
```R
# Instead of: A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
# Use: A ~ X1 + X2 + X3 + X4 + X5 + X6
```

### 3. **Bayesian Propensity Score Estimation**
Use weakly informative priors to prevent extreme coefficients:
```R
library(rstanarm)
ps_model <- stan_glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     family = binomial(),
                     weights = survey_weight,
                     prior = normal(0, 2.5),
                     data = data)
```

### 4. **Propensity Score Truncation**
Enforce minimum overlap:
```R
e_score <- pmax(pmin(e_score, 0.95), 0.05)
```

### 5. **Alternative Estimation Methods**
- Gradient boosting (e.g., `xgboost`) with early stopping
- Random forests with probabilistic predictions
- Generalized additive models (GAMs) with smoothing

## Implementation Priority

1. **Immediate Fix**: Add regularization to propensity score model
2. **Short-term**: Implement propensity score truncation and model simplification
3. **Long-term**: Compare multiple propensity score estimation methods

## Validation Approach

After implementing fixes:
1. Check propensity score distribution (should have reasonable variance)
2. Verify no convergence warnings
3. Assess overlap between treatment groups
4. Run simulation to confirm improved coverage

## Conclusion

The current implementation's reliance on unregularized GLM for propensity scores is incompatible with the retrospective sampling design. The systematic failure of propensity score estimation explains all observed issues: extreme point estimates, underestimated variance, and poor coverage. Implementing regularized estimation should resolve these problems. 