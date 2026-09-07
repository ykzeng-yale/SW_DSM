# WDSM Update Summary: Switching to Multinomial Bootstrap

## Key Decision

Based on our comparison results, we have selected the **Multinomial Bootstrap** method as the preferred WDSM implementation for PATE estimation under retrospective sampling.

## Performance Comparison (10 replicates)

| Method | Coverage | Mean CI Width | Mean SE | Mean Time |
|--------|----------|---------------|---------|-----------|
| **Multinomial Bootstrap** | 100% | **0.189** | 0.050 | **42.2 sec** |
| Exponential Bootstrap | 100% | 0.242 | N/A | 60.1 sec |

**Advantages of Multinomial Bootstrap:**
- 22% narrower confidence intervals (0.189 vs 0.242)
- 30% faster computation (42.2 vs 60.1 seconds)
- Maintains perfect coverage
- Provides standard error estimates

## Updated Files

### 1. Main WDSM Implementation
- **File**: `wdsm_method2_multinomial_bootstrap.R`
- **Key Functions**:
  - `method2_multinomial_bootstrap_ci()` - Main bootstrap CI function
  - `compute_wdsm_method2_ci()` - Convenience wrapper

### 2. Comparison Script Updated
- **File**: `compare_methods_pate_retrospective.R`
- **Changes Made**:
  - Source file changed from `wdsm_method1_exponential_bootstrap.R` to `wdsm_method2_multinomial_bootstrap.R`
  - Function calls updated from `method1_exponential_bootstrap_ci` to `method2_multinomial_bootstrap_ci`
  - Result keys changed from `wdsm_method1` to `wdsm_multinomial`
  - Method name updated to "WDSM (Multinomial Bootstrap)"
  - Export list updated for parallel processing

## Usage Example

```r
# Load required functions
source("wdsm_method2_multinomial_bootstrap.R")
source("wdsm_ci_functions.R")

# Get point estimate
point_est <- wdsm_point_estimate(data, M = 5)

# Extract variables
Y <- data$Y
X <- as.matrix(data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
A <- data$A
w <- data$survey_weight

# Compute CI using multinomial bootstrap
ci_result <- method2_multinomial_bootstrap_ci(
  Y = Y, X = X, A = A, weights = w,
  point_estimate = point_est,
  B = 200,
  alpha = 0.05,
  use_bias_correction = TRUE,
  show_progress = TRUE
)
```

## Technical Details

### Multinomial Bootstrap Weights
- Uses `tabulate(sample(1:n, n, replace = TRUE), nbins = n)`
- Equivalent to multinomial(n, p=1/n for all units)
- Preserves the discrete nature of the resampling

### Key Features Maintained
- Ridge regression for propensity scores (glmnet with alpha=0)
- Weighted linear regression for prognostic scores
- Preserves matching structure (neighbor sets and reuse counts)
- Implements bias correction following Yang & Zhang (2020)

## Recommendation

Use `wdsm_method2_multinomial_bootstrap.R` for all future WDSM analyses requiring confidence intervals for PATE under retrospective sampling. The multinomial bootstrap provides better statistical efficiency while maintaining theoretical validity.