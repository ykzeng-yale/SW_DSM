# Conditionally stabilized WDSM

## September 17 tie-corrected rerun

The estimator now uses the shared recipient-specific random tie rule in
`R/wdsm_ties.R`. The full Bouchet rerun completed all 32 cells and 1,000
replications per cell. An independent comparison of all 96,000 M-specific pairs
found exact equality for all 95,928 successful stabilized estimates and all
reference estimates; the same 72 positivity rejections and their reasons remain.
There were no allocation-relevant ties. Thus the tie correction does not change
the point-estimator conclusions below. See the
[full paired comparison](../audit/ties_20260917/stabilized_pairing/comparison_summary.txt).

The strict final pairing against the newly rerun main analysis has also passed.
The complete main raw-result comparison found exact equality of estimates, SEs,
interval endpoints, and saved bootstrap draws against the corrected September 9
run. All 96 stabilized summary rows and all 224 main summary rows are
[exactly unchanged](../audit/ties_20260917/metric_comparison_20260909_20260917.json).
Use the [September 17 publication index](../Results/Final_20260917/README.md),
[96-setting metrics](../Results/Final_20260917/stabilized/summary/stabilized_point_metrics.csv),
and [comparison tables/figures](../Results/Final_20260917/stabilized/performance).
The September 9 artifacts below remain the preserved baseline; the new raw-result
release archive is still being prepared.

The [manual manuscript guide](../audit/ties_20260917/MANUSCRIPT_GUIDANCE_20260917.md)
explains why this tie correction requires no further simulation numerical changes
relative to the corrected September 9 results, while the older paper's score/bootstrap
corrections remain necessary. This remains a point-estimator study, without stabilized
SEs, intervals, or coverage. See the current
[Bouchet execution record](../audit/ties_20260917/submitted_workflow.json).

This folder implements the **separate point-estimator extension** at the end of Section 3.3. It does not replace the original self-normalized WDSM estimator or change any existing simulation or case-study scripts.

## Source and scope

The implementation is based on the shared corrected **`R/wdsm_core_final.R`**, checked against main commit **`2f9f24e`** (September 9, 2026, merging the PATE/PATT corrections). It calls `wdsm_final_nuisance()` directly rather than maintaining another copy of the propensity-score solver or first-stage models. Consequently it uses the updated checked zero-initialization PS solver, probability-scale matching coordinates, arm-specific quadratic outcome regressions, and pooled unweighted standardization.

The matching loop uses the same squared Euclidean distances and recipient-specific randomized boundary-tie resolution (explicit independent tie seed) as `wdsm_final()`. A second interface reuses an existing original fit without refitting or rematching. Tests compare its original-estimator counterpart against the updated core on exactly the same synthetic data.

Only point estimates are implemented. **No standard errors, confidence intervals, coverage estimates, or stabilized-bootstrap validity are claimed.** The original estimator's replication routine must not be applied unchanged to the stabilized output.

## Algorithm change

For arm `z`, estimate two different conditional means on its own double score:

$$
m_z(d)=\frac{E[WY\mid Z=z,D_z=d,S=1]}{E[W\mid Z=z,D_z=d,S=1]},
\qquad
\rho_z(d)=E[W\mid Z=z,D_z=d,S=1].
$$

Here `W` is the observed individual's survey weight. Fit `m_z` using survey-weighted outcome regression, but fit `rho_z` by **unweighted regression of W**, separately within each treatment arm.

For an individual whose arm-`z` outcome is missing, replace the original within-match self-normalized residual average with

$$
\widetilde Y_i(z)=\widehat m_z(\widehat D_{z,i})+
\frac{1}{M}\sum_{j\in\mathcal J_z(i)}
\frac{W_j}{\widehat\rho_z(\widehat D_{z,j})}
\left\{Y_j-\widehat m_z(\widehat D_{z,j})\right\}.
$$

The denominator is evaluated at **matched individual j's score**. The stabilizer multiplies the **entire residual**. There is no additional normalization by the sum of stabilized weights in the matched set. Observed outcomes remain unchanged.

The outer averages are unchanged:

$$
\widetilde\tau_{\mathrm{PATE}}=
\frac{\sum_i W_i\{\widetilde Y_i(1)-\widetilde Y_i(0)\}}{\sum_i W_i},
\qquad
\widetilde\tau_{\mathrm{PATT}}=
\frac{\sum_{i:Z_i=1}W_i\{Y_i-\widetilde Y_i(0)\}}{\sum_{i:Z_i=1}W_i}.
$$

