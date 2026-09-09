# WDSM Version 1 for PATT Prospective - Documentation

## Overview

This implementation provides the Version 1 methodology for Weight-Dependent Sample Matching (WDSM) to estimate the Population Average Treatment Effect on the Treated (PATT) under prospective survey designs.

## Key Features

### 1. Yang & Zhang Transformations
- **Logit transformation** of propensity scores: `logit(e) = log(e/(1-e))` to map (0,1) → ℝ
- **Standardization** of double scores to mean 0, variance 1
- Improves numerical stability and matching performance

### 2. Bias Correction for d=2 Matching
- Essential when matching on double scores (propensity + prognostic)
- Uses flexible polynomial regression: `Y ~ poly(S1, 2) + poly(S2, 2) + S1:S2`
- Estimates and corrects for systematic bias in matched comparisons

### 3. Bootstrap Variance Estimation
- **Multinomial weights**: `omega* = m*/n` where `m* ~ Multinomial(n, p_weights)`
- **Fixed μ₀ function**: Original bias correction function is held fixed during bootstrap
- **Linear approximation**: Uses theoretical linearization for computational efficiency

### 4. Model Specifications
- Automatically includes x1:x2 interaction term to match typical DGPs
- Survey-weighted estimation for both propensity and prognostic scores
- Handles complex survey designs with appropriate weighting

## Usage

```r
# Load required libraries
library(survey)
library(MASS)
library(mgcv)

# Source the function
source("WDSM/R/wdsm_patt_prospective_v1.R")

# Prepare your data with required columns:
# - X: covariate matrix (n x p)
# - A: treatment indicator (0/1)
# - Y: outcome variable
# - w: survey weights

# Run WDSM Version 1
result <- wdsm_patt_prospective_v1(
  sample = your_data,
  M = 3,        # Number of matches per treated unit
  B = 500,      # Bootstrap iterations
  show_progress = TRUE
)

# Access results
result$tau_hat      # Bias-corrected PATT estimate
result$SE           # Bootstrap standard error
result$CI_lower     # 95% CI lower bound
result$CI_upper     # 95% CI upper bound
result$bias_correction  # Magnitude of bias correction
```

## Output Structure

The function returns a list containing:
- `tau_hat`: Bias-corrected PATT estimate
- `SE`: Bootstrap standard error
- `CI_lower`, `CI_upper`: 95% confidence interval bounds
- `tau_boot`: Vector of all bootstrap replicates
- `bias_correction`: Magnitude of bias correction applied
- `initial_estimate`: Initial estimate before bias correction
- `matches`: List of matched control indices for each treated unit
- `K_M_w`: Weighted reuse factors for control units

## Key Differences from Version 2

1. **Bootstrap weights**: Version 1 uses multinomial weights (`m*/n`), Version 2 uses direct counts
2. **μ₀ function**: Version 1 keeps it fixed, Version 2 re-estimates in each bootstrap iteration
3. **Bootstrap formula**: Different theoretical linearizations

## Performance Characteristics

Based on simulations:
- Achieves nominal coverage rates (≈95%) when properly specified
- Bias correction is crucial for d=2 matching
- Standard errors are typically conservative
- Robust to moderate model misspecification

## References

Yang, S., & Zhang, Y. (2020). Multiply robust matching estimators of average and quantile treatment effects. *Scandinavian Journal of Statistics*.

## Files

1. **Main function**: `WDSM/R/wdsm_patt_prospective_v1.R`
2. **Test script**: `test_wdsm_patt_prospective_v1.R`
3. **This documentation**: `WDSM_Version1_Documentation.md`