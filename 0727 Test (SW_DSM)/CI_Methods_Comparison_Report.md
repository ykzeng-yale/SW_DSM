# Comparison of Two CI Methods for WDSM PATE Under Retrospective Sampling

## Executive Summary

This report compares two different methods for calculating 95% confidence intervals for the Weighted Double Score Matching (WDSM) estimator of the Population Average Treatment Effect (PATE) under retrospective sampling with survey weights.

## Methods Compared

### Method 1: Exponential Bootstrap
- Uses exponential weights (ξᵢ* ~ Exponential(1))
- Pre-computes weighted matching frequencies K₀ʷ(i) and K₁ʷ(i)
- Re-estimates scores with bootstrap weights
- Uses linear representation for bootstrap replicate calculation
- Simplified version for dimension 2 (no bias correction needed)

### Method 2: Survey Bootstrap  
- Uses two-stage survey bootstrap
- Pre-computes fixed survey-weighted reuse count
- Uses bootstrap weights from sampling with replacement
- Re-estimates nuisance parameters
- Uses linearized form with local regression

## Simulation Setup

- **Population Size**: 1,000,000
- **True PATE**: 0.8664
- **Sample Size**: ~1,000 (retrospective sampling)
- **Number of Simulations**: 10
- **Bootstrap Iterations**: B = 5 (small scale test)
- **Matching Count**: M = 3
- **Covariates**: 6 covariates (X1-X6) with interaction X1:X2

## Key Findings

### 1. Point Estimates
- **Both methods produce identical point estimates** (max difference < 1e-10)
- Mean estimate: 0.8437 (bias = -0.0227)
- Standard deviation of estimates: 0.0683

### 2. Standard Errors
- **Method 1 (Exponential Bootstrap)**: Mean SE = 0.1008
- **Method 2 (Survey Bootstrap)**: Mean SE = 0.1046
- **Difference**: Method 2 produces slightly larger SEs (+0.0038 or +3.8%)

### 3. Confidence Interval Widths
- **Method 1**: Mean CI width = 0.3952
- **Method 2**: Mean CI width = 0.4099
- **Difference**: Method 2 produces wider CIs (+0.0147 or +3.7%)

### 4. Coverage Rates
- **Both methods achieved 100% coverage** (10/10 simulations)
- Note: With only 10 simulations, this is not conclusive

### 5. Computational Differences
Both methods have similar computational complexity:
- Pre-computation of matching frequencies
- Bootstrap re-estimation of nuisance parameters
- Similar runtime performance

## Implementation Details

### Common Features
1. Both methods correctly handle survey weights in all estimation steps
2. Both use the same WDSM point estimation procedure
3. Both pre-compute and fix the matching structure
4. Both use normal approximation for CI construction

### Key Differences
1. **Bootstrap weight generation**:
   - Method 1: Exponential(1) weights normalized by mean
   - Method 2: Resampling with replacement

2. **Variance estimation philosophy**:
   - Method 1: Based on linear representation theory
   - Method 2: Based on survey bootstrap principles

## Recommendations

1. **Both methods appear valid** for variance estimation of WDSM under retrospective sampling

2. **Method 2 (Survey Bootstrap) may be slightly more conservative** due to larger standard errors

3. **For production use**:
   - Increase bootstrap iterations to B ≥ 1000
   - Run more simulations (n_sim ≥ 500) for reliable coverage assessment
   - Consider computational efficiency if processing large datasets

4. **Choice between methods** may depend on:
   - Theoretical preferences (survey statistics vs. general bootstrap)
   - Computational considerations
   - Consistency with other analyses in the project

## Code Availability

All code for this comparison is available in:
- `compare_wdsm_ci_methods.R`: Main comparison script
- `analyze_ci_methods_comparison.R`: Analysis and visualization
- `wdsm_ci_methods_comparison_results.RData`: Saved results

## Next Steps

1. Run larger-scale simulation with B = 1000 and n_sim = 500
2. Test under different scenarios (poor overlap, model misspecification)
3. Compare computational efficiency at scale
4. Validate theoretical properties through mathematical analysis 