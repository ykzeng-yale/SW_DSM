# WDSM Bootstrap Implementation Verification for ATE/PATE

## Overview

This document verifies that our WDSM multinomial bootstrap implementation (`wdsm_method2_multinomial_bootstrap.R`) correctly handles Average Treatment Effect (ATE) estimation, specifically for Population ATE (PATE) under retrospective sampling.

## Key Requirements for ATE

For ATE estimation, we must re-estimate **ALL** components in each bootstrap iteration:
1. Propensity score e(X)
2. Prognostic score for control outcomes μ₀
3. Prognostic score for treated outcomes μ₁

This differs from ATT where technically only the prognostic score needs re-estimation.

## Implementation Verification

### 1. ✅ Propensity Score Re-estimation (Lines 126-136)

```r
# Re-estimate propensity score with bootstrap weights
cv_ps_star <- cv.glmnet(X, y, 
                        family = "binomial", 
                        weights = w_star * weights,  # Combine bootstrap and survey weights
                        alpha = 0,  # Ridge regression
                        nfolds = 10)
e_star <- predict(cv_ps_star, newx = X, s = "lambda.min", type = "response")[,1]
```

**Verification**: 
- ✅ Re-estimated in each bootstrap iteration
- ✅ Uses combined weights `w_star * weights` 
- ✅ Ridge regression for stability

### 2. ✅ Prognostic Score for Control (μ₀) Re-estimation (Lines 140-149)

```r
# Fit weighted regression for control units
idx0 <- which(A == 0)
prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                data = df_0, 
                weights = (w_star * weights)[idx0])
```

**Verification**: 
- ✅ Fitted only on control units (A=0)
- ✅ Uses combined bootstrap and survey weights
- ✅ Includes interaction term X1:X2

### 3. ✅ Prognostic Score for Treated (μ₁) Re-estimation (Lines 151-159)

```r
# Fit weighted regression for treated units  
idx1 <- which(A == 1)
prog1_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                data = df_1, 
                weights = (w_star * weights)[idx1])
```

**Verification**: 
- ✅ Fitted only on treated units (A=1)
- ✅ Uses combined bootstrap and survey weights
- ✅ Same model specification as control

### 4. ✅ Prediction for All Units (Lines 162-166)

```r
# Predict prognostic scores for all units
mu0_star <- predict(prog0_star, newdata = df_all)
mu1_star <- predict(prog1_star, newdata = df_all)
```

**Verification**: 
- ✅ Both μ₀ and μ₁ predicted for ALL units
- ✅ Necessary for ATE where both potential outcomes are needed

### 5. ✅ ATE Bootstrap Estimate Calculation (Lines 173-208)

```r
# Part 1: Estimated expectation of potential outcomes
tau_star <- tau_star + mean(w_star * weights * mu1_star) / mean(w_star * weights)
tau_star <- tau_star - mean(w_star * weights * mu0_star) / mean(w_star * weights)
```

**Verification**: 
- ✅ ATE = E[Y(1)] - E[Y(0)]
- ✅ Both μ₁ and μ₀ contribute to the estimate

### 6. ✅ Bias Correction Terms

**Control units contribute to E[Y(1)]**:
```r
if (A[i] == 0) {
  # Control unit: contributes to E[Y(1)]
  residual <- ... (Y[neighbors] - mu1_star[neighbors]) ...
}
```

**Treated units contribute to E[Y(0)]**:
```r
else {
  # Treated unit: contributes to E[Y(0)]
  residual <- ... (Y[neighbors] - mu0_star[neighbors]) ...
}
```

**Verification**: 
- ✅ Control units help estimate Y(1) through their treated neighbors
- ✅ Treated units help estimate Y(0) through their control neighbors
- ✅ Uses re-estimated μ₀_star and μ₁_star in residuals

## Key Differences from Unweighted Yang & Zhang

1. **Survey Weights**: Our implementation uses `w_star * weights` throughout, combining bootstrap weights with survey weights

2. **Ridge Regression**: We use ridge regression (glmnet with α=0) for propensity scores instead of standard logistic regression for stability

3. **Weight Normalization**: We normalize by `mean(w_star * weights)` instead of `n` to account for survey design

## Conclusion

✅ **The implementation correctly re-estimates ALL components** (propensity score, μ₀, and μ₁) in each bootstrap iteration, as required for ATE estimation.

✅ **Both potential outcomes are used** in the bootstrap estimate calculation, correctly implementing ATE = E[Y(1)] - E[Y(0)].

✅ **Survey weights are properly incorporated** throughout the bootstrap procedure.

The implementation follows Yang & Zhang (2020) theoretical framework while correctly adapting it for survey-weighted data in the retrospective sampling context.