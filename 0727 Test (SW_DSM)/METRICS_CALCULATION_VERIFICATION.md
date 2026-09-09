# Metrics Calculation Verification

## Most Updated Scripts

### WDSM Scripts (All Identical Across Scenarios)
- **`wdsm_ci_functions.R`** - MD5: `493a58ecf48de05134b4a4c8f7997e92`
- **`wdsm_method2_multinomial_bootstrap.R`** - MD5: `5e03ac42bf855b39d78e7bfb94debb36`

These scripts are identical across all scenario folders (CorCor, MisCor, CorMis, MisMis) in the 1000rep CORRECTED versions, confirming consistent implementation.

### Comparison Script
- **`compare_methods_pate_retrospective_mccleary.R`** in each scenario folder
- Only difference between scenarios: the hardcoded `scenarios` variable
- All other logic is identical

## ✅ Metrics Calculation Verification

### Current Implementation (CORRECT)

```r
# For each method and scenario:
empirical_se = sd(estimates)           # Monte Carlo empirical standard error
mean_se = mean(ses)                    # Average of estimated SEs across reps
se_ratio = mean(ses) / sd(estimates)   # SE Ratio (efficiency of SE estimation)
```

### What We Calculate:

1. **Bias** = `mean(estimates) - true_pate`
   - Absolute bias of the point estimate

2. **Relative Bias** = `(mean(estimates) - true_pate) / abs(true_pate)`
   - Percentage bias relative to true effect

3. **Empirical SE** = `sd(estimates)`
   - Monte Carlo standard error from 1000 replications
   - This is the TRUE variability of the estimator

4. **Mean SE** = `mean(ses)`
   - Average of the standard errors estimated by each method
   - This is what the method THINKS its variability is

5. **SE Ratio** = `mean(ses) / sd(estimates)`
   - Ratio of estimated SE to empirical SE
   - **Ideal value = 1.0**
   - Values > 1: Conservative (overestimating uncertainty)
   - Values < 1: Anti-conservative (underestimating uncertainty)

6. **Coverage** = `mean(CI contains true_pate)`
   - Proportion of 95% CIs that contain the true PATE
   - **Ideal value = 95%**

## What About Relative Efficiency?

### Current Approach
We calculate **SE Ratio** for each method independently, which tells us:
- How well each method estimates its own standard error
- Whether the method's variance estimation is accurate

### Alternative: Relative Efficiency to Reference Method
If we wanted to compare efficiency relative to a baseline (e.g., PS Unweighted):

```r
# NOT currently implemented, but could be added:
relative_efficiency = var(ps_unweighted_estimates) / var(method_estimates)
# OR equivalently:
relative_efficiency = (empirical_se_ps_unweighted)^2 / (empirical_se_method)^2
```

This would tell us which method has lower variance (higher efficiency) relative to the baseline.

## Current Focus: SE Ratio is More Important

For our analysis, **SE Ratio** is the critical metric because:

1. **Statistical Validity**: A method with SE Ratio ≈ 1.0 provides accurate uncertainty quantification
2. **Coverage**: SE Ratio directly affects coverage probability
3. **Method Comparison**: We can see which methods correctly estimate their own uncertainty

## Example Interpretation

For WDSM in CorMis scenario (from 100-rep tong results):
- **Bias**: -0.004% (excellent, nearly unbiased)
- **SE Ratio**: 1.003 (excellent, accurate SE estimation)
- **Coverage**: 94.4% (excellent, close to nominal 95%)

This shows WDSM:
1. Provides unbiased estimates even with PGS misspecification
2. Correctly estimates its own uncertainty
3. Achieves nominal coverage

## Conclusion

✅ **YES, the calculations are correct:**
- We use Monte Carlo empirical variance (`sd(estimates)`) for each method
- SE Ratio correctly compares estimated SE to empirical SE
- This is the standard approach for simulation studies

The current implementation focuses on:
- **Bias** (accuracy of point estimates)
- **SE Ratio** (accuracy of uncertainty quantification)
- **Coverage** (practical performance of confidence intervals)

These are the most important metrics for evaluating matching methods in causal inference.