| Component | Retrospective | Prospective |
|---|---|---|
| PS regression | Survey weighted | Unweighted |
| First-stage prognostic regression | Unweighted within arm | Unweighted within arm |
| Matching | Unweighted Euclidean on standardized own double score | Same |
| Outcome regression `m_z` | Survey weighted within arm | Survey weighted within arm |
| Conditional-weight regression `rho_z` | **Unweighted** within arm | **Unweighted** within arm |
| Outer average | Original observed-arm survey weights | Original survey weights |

PATE fits both arms' models and matches in both directions. PATT only fits the control prognostic, control outcome, and control conditional-weight regressions. It requires neither a treated prognostic model nor a treated auxiliary outcome model.

## Use

Requires only R and its standard `stats` package. From the repository root:

```r
source("StabilizedWDSM/wdsm_stabilized.R")

fit <- wdsm_stabilized_point_estimate(
  data = dat,                         # Y, A (0/1), survey_weight, covariates
  ps_formula = A ~ X1 + X2 + X3 + X4 + X5 + X6,
  pg_formula = Y ~ X1 + X2 + X3 + X4 + X5 + X6,
  M = 5,
  estimand = "PATE",                  # or "PATT"
  sampling_design = "retrospective"  # or "prospective"
)

fit$tau                              # stabilized point estimate
fit$self_normalized_tau              # original BC formula, same fits/matches
fit$ps_diagnostics                   # updated core's numerical checks
```

The high-level function automatically locates the shared core relative to this file. If loading through a different mechanism, pass `core_file = "/path/to/SW_DSM/R/wdsm_core_final.R"` explicitly. The source file and core must remain from a compatible repository checkout.

### Reuse an updated original fit exactly

If the original analysis already calls `wdsm_final(..., keep_point = TRUE)`, reuse its saved models and match sets:

```r
# original <- wdsm_final(dat, ps_formula, pg_formula,
#                        estimand = "PATE", sampling_design = "retrospective",
#                        M = 5, keep_point = TRUE)
stabilized <- wdsm_stabilized_from_fit(original, data = dat)
```

This does not run a new bootstrap. `dat` must be the unchanged original data in the same row order. The adapter checks the reconstructed original point estimate, original reuse coefficients, and match-set size against the saved result. These checks detect practical inconsistencies but cannot certify row identity without saved row identifiers. It inherits the original estimand and rejects a conflicting one.

The adapter also accepts the corrected case-study `wdsm_adaptive()` point-fit format, which already contains `Y`, `A`, and `weights`. For that format, `data` is not needed and `estimand` defaults to PATE. An arbitrary legacy fit is not automatically converted: the supplied outcome predictions must refer to the supplied arm-specific matching variables.

## Conditional-weight regression

The default `rho_degree = 2` uses unweighted least squares on a full quadratic in the arm-specific standardized double score. The response is divided by the pooled mean survey weight for numerical conditioning and predictions are multiplied back to the original weight units. This is **not** an extra survey weighting step. For exactly constant weights within an arm, the fitted conditional mean is that constant.

All required conditional-weight predictions must be positive and finite. The function stops on nonpositive predictions, rank-deficient regressions, failed PS solves, missing values, or insufficient matches. It does not silently trim weights, clip predictions, remove observations, substitute an intercept-only regression, or drop failed simulation runs. The default polynomial model is a practical working specification, not a guarantee of correct specification.

For an alternative smoother or an oracle simulation, supply conditional-weight predictions:

```r
fit <- wdsm_stabilized_point_estimate(
  dat, ps_formula, pg_formula, M = 3, estimand = "PATE",
  rho_predictions = list("0" = rho0, "1" = rho1)
)
```

Each vector has length `n`, in the original data order. Only entries from its corresponding observed arm are used; other entries may be `NA`. PATT needs only `list("0" = rho0)`. These must estimate `E[W | Z=z,D_z,S=1]` on the **same scores**, not the mean survey weight in the fixed-M match set. The adapter is preferable for custom estimators fitted after inspecting saved scores.

The appendix's current feasible-consistency proof gives a particular shrinking-bandwidth ball-kernel construction for both auxiliary means. The default fixed quadratic regression in this folder is not that construction and is not automatically covered by that theorem. A growing-series/spline or kernel realization requires the corresponding approximation, positivity, and convergence conditions. To evaluate another realization without changing the matching algorithm, replace the saved fit's `mu0_bc`/`mu1_bc` predictions and supply its `rho_predictions` to the low-level adapter; do not present that changed fit as an unchanged official `wdsm_final` result.

## Diagnostics and comparisons

The result includes imputed outcomes, `rho0`/`rho1`, saved double scores, match lists, the stabilized incoming reuse coefficients `K`, and an algebraic imputation/reuse check `identity_error`. `local_stabilizer_mass` records the mean multiplier in each match set; it need not equal one. `K` is **not** the original self-normalized reuse coefficient and is not a validated bootstrap influence coefficient.

