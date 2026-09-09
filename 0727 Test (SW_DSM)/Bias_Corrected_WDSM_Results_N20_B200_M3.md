# Bias-Corrected WDSM Simulation Results

## Simulation Parameters
- Number of simulations: 20
- Sample size: 5,000
- Bootstrap iterations: 200
- Number of neighbors (M): 3
- Distance metric: Unweighted Euclidean
- Bias correction: **ENABLED**
- Parallel processing: 5 cores

## Results Summary

### True PATE
- Population PATE: 0.8664

### Method Comparison

| Method | Mean Estimate | Bias | SD | Mean SE | Coverage | Mean CI Width |
|--------|--------------|------|----|---------|-----------|--------------| 
| Method 1: Exponential Bootstrap | 0.565 | -0.301 | 1.09 | 0.0535 | 65.0% | 0.210 |
| Method 2: Survey Bootstrap | 0.565 | -0.301 | 1.09 | 0.0537 | 65.0% | 0.210 |

### Key Findings

1. **Identical Results**: Both methods produce virtually identical results, suggesting the bias correction is implemented consistently.

2. **Low Coverage**: The 65% coverage is significantly below the nominal 95% level, indicating that:
   - The standard errors are underestimated (mean SE ≈ 0.054 vs empirical SD ≈ 1.09)
   - The confidence intervals are too narrow

3. **Substantial Bias**: The bias of -0.301 represents a relative bias of -34.7%, which is quite large despite bias correction.

4. **Extreme Outliers**: Several simulations produced extreme estimates:
   - Simulation 3: -2.28 (2.64 SDs below true value)
   - Simulation 12: -1.99 (2.30 SDs below true value)
   - Simulation 14: -1.25 (1.44 SDs below true value)
   - Simulation 19: 2.19 (2.53 SDs above true value)

### Potential Issues

1. **Bootstrap Variance Underestimation**: The bootstrap standard errors (≈0.054) are about 20 times smaller than the empirical standard deviation (≈1.09).

2. **Finite Sample Issues**: With a sample size of 5,000 and some extreme sampling variability, the asymptotic approximations may not hold well.

3. **Bias Correction Implementation**: While bias correction is enabled, it may not be fully addressing the matching bias in finite samples.

### Recommendations

1. Investigate the bootstrap variance calculation - there may be an issue with how the bootstrap replicates are being computed or aggregated.

2. Consider increasing the number of bootstrap iterations (though 200 should be sufficient).

3. Debug the extreme outlier cases to understand what's causing such variable estimates.

4. Verify the bias correction implementation is working as intended by checking intermediate calculations. 