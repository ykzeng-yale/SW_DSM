# Polynomial Sieve Weights Analysis

## How Weights are Handled in Our Implementation

### 1. **Point Estimation** (`wdsm_ci_functions.R`)
```r
# For control units (mu0)
bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
              data = ...[A == 0],
              weights = w[A == 0])  # Survey weights only

# For treated units (mu1)  
bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
              data = ...[A == 1],
              weights = w[A == 1])  # Survey weights only
```

### 2. **Bootstrap** (`wdsm_method2_multinomial_bootstrap.R`)
```r
# For control units (mu0)
bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
              data = ...[A == 0],
              weights = (w_star * weights)[A == 0])  # Combined weights

# For treated units (mu1)
bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
              data = ...[A == 1],
              weights = (w_star * weights)[A == 1])  # Combined weights
```

## Weight Handling Summary

### Main Estimation
- Uses **survey weights only** (`w`)
- Applied separately to control and treated units

### Bootstrap Iterations
- Uses **combined weights**: `w_star * weights`
- `w_star`: Bootstrap resampling weights (multinomial)
- `weights`: Original survey weights
- This ensures both bootstrap uncertainty and survey design are accounted for

## Comparison with dsmatch-master

The original `dsmatch-master` package doesn't appear to use weights in their polynomial sieve regressions:
```r
# dsmatch-master (no weights specified)
lm.out1 <- lm(lm.y[which(A == 1)] ~ lm.x[which(A == 1), ])
lm.out0 <- lm(lm.y[which(A == 0)] ~ lm.x[which(A == 0), ])
```

This is likely because:
1. They assume equal weights (simple random sampling)
2. Their bootstrap already accounts for weighting through data resampling

## Our Approach is Correct

For retrospective sampling with survey weights:
1. ✅ Main estimation uses survey weights
2. ✅ Bootstrap combines survey and bootstrap weights
3. ✅ Separate models for treated/control maintain proper weighting

This ensures the polynomial sieve bias correction properly accounts for the sampling design.