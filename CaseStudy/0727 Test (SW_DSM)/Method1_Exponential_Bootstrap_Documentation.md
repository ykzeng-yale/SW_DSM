# WDSM Method 1: Exponential Bootstrap CI Module

## Overview

This module provides a reusable implementation of Method 1 (Exponential Bootstrap) for computing confidence intervals in Weighted Distance-based Sample Matching (WDSM) for Population Average Treatment Effect (PATE) estimation under retrospective sampling.

## Key Features

- **Exponential Bootstrap Weights**: Uses exponential random weights for bootstrap resampling
- **Bias Correction**: Optional bias correction following Yang & Zhang (2020)
- **Stable Estimation**: Uses ridge regression via glmnet for stable propensity score estimation
- **Progress Tracking**: Optional progress bar for long-running simulations
- **Modular Design**: Easy to integrate into existing simulation studies

## Files

1. **`wdsm_method1_exponential_bootstrap.R`** - Main module file
2. **`example_using_method1.R`** - Example usage scripts
3. **`Method1_Exponential_Bootstrap_Documentation.md`** - This documentation

## Usage

### Basic Usage

```r
# Source the module
source("wdsm_method1_exponential_bootstrap.R")

# Assuming you have:
# - sample_data: data frame with columns A, Y, X1-X6, survey_weight
# - point_estimate: results from wdsm_point_estimate()

# Compute CI
ci_results <- method1_exponential_bootstrap_ci(
  data = sample_data,
  point_estimate = point_estimate,
  M = 3,              # Number of neighbors
  B = 200,            # Bootstrap iterations
  alpha = 0.05,       # Significance level
  use_bias_correction = TRUE
)

# Access results
print(ci_results$tau_hat)    # Point estimate
print(ci_results$se)          # Standard error
print(ci_results$ci_lower)    # Lower CI bound
print(ci_results$ci_upper)    # Upper CI bound
```

### Using the Wrapper Function

```r
# The wrapper handles both point estimation and CI calculation
results <- compute_wdsm_method1_ci(
  data = sample_data,
  wdsm_point_estimate_func = wdsm_point_estimate,
  M = 3,
  B = 200,
  alpha = 0.05,
  use_bias_correction = TRUE
)

# Access combined results
results$combined$tau_hat
results$combined$ci_lower
results$combined$ci_upper
results$combined$ci_width
```

## Function Parameters

### `method1_exponential_bootstrap_ci()`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `data` | data.frame | Required | Sample data with columns: A, Y, X1-X6, survey_weight |
| `point_estimate` | list | Required | WDSM point estimate results |
| `M` | integer | 3 | Number of neighbors for matching |
| `B` | integer | 200 | Number of bootstrap iterations |
| `alpha` | numeric | 0.05 | Significance level for CI |
| `use_bias_correction` | logical | FALSE | Whether to apply bias correction |
| `show_progress_bar` | logical | TRUE | Whether to display progress |

### Return Value

A list containing:
- `tau_hat`: Point estimate
- `se`: Bootstrap standard error
- `ci_lower`: Lower confidence interval bound
- `ci_upper`: Upper confidence interval bound
- `tau_star`: Vector of bootstrap estimates

## Integration with Simulations

### Sequential Processing

```r
# Run simulation
n_sim <- 1000
results <- data.frame()

for (sim in 1:n_sim) {
  # Sample data
  sample_data <- retrospective_sample(population, n_sample = 1000)
  
  # Point estimate
  point_est <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
  
  # CI using Method 1
  ci_results <- method1_exponential_bootstrap_ci(
    data = sample_data,
    point_estimate = point_est,
    M = 3,
    B = 200,
    use_bias_correction = TRUE,
    show_progress_bar = FALSE  # Turn off for simulation
  )
  
  # Store results
  results <- rbind(results, data.frame(
    sim = sim,
    tau_hat = ci_results$tau_hat,
    se = ci_results$se,
    ci_lower = ci_results$ci_lower,
    ci_upper = ci_results$ci_upper
  ))
}
```

### Parallel Processing

```r
library(parallel)
library(doParallel)

# Set up cluster
cl <- makeCluster(detectCores() - 1)
registerDoParallel(cl)

# Export necessary functions
clusterExport(cl, c("method1_exponential_bootstrap_ci", 
                    "wdsm_point_estimate",
                    "retrospective_sample",
                    # ... other required functions
                    ))

# Run parallel simulation
results <- foreach(sim = 1:n_sim, .combine = rbind,
                  .packages = c("MASS", "glmnet", "dplyr")) %dopar% {
  # Simulation code here
}

stopCluster(cl)
```

## Technical Details

### Bootstrap Weight Generation

The method uses exponential weights:
```r
xi_star <- rexp(n, rate = 1)
omega_star <- xi_star / mean(xi_star)
w_star <- omega_star * w  # w = survey weights
```

### Linearization

The bootstrap estimates are based on the linearization:
- Without bias correction: Standard WDSM linearization
- With bias correction: Includes bias correction terms based on prognostic score differences

### Confidence Interval Construction

Uses normal approximation:
```
CI = [tau_hat - z_(1-α/2) * SE_boot, tau_hat + z_(1-α/2) * SE_boot]
```

## Dependencies

Required R packages:
- `MASS`
- `mvtnorm`
- `glmnet`
- `dplyr`

## References

Yang, S., & Zhang, Y. (2020). Multiply robust matching estimators of average and quantile treatment effects. *Scandinavian Journal of Statistics*.

## Troubleshooting

1. **Missing packages**: The module will check for required packages and provide clear error messages if any are missing.

2. **Memory issues**: For large datasets or many bootstrap iterations, consider:
   - Reducing B (bootstrap iterations)
   - Using parallel processing
   - Increasing available memory

3. **Convergence warnings**: These typically come from glmnet during propensity score estimation. The ridge regression approach (alpha=0) helps stabilize estimation.

## Version History

- v1.0: Initial release with basic exponential bootstrap functionality
- v1.1: Added bias correction option
- v1.2: Improved stability with ridge regression for propensity scores