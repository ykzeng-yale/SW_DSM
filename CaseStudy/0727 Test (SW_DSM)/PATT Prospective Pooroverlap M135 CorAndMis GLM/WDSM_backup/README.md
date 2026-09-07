# wdsmatch: Weighted Double Score Matching for Survey Data

The `wdsmatch` R package implements weighted double score matching (WDSM) for causal inference with complex survey data. It extends the double score matching methodology to properly incorporate survey weights, enabling valid population-level causal inference.

## Overview

WDSM addresses the critical challenge of conducting causal inference when data comes from complex surveys with unequal sampling probabilities. The package provides:

- **Population Average Treatment Effect (PATE)** estimation
- **Population Average Treatment Effect on the Treated (PATT)** estimation
- Support for both **prospective** and **retrospective** sampling designs
- **Bootstrap variance estimation** that accounts for survey design complexity
- **Double robustness** properties - consistent when either propensity score or prognostic score model is correctly specified

## Key Features

1. **Survey Weight Integration**: Properly incorporates survey weights throughout the matching process
2. **Flexible Sampling Designs**: 
   - Prospective: weights depend only on covariates X
   - Retrospective: weights depend on both covariates X and treatment Z
3. **Multiple Matching Methods**: Compare double score, propensity score only, prognostic score only, and covariate matching
4. **Bias Correction**: Implements bias correction procedures for finite-sample performance
5. **Comprehensive Diagnostics**: Provides covariate balance assessment and bootstrap inference

## Installation

```r
# Install from local directory
devtools::install("path/to/WDSM")

# Load the package
library(wdsmatch)
```

## Basic Usage

```r
# Load example data
library(Matching)
data(lalonde)

# Prepare data
Y <- lalonde$re78  # Outcome
X <- as.matrix(lalonde[, c("age", "educ", "black", "hisp", "married", 
                           "nodegr", "re74", "re75")])
A <- lalonde$treat  # Treatment

# Example: PATE with prospective sampling
weights <- runif(length(Y), 0.5, 2)  # In practice, use actual survey weights

result <- wdsmatch(Y, X, A, weights,
                   estimand = "PATE",
                   sampling = "prospective",
                   method = "dsm",
                   varest = TRUE,
                   boots = 100)
print(result)

# Example: PATT with retrospective sampling
weights0 <- runif(length(Y), 0.5, 2)
weights1 <- runif(length(Y), 0.5, 2.5)
weights_retro <- list(weights0 = weights0, weights1 = weights1)

result_retro <- wdsmatch(Y, X, A, weights_retro,
                         estimand = "PATT",
                         sampling = "retrospective",
                         method = "dsm")
print(result_retro)
```

## Main Functions

### `wdsmatch()`
The main wrapper function for all WDSM estimation:

- **Arguments**:
  - `Y`: Outcome vector
  - `X`: Covariate matrix
  - `A`: Treatment indicator (0/1)
  - `weights`: Survey weights (vector for prospective, list/matrix for retrospective)
  - `estimand`: "PATE" or "PATT"
  - `sampling`: "prospective" or "retrospective"
  - `method`: "dsm", "ps", "pg", "cov", or "all"
  - Additional options for score models, matching parameters, variance estimation

### Specific Functions

- `wdsmatchPATE_prospective()`: PATE estimation under prospective sampling
- `wdsmatchPATE_retrospective()`: PATE estimation under retrospective sampling
- `wdsmatchPATT_prospective()`: PATT estimation under prospective sampling
- `wdsmatchPATT_retrospective()`: PATT estimation under retrospective sampling

## Theoretical Background

WDSM is based on the theoretical framework developed in "Weighted Double Score Matching for Causal Inference in Survey Observational Data". Key theoretical properties:

1. **Consistency**: √n-convergence rate under standard regularity conditions
2. **Double Robustness**: Consistent if either propensity score OR prognostic score model is correctly specified
3. **Efficiency**: Achieves semiparametric efficiency bound under correct model specification
4. **Valid Inference**: Bootstrap procedures provide valid confidence intervals accounting for all sources of uncertainty

## Examples

See the `examples/` directory for detailed examples including:
- Basic WDSM usage with LaLonde data
- Comparison of different matching methods
- Sensitivity analyses
- Simulation studies

## References

- Original double score matching: Yang, S. and Zhang, Y. (2020). "Multiply Robust Matching Estimators of Average and Quantile Treatment Effects"
- Survey weighting theory: Ridgeway et al. (2015), Zeng et al. (2025)
- Matching theory: Abadie & Imbens (2006, 2011, 2016)

## Authors

Developed based on the `dsmatch` package by Yunshu Zhang and Shu Yang, extended for survey data applications.

## License

GPL-3










