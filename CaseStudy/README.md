# Case study analyses

## Current correction audit — September 17, 2026

The complete original source datasets have now been recovered from the July 27
folder and added under each study’s `data/raw/` directory. See
[full-source provenance](provenance/RAW_DATA.md) and the
[tie-correction protocol](../audit/ties_20260917/PROTOCOL.md).
`prepare_from_raw.R` rebuilds both samples; `rerun_tie_correction.R` reruns all
methods, with paired controls for tie allocation and NHANES missing-code changes.
The results below and `Results/Final_20260917/` are the **preserved September 9
baseline**, pending the newly corrected analysis. They must not be described as
already incorporating the new tie rule or the 3,790-person NHANES sample.
Historical reproduction commands explicitly retain the old row-order rule.

## Reproducible release — September 17, 2026

The exact analytic input files are now included in `NHANES/data/` and `NSDUH/data/`.
The release retains the corrected estimator and scientific specification verified
on September 9. See [input provenance](DATA.md), [checksums](data_manifest.json),
and the [final results package](Results/Final_20260917/).

## Verified implementation — September 9, 2026

The five WDSM fits were rerun on Yale Bouchet from frozen commit `8444359` with the original samples, formulas, seed protocol **2024**, **B=200**, and Wald intervals. All 1,000 replications and 1,005 propensity fits passed the recorded numerical checks. These results supersede the earlier WDSM numerical rows; the 12 comparator rows are preserved. These functions do not use a replacement implementation from the wdsmatch package.

### NSDUH

Original sample: 17,471 adults aged 18–29 (1,877 treated). Prospective WDSM uses unweighted first-stage propensity and prognostic fits, survey-weighted imputation/correction, and an outer Hájek average.

| Outcome | M | Estimate (risk difference) | 95% CI |
|---|---:|---:|---|
| AMIPY | 5 | 0.065414 | [-0.004755, 0.135583] |
| SMIPY | 5 | 0.018153 | [-0.016619, 0.052925] |

### NHANES

Saved sample: 3,793 adults aged 40–70 from **2015–2018**, after excluding reported diagnosed diabetes. Retrospective WDSM uses weighted propensity fits and unweighted prognostic fits. All methods in the primary comparison use seven covariates, including smoking. Original numeric coding and sample exclusions were preserved.

| Method | M | Estimate (HbA1c percentage points) | 95% CI |
|---|---:|---:|---|
| WDSM | 1 | 0.070467 | [0.003999, 0.136935] |
| WDSM | 3 | 0.074021 | [0.014426, 0.133617] |
| WDSM | 5 | 0.074145 | [0.014335, 0.133954] |
| SW-PSM | full | 0.070768 | [0.006834, 0.134703] |

SW-PSM also has an interval excluding zero. WDSM estimates do not decrease with M, and the M=3/M=5 intervals are nearly identical. These comparisons do not establish bias relative to an unknown causal effect.

## Rebuild the paper tables and figures

From the repository root:

```sh
Rscript --vanilla CaseStudy/assemble_publication.R /path/to/new-publication-output
```

This independently recomputes the B-divisor SEs and Wald endpoints from the 1,000
saved Bouchet draws, checks all 1,005 propensity diagnostics, and rebuilds the
17-row CSV, Markdown/LaTeX tables and PNG/PDF/SVG figures. It retains the 12
unchanged comparator rows. Requirements: R, Python 3 and matplotlib.

## Rerun the estimators from the included data

From a clean Git checkout:

```sh
Rscript --vanilla CaseStudy/reproduce.R /path/to/new-case-rerun
```

The five WDSM fits use base R. This command runs NHANES M=1/3/5 and NSDUH
AMIPY/SMIPY M=5, requires 200 draws per fit, and independently checks B-divisor
variance, Wald intervals, source/input hashes and RNG states. It saves five RDS
records, all draws and diagnostics, runtime details and the comparison against
Bouchet. It refuses to overwrite a nonempty output directory or run uncommitted source.

**Runtime comparison:** the September 17 Mac R 4.4.0 rerun reproduced all point
estimates within 4e-16, but its replication draws and SEs differ slightly from
Bouchet R 4.4.2. The largest CI-endpoint difference is 0.000024549. This does not
change which reported intervals exclude zero. The cause has not been isolated;
identical RNG states alone do not establish identical fitted replicate values.
See [`verification_20260917/`](verification_20260917/). Accordingly, the paper's
**authoritative numbers remain the September 9 Bouchet results** in `Figures/`
and `Results/Final_20260917/`; they are not replaced by this local rerun.

