# Case study analyses

## Verified implementation update — September 2026

These results were rerun from patched copies of the original functions with seed **2024**, **B=200**, and Wald intervals. They supersede the earlier README tables. These functions do not use a replacement implementation from the wdsmatch package.

### NSDUH

Original sample: 17,471 adults aged 18–29 (1,877 treated). Prospective WDSM uses unweighted first-stage propensity and prognostic fits, survey-weighted imputation/correction, and an outer Hájek average.

| Outcome | M | Estimate (risk difference) | 95% CI |
|---|---:|---:|---|
| AMIPY | 5 | 0.065414 | [-0.004752, 0.135581] |
| SMIPY | 5 | 0.018153 | [-0.016620, 0.052926] |

### NHANES

Saved sample: 3,793 adults aged 40–70 from **2015–2018**, after excluding reported diagnosed diabetes. Retrospective WDSM uses weighted propensity fits and unweighted prognostic fits. All methods in the primary comparison use seven covariates, including smoking. Original numeric coding and sample exclusions were preserved.

| Method | M | Estimate (HbA1c percentage points) | 95% CI |
|---|---:|---:|---|
| WDSM | 1 | 0.070467 | [0.004005, 0.136929] |
| WDSM | 3 | 0.074021 | [0.014437, 0.133606] |
| WDSM | 5 | 0.074145 | [0.014311, 0.133979] |
| SW-PSM | full | 0.070768 | [0.006834, 0.134703] |

SW-PSM also has an interval excluding zero. WDSM estimates do not decrease with M, and the M=3/M=5 intervals are nearly identical. These comparisons do not establish bias relative to an unknown causal effect.

## Current files

- NHANES: `0727 Test (SW_DSM)/Case Study Data/NHANES/WDSM_adaptive.R`
- NSDUH: `0727 Test (SW_DSM)/Case Study Data/SAMHSA 0914/Analysis/Scripts/wdsm_flexible.R`
- The NHANES `ANALYSIS_10_SLEEP_HBA1C_FIXED.R` caller now supplies sampling weights to full matching and uses B=200. Other historical runners and saved results are not automatically updated.
- `verified_2026_09/run_verified_wdsm.R` reproduces the five WDSM results above from saved inputs with the recorded RNG protocol.
- `verified_2026_09/results.csv` contains all 17 comparisons. This update adds no participant data or fitted-model objects.

Run from the repository root with original inputs available:

```sh
Rscript CaseStudy/verified_2026_09/run_verified_wdsm.R
```

## Corrections and scope

Matching uses **probability-scale propensity and the appropriate arm-specific prognostic score**, with pooled unweighted componentwise standardization. The previous README's claim that logit-scale scores were required was incorrect for this manuscript specification. Bias correction uses a survey-weighted complete quadratic in the same double score. This fixed basis does not itself prove a nonparametric rate assumption.

NHANES propensity fitting weights are normalized by a common constant to prevent the original GLM initialization failure without changing the estimating equation. Convergence is checked. Replications refit nuisance regressions but retain the original reuse coefficients, as specified in the current manuscript. They do not rematch zero-multiplicity observations or silently omit failed imputations. NSDUH uses an equivalent rowwise distance computation to avoid large matrices.

WDSM intervals are **Wald intervals from B-divisor replication variance**, not the old NHANES bias-corrected percentile intervals. SW-PSM retains matched-subclass cluster-robust covariance, not survey-PSU clustering; matching and survey outcome weights are combined exactly once. Unweighted comparisons retain the original dsmatch procedures.

NHANES restores each original M-specific starting RNG state and extends 50 draws to 200, preserving its first 50 draws. Extended runs overlap in random draws. NSDUH resets 2024 per outcome. All five WDSM runs completed 200/200 replications and matched independent numerical calculations to approximately 1e-15.

Numerical agreement is **not a completed proof of estimated-score or bootstrap validity**. Final appendix justification and NHANES special-value coding remain author-review items. Refused/unknown codes were retained for reproduction; changing their handling requires rerunning. These checks do not establish design-valid multistage-survey inference.

## Historical archive

The [2026-09-07 snapshot](0727-snapshot/README.md) retains the original complete folder, data and old results. It is historical, not the current numerical analysis.
