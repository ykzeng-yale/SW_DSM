# Case-study corrections compared with the PATE simulation corrections

Read-only audit, September 9, 2026. Repository: `/Users/yukang/Documents/WDSM_PATE_bootstrap_20260909`. No models were fit, no case-study numerical analysis was rerun, and no original inputs or `CaseStudy/` files were changed. `CaseStudy/` is unchanged from `origin/main` at `3356769`.

## What was already fixed, and when

[Commit aa1f695](https://github.com/ykzeng-yale/SW_DSM/commit/aa1f69534700d22046f101b257be40aebdfad2da) made the substantive corrections on **September 7, 2026, 12:38 EDT**. Its recorded timestamp is September 8, 00:38:04 +08:00. The diff patches the original NHANES/NSDUH functions and adds a verified aggregate table plus a reproducibility runner.

[Commit dadf414](https://github.com/ykzeng-yale/SW_DSM/commit/dadf414c3940353d17f9aaf83f6553911ba24d27), seven minutes later at **12:45 EDT**, moved those corrected functions into the current NHANES/NSDUH directories, split the reproducibility wrappers, and replaced the hard-coded figure with a figure generated from `Figures/results.csv`.

The September corrections already included:

- **Wald intervals with the manuscript's B-divisor variance.** Current NHANES lines 419–422 and NSDUH lines 316–319 explicitly implement this. NHANES previously used bias-corrected percentile intervals; NSDUH already had Wald endpoints but its replication details and variance convention were corrected.
- **Fixed original reuse coefficients during replication.** Regressions are refit with multinomial counts; original donor reuse is retained. NHANES previously reran matching after changing weights. Failed fits/imputations are no longer silently dropped to produce an apparently valid result.
- **The same raw-weight GLM initialization problem now found in simulations.** NHANES lines 71–84 divide the propensity-fitting weights by their common mean and check convergence. This preserves the weighted logistic estimating equation. The current simulation fix uses a zero coefficient start with raw weights and stronger numerical checks. These are different numerical remedies for the same failure mechanism, not different target propensity models.
- **Design-specific nuisance weighting.** NSDUH uses prospective unweighted propensity/prognostic point fits and multiplicity-only refits; NHANES retains survey-weighted propensity fits and unweighted prognostic fits.
- **Case-study matching and bias-correction geometry.** Both now match on probability-scale propensity and the appropriate arm-specific prognostic score, with pooled unweighted componentwise standardization. Each arm uses a complete quadratic of its own double score. The earlier README assertion that logit-scale propensity was required was withdrawn.
- **NHANES caller/RNG details.** The broad caller now supplies sampling weights to full matching and uses B=200. The exact WDSM wrapper preserves the saved 3,793-person sample, seven covariates, and original M-specific RNG starts while extending 50 draws to 200. NSDUH resets seed 2024 for each outcome.

Sources: `CaseStudy/README.md` lines 45–55; the actual aa1f695 diffs; `CaseStudy/NHANES/WDSM_adaptive.R` and `CaseStudy/NSDUH/wdsm_flexible.R`.

## Which saved results the current paper uses

The current 17-row `CaseStudy/Figures/results.csv` is **byte-identical** to `aa1f695:CaseStudy/verified_2026_09/results.csv`. Current NHANES code is byte-identical to that commit's patched source; NSDUH differs only by two trailing blank lines. Current PNG/PDF are byte-identical to the regenerated files committed in dadf414.

The active case-study text in `main (8).tex` matches these corrected aggregates, not the earlier package README or old hard-coded figure:

| WDSM result | Estimate | 95% CI |
|---|---:|---:|
| NSDUH AMIPY, M5 | 0.065414 | [−0.004752, 0.135581] |
| NSDUH SMIPY, M5 | 0.018153 | [−0.016620, 0.052926] |
| NHANES HbA1c, M1 | 0.070467 | [0.004005, 0.136929] |
| NHANES HbA1c, M3 | 0.074021 | [0.014437, 0.133606] |
| NHANES HbA1c, M5 | 0.074145 | [0.014311, 0.133979] |

All five saved endpoints equal estimate ± z(.975)×SE within 6.4×10^−16. The plotting script directly loads that CSV (lines 15–25); the two exact WDSM wrappers source the corrected functions and compare computed outputs against the same CSV at tolerance 1e−8.

The prior committed README records 200/200 valid replications and agreement with an independent calculation around 1e−15. **This audit verifies the code/commit/result lineage and the saved CI algebra; it does not newly validate or repeat those 200/200 runs.** Participant inputs and fitted objects are not stored in the active CaseStudy directories.

Older material remains distinguishable. The April 13 [fa7b54b package implementation](https://github.com/ykzeng-yale/SW_DSM/commit/fa7b54b0aafb08111e35eea3482c5d5c2be17c15) had a README and hard-coded figure with different numbers. The restored top-level `0727 Test (SW_DSM)` contains legacy functions and figures with different hashes; they were preserved, not automatically updated. Use the canonical CaseStudy wrappers/CSV for the corrected case-study record.

## What remains different from the current PATE batch

The current PATE simulation batch corrects Wald/B-divisor inference, fixed original reuse, and propensity-solver stability. It **does not yet fully harmonize the point-estimation implementation with the case studies and current paper description**:

| Component | Corrected case studies | Current PATE simulation batch |
|---|---|---|
| Propensity coordinate used for matching | Probability e | Clipped logit(e) |
| Matching component standardization | Pooled unweighted | Survey-weighted |
| Bias-correction basis | Arm-specific complete quadratic in (e, psi_z) | Joint 10-term basis involving psi0, psi1 and logit(e), plus intercept |

Simulation evidence: `R/wdsm_ci_functions.R` lines 198–229. Case evidence: `CaseStudy/NSDUH/wdsm_flexible.R` lines 127–149 and NHANES lines 128–175, 193–203. Thus it is accurate to say these specific inference and solver corrections are shared. It is inaccurate to say the simulation batch now reproduces every component of the corrected case-study/paper algorithm.

## Content fingerprints

- Current corrected CSV: `511f1cd167e02c02052119248fe7a496c8f95ab5f6fb68e65e12c9eb0522eb35`.
- Current NHANES source: `f7e614f1fe09e833f3717d1cca5d94e505bd9036c7570a234ce18bb7baccc18e`.
- Current NSDUH source: `91b9dfc287d60755d03400ba2eb31328a47caf14b8d05d58651d4cd75a1a7217`.
- Current corrected PNG: `5f568839a09b5aeaf4e432e0524e355e596dd40c56bef4317f25c2e0a05a02a0`.
- Current corrected PDF: `cc2177506dc0f01fc0ae797ac0d4ba175dd97efcd21b53ef0177ff47061312eb`.