The point-estimation code is reproducible given the data, formulas, auxiliary predictions, and explicit tie seed. Matching uses an isolated random stream and restores the caller’s RNG state. Compare methods on the same generated sample and use `self_normalized_tau` for an exact same-fit, same-match comparison. Record failed fits explicitly in future Monte Carlo experiments rather than deleting them from the denominator.

Useful limiting checks are:

- Constant weights within an arm give `W/rho = 1` and recover the original equal-share correction on the same matches.
- At `M = 1`, the conditional stabilizer remains; it does not cancel like a within-match ratio.
- Multiplying **all** survey weights and supplied conditional-weight predictions by one positive constant leaves the point estimate unchanged, up to numerical fitting tolerance.
- Adding a constant to every outcome and its fitted conditional means leaves the effect contrast unchanged, because the whole residual is stabilized.

These numerical identities do not establish general consistency, double robustness, or asymptotic inference. Those depend on the stated identification, sampling, matching, and auxiliary-estimation conditions.

## Tests and synthetic example

```sh
Rscript StabilizedWDSM/tests/test_stabilized.R
Rscript StabilizedWDSM/examples/simulation_smoke.R
```

Tests include seeded comparisons to the updated original shared core, hand-calculated PATE/PATT imputations, M=1 behavior, constant-weight equivalence, weight-scale and outcome-shift checks, and malformed-input rejection. The example only checks execution of the four design/estimand combinations. It is not a reproduction of the paper's simulations or evidence of comparative performance. Neither command downloads case-study data or changes existing analysis results.

Verified on September 9, 2026 with R 4.4.3: **28 synthetic tests passed**, including both estimands and sampling designs at `M = 1, 3, 5`, using seed 2024. The shared-core reference uses two supplied all-one count vectors solely to expose its original point fit; these are not used for stabilized inference. All 12 combinations in the synthetic example also completed. Existing repository functions and analysis results were left unchanged.

## Preserved paired full-scale bias experiment (September 9, 2026)

The user requested a direct test of whether the new point estimator reduces relative bias. `Simulations/rerun_stabilized.R` preserves the corrected main simulation's populations, sampling implementation, seed 2025+replication, truth, model specification, and M=1/3/5. It compares original and stabilized point estimates using the same fitted models and match sets. There are 32 settings and 1,000 sampled data sets per setting (96,000 requested stabilized estimates). The original main simulation was run separately and paired during final verification.

`simulation_protocol.json` and `simulation_protocol.md` freeze the original experiment. `audit/execution.json` records its September 9 cluster jobs and status. The complete five-sample pilot passed all 32 settings and 480 paired estimates, with no failures or warnings and exact agreement with the saved corrected-original point estimates. Full production and strict paired finalization completed as Bouchet jobs **25698446** and **25698530**. See the [preserved September 9 study results](../Results/Final_20260909/README.md), [96-setting metrics](../Results/Final_20260909/stabilized/summary/stabilized_point_metrics.csv), and [comparison tables/figures](../Results/Final_20260909/stabilized/performance). Primary outcomes are signed/absolute relative bias and the reduction in absolute relative bias in percentage points. Empirical SD, RMSE, numerical failures, and weight-multiplier diagnostics are supporting outcomes. No stabilized causal-effect interval is computed.

The simulation adapter uses two supplied all-one identity vectors only to expose the official original point fit through its existing API; it discards their artificial variance/SE/interval fields. They are not bootstrap replicates. The estimator leaves the caller’s random stream unchanged; its separate tie stream is recorded in diagnostics. Genuine conditional-weight failures are retained; they are not replaced or silently excluded from the 1,000-run denominator.

Production outputs are finalized only after both this array and the corrected-main array finish; dependent Bouchet job **25698530** uses analysis source **f5eb6b7**. `Simulations/finalize_stabilized.sbatch` runs the strict paired summary followed by the guarded performance generator. The summary preserves all requested failures and verifies the original counterpart against every completed baseline record before releasing primary tables or figures.

The [complete production failure census](audit/production_failure_census_20260909.md) covers all32,000 sample analyses:95,928 stabilized estimates succeeded and72 were rejected by the positivity check, across24 estimand/sample/specification records. The rejected fits occur in four prospective PATE settings and one prospective PATT setting; they remain explicit failures from the frozen quadratic rho model. No clipping or fallback was introduced. The final audit subsequently matched all 96,000 original counterparts exactly. Primary performance is available for 81 settings; 15 retain missing primary stabilized metrics and explicit failures. Absolute relative bias improves in 28 of 81 available settings and RMSE in 11; the fixed quadratic rho version does not broadly resolve poor-overlap bias. The census records failures; the linked full comparison supplies the bias findings. The earlier [preliminary audit](audit/production_rho_rejections_20260909.md) is preserved.
