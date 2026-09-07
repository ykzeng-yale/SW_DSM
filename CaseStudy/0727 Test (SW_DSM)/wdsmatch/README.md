# wdsmatch: Weighted Double Score Matching for Survey-Weighted Causal Inference

Implements weighted double score matching (WDSM) for estimating causal effects from survey-weighted observational data. Matches units on both propensity scores and prognostic scores incorporating survey design weights, with polynomial sieve bias correction and linearization-based multinomial bootstrap variance estimation.

## Installation

```r
# From GitHub:
remotes::install_github("ykzeng-yale/wdsmatch")
```

## Usage

```r
library(wdsmatch)
data(survey_obs)

# Estimate PATE (Population Average Treatment Effect)
fit_ate <- wdsmatchATE(
  Y = survey_obs$Y,
  X = survey_obs[, c("X1","X2","X3","X4","X5","X6")],
  Z = survey_obs$Z,
  weights = survey_obs$survey_weight,
  M = 5,
  model.ps = Z ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  model.pg = Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  sampling = "retrospective",
  varest = TRUE, boots = 200
)
fit_ate

# Estimate PATT (Population Average Treatment Effect on the Treated)
fit_att <- wdsmatchATT(
  Y = survey_obs$Y,
  X = survey_obs[, c("X1","X2","X3","X4","X5","X6")],
  Z = survey_obs$Z,
  weights = survey_obs$survey_weight,
  M = 5,
  sampling = "retrospective",
  varest = TRUE, boots = 200
)
fit_att
```

## Key Features

- **Double robustness**: Consistent when either the propensity score or prognostic score model is correctly specified
- **Survey weight integration**: Proper incorporation of survey design weights throughout score estimation, matching, and inference
- **Flexible sampling designs**: Supports both retrospective (treatment-dependent) and prospective (treatment-independent) sampling
- **Polynomial sieve bias correction**: 10-term basis for improved finite-sample performance
- **Linearization-based bootstrap**: Computationally efficient variance estimation preserving the survey-weighted matching structure

## References

Zeng, Y., Tong, G., Tong, J., Lu, H., Mukherjee, B., and Li, F. (2026). Where to weight? Estimating population causal effects with weighted double score matching in complex surveys. *Manuscript under review*.

## License

GPL-3
