# Conditionally stabilized WDSM

Point-estimation implementation for Web Appendix A.9, using the shared
[`R/wdsm_core_final.R`](../R/wdsm_core_final.R) nuisance fits and matching rule.
The paper's simulations and case studies use the original WDSM estimator,
not this extension. No stabilized standard errors or confidence intervals
are implemented.

From the repository root:

```r
source("StabilizedWDSM/wdsm_stabilized.R")
fit <- wdsm_stabilized_point_estimate(
  data = dat,                 # Y, A (0/1), survey_weight, covariates
  ps_formula = A ~ X1 + X2,
  pg_formula = Y ~ X1 + X2,
  M = 5, estimand = "PATE",   # or "PATT"
  sampling_design = "retrospective"
)
fit$tau
```

The auxiliary conditional-weight regression is unweighted within each arm;
the outcome regression is survey-weighted. The default quadratic working
models are not the appendix's shrinking-bandwidth construction. Custom
conditional-weight predictions can be supplied through `rho_predictions`;
`wdsm_stabilized_from_fit()` also accepts supplied outcome predictions.
Required predictions must be positive and finite. The implementation stops
on failed fits rather than trimming weights or discarding observations.

The implementation requires only base R.