After saving reviewable output, `reproduce.R` returns an error if any draw or
summary differs from the authoritative run by 1e-8 or more. This is a publication
safeguard, not a dropped-replicate procedure. Run `assemble_publication.R` to
reconstruct the paper outputs exactly from their saved draws on either runtime.
The 12 comparator rows are **not newly estimated** by either command; every row's
origin is recorded in `row_provenance.csv`.

### Current code

- `NHANES/WDSM_adaptive.R`: corrected retrospective estimator.
- `NSDUH/wdsm_flexible.R` and `NSDUH/prepare_nsduh.R`: corrected prospective estimator and original covariate preparation.
- `case_rerun_config.R`: frozen input identities, sample specifications and RNG protocol.
- `rerun_wdsm_final.R` and `submit_wdsm_final.sbatch`: isolated per-case execution locally or on Bouchet.
- `reproduce.R` and `verify_results.R`: estimator rerun and independent numerical/reference checks.
- `assemble_publication.R`: exact publication output from the verified Bouchet draws.
- `Figures/plot_corrected_case_studies.py`: plot the 17-row table; accepts `--results` and `--output`.
- `NHANES/run_wdsm_corrected.R` and `NSDUH/run_wdsm_corrected.R`: smaller per-study checks retained for compatibility.

For Bouchet, supply `WDSM_REPO`, `WDSM_CODE_COMMIT`, `CASE_OUTPUT_DIR`, an R module,
and the account/partition. Inputs default to the bundled files; `NHANES_INPUT`
and `NSDUH_INPUT` can override paths only with files having the frozen identities.
After the array succeeds, call `verify_case_results()` from `verify_results.R`,
then render the figure with the resulting `results.csv`.

## Corrections and scope

Matching uses **probability-scale propensity and the appropriate arm-specific prognostic score**, with pooled unweighted componentwise standardization. The previous README's claim that logit-scale scores were required was incorrect for this manuscript specification. Bias correction uses a survey-weighted complete quadratic in the same double score. This fixed basis does not itself prove a nonparametric rate assumption.

NHANES propensity fitting weights remain normalized by a common constant, preserving the estimating equation. Both case functions now use zero-coefficient initialization and verify convergence, coefficient identification, nonsaturated probabilities, and a dimensionless score residual at most 1e-7. Their original inference formulas needed no additional correction. A nonfinite NSDUH reuse coefficient now stops instead of being replaced by zero. Replications refit nuisance regressions but retain the original reuse coefficients, as specified in the current manuscript. They do not rematch zero-multiplicity observations or silently omit failed imputations. NSDUH uses an equivalent rowwise distance computation to avoid large matrices.

WDSM intervals are **Wald intervals from B-divisor replication variance**, not the old NHANES bias-corrected percentile intervals. SW-PSM retains matched-subclass cluster-robust covariance, not survey-PSU clustering; matching and survey outcome weights are combined exactly once. Unweighted comparisons retain the original dsmatch procedures.

NHANES restores each original M-specific starting RNG state and extends 50 draws to 200, preserving its first 50 draws. Extended runs overlap in random draws. NSDUH resets 2024 per outcome. All five WDSM runs completed 200/200 replications. The B-divisor standard errors and Wald endpoints were independently recomputed from all saved draws. Original and final RNG states matched independent reconstruction. Sanitized summaries, draw vectors, and propensity diagnostics are in `verification_20260909/`; they contain no participant records or fitted models.

The September 9 rerun changes CI endpoints by at most 0.000025 relative to the preceding CSV while preserving the conclusions. A same-input, same-RNG, same-runtime NHANES M=5 check with the exact preceding function reproduces the new SE within 1.1e-12; its difference from the earlier CSV therefore predates this safeguard update. The original cause of that historical mismatch was not established. See the execution audit and paired legacy/new draws in `verification_20260909/`.

Numerical agreement is **not a completed proof of estimated-score or bootstrap validity**. Final appendix justification and NHANES special-value coding remain author-review items. Refused/unknown codes were retained for reproduction; changing their handling requires rerunning. These checks do not establish design-valid multistage-survey inference.


## Removed superseded runners

`NHANES/ANALYSIS_10_SLEEP_HBA1C_FIXED.R` and `NSDUH/11_complete_both_outcomes.R`
were removed from the active tree. The first used a different raw-data/RNG pathway;
the second could continue after estimator errors and emit incomplete comparisons.
Neither is the audited five-fit reproduction entrypoint. Their prior versions are
recoverable at Git commit `d93a7e6`.

The current simulation core is `R/wdsm_core_final.R`; legacy compatibility names
already route to it. Superseded pre-alignment function copies and the obsolete
PATE-only diagnostic runner/summary were removed. The original July 27 snapshot
is explicitly historical and remains preserved for provenance.
