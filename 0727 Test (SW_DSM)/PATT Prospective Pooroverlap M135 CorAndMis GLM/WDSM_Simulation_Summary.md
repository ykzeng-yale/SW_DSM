# WDSM Simulation with SW_PSW Design - Summary

## Overview
This document summarizes the simulation study testing the Weighted Double Score Matching (WDSM) method using the survey weighted simulation design from the SW_PSW-main folder.

## Simulation Setup

### Super Population Generation
- Population size: N = 1,000,000
- Sample size: n = 5,000 (0.5% of population)
- Number of covariates: 6 (plus interaction term)
- Structure: 10 strata × 20 clusters per stratum
- Good overlap scenario with logistic propensity score model

### True Population Parameters
- **ATE (Population Average Treatment Effect)**: 1.155
- **ATT (Average Treatment Effect on Treated)**: 1.291
- **ATO (Average Treatment Effect on Overlap)**: 1.215

### Sampling Designs Tested

#### 1. Prospective Sampling (Multi-stage)
- Independent of treatment assignment
- Multi-stage sampling: stratified → cluster → individual
- Survey weights: w_i = 1/P(S_i = 1 | X_i)

#### 2. Retrospective Sampling (Treatment-dependent)
- Sampling probability depends on treatment status
- P(S = 1 | X, Z) with different probabilities for treated/control
- Survey weights: w_{z,i} = 1/P(S_i = 1 | X_i, Z_i = z)

## Methods Compared

### WDSM (Weighted Double Score Matching)
- Uses both propensity score and prognostic score
- Incorporates survey weights in estimation
- Bias correction applied
- M = 3 matches per unit

### PSW (Propensity Score Weighting) 
- Traditional survey-weighted propensity score method
- From SW_PSW-main EstSOD function
- Used as benchmark comparison

## Preliminary Results (5 replications)

### Prospective Sampling
- **WDSM PATE**: Relative bias = -0.69%, RMSE = 0.075
- **WDSM PATT**: Relative bias = -0.96%, RMSE = 0.074
- **PSW PATE**: Relative bias = -1.35%, RMSE = 0.100
- **PSW PATT**: Relative bias = -2.89%, RMSE = 0.094

### Retrospective Sampling
- Results pending from full simulation

## Full Simulation Status
- Running 100 replications
- Using 4 cores for parallel processing
- Started: [timestamp]
- Expected completion: ~20-30 minutes

## Key Findings (Preliminary)
1. WDSM shows lower relative bias than PSW for both PATE and PATT
2. WDSM has smaller RMSE compared to PSW
3. Both methods perform well with relative bias < 3%
4. Some replications fail due to small sample sizes in certain strata/clusters

## Next Steps
1. Complete full simulation with 100 replications
2. Calculate 95% confidence interval coverage
3. Assess performance under both prospective and retrospective sampling
4. Compare with other methods (MOM, CVR, WET) if needed 