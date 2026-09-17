# Weighted Double Score Matching (WDSM)

## Full inference and implementation correction — September 9, 2026

The paper’s original simulation tables have been traced to the saved 0727 publication results and Tong’s Bouchet production runs. The original PATE bootstrap omitted residual reuse contributions and used percentile intervals. Retrospective propensity fits also failed numerically in both PATE and PATT. The full audit additionally identified a discrepancy between the old simulation score/bias-correction implementation and the probability-score, own-arm construction used by the manuscript and corrected case studies.

**Status: both full studies are complete and verified.** The [final results index](Results/Final_20260909/README.md) contains corrected main tables/figures, the complete stabilized point-estimator comparison, verification records, and [raw archives/input files](https://github.com/ykzeng-yale/SW_DSM/releases/tag/final-simulations-20260909). Main validation passed all 224,000 method results and 38.4 million bootstrap draws. Stabilized validation paired all 96,000 estimates; 72 positivity rejections remain explicit. The tested quadratic stabilizer improves absolute bias in 28 of 81 fully defined settings and does not generally resolve poor-overlap bias.

Historical numbers outside `Results/Final_20260909/`, including `Tables/All_12_Simulation_Tables.txt` and the original simulation images, remain the preserved baseline. Use the linked final outputs for corrected results. See [run status](audit/full_rerun_execution.json), [result lineage](audit/paper_result_lineage.md), and [case-study comparison](audit/case_study_fix_comparison_20260909.md).

A separate [conditionally stabilized point-estimator experiment](StabilizedWDSM/README.md) tests whether the Section 3.3 extension reduces relative bias. It uses the same 32 settings, 1,000 replications per setting, and M=1/3/5, with identical original samples, fits, and matches. Its [protocol](StabilizedWDSM/simulation_protocol.md) and [execution record](StabilizedWDSM/audit/execution.json) distinguish pilot checks from production results. No stabilized causal-effect SEs, confidence intervals, or coverage are being developed in this experiment.

## Current implementation

- `R/wdsm_core_final.R`: one checked PATE/PATT implementation for both designs and all M values. It uses probability propensity scores, own-arm prognostic scores, original fixed weighted reuse, the correct estimand-specific denominator, all B requested replication draws, B-divisor variance, and centered normal Wald intervals. It fails explicitly on invalid nuisance fits or draws.
- `R/comparators_final.R`: the original PSM/PGM/DSM nearest-neighbor algorithms (M=1) and survey-weighted optimal full matching, with additional checks and saved diagnostics. Nearest-neighbor comparator variance retains the vendor’s B−1 convention; SW-PSM uses its subclass-cluster sandwich variance. All reported intervals are normal Wald intervals. These are different variance estimators, not one shared bootstrap formula.
- `Simulations/rerun_wdsm_final.R`: reproducible 32-setting rerun (PATE/PATT × retrospective/prospective × good/poor overlap × four model specifications). Every sample is analyzed with WDSM M=1/3/5 and all four comparators. It saves samples’ population IDs, full bootstrap draws, convergence diagnostics, deterministic seeds, and code/data/runtime hashes.
- `Simulations/submit_wdsm_final.sbatch`: array indices 0–31, pilot by default. Production requires an explicitly selected separate output directory and 1,000 replications per setting after the complete pilot passes.

The original sampling seed remains `2025 + replication`. Bootstrap streams are separately recorded new deterministic streams. The prospective WDSM propensity model uses unweighted point fits and multiplicity-weighted replicate fits; the retrospective version uses survey weights and multiplicity-times-survey weights. Prognostic fits do not use survey weights; bias-correction fits do.

The concrete pooled component standardization and complete quadratic bias-correction basis match the corrected case studies. These finite-dimensional implementation choices do not themselves establish the asymptotic sieve conditions or validate an iid replication scheme for every multistage sampling design. Numerical validation and theoretical justification remain distinct.

## Running the corrected analysis

```sh
Rscript --vanilla Simulations/rerun_wdsm_final.R --help
Rscript --vanilla tests/test_wdsm_core_final.R
```

Provide `--repo`, `--data-dir` (or `--data-file`), `--output`, `--estimand`, `--design`, `--overlap`, and `--scenario`. Use `--pilot` for the initial five-sample check; `--reps 1000 --B 200` selects the full simulation. Outputs never default to historical results. Resume checks code, data, runtime, and configuration identity.

For Bouchet, set `WDSM_REPO`, `WDSM_DATA_DIR`, `WDSM_OUTPUT_DIR`, and the available R module, then submit the array with the authorized account and partition. The recorded current run uses R 4.4.2 and the `day` partition. Set BLAS/OpenMP threads to one; allocated workers provide parallelism.

Canonical per-scenario R and shell entry points now route to this same driver. The public `compute_wdsm_method2_ci()` and `compute_wdsm_patt_ci()` compatibility functions call the finalized core. Separate historical point/bootstrap objects and the earlier PATE-only driver are retired because their score objects and configuration do not match the final implementation. Superseded diagnostic function copies have been removed from the active tree; recovery instructions remain in `R/legacy_pre_alignment_20260909/README.md` and Git history.

## Validation and outputs

The final-core suite has 318 independent numerical checks, including unequal survey weights, both estimands/designs, M=1/3/5, nuisance fitting weights, fixed-reuse identities, failure handling, and synthetic parity with corrected NHANES/NSDUH functions. Comparator validation matches the untouched vendor estimates and variance exactly across all model specifications.

The actual pilot passed all 32 settings, 160 sampled data sets, 1,120 method results and 192,000 bootstrap draws without warnings or failures.

The complete production run contains 32,000 sample-analysis records (4,000 distinct sampled data sets reused across estimands/specifications), 224,000 method results, and 38.4 million WDSM/vendor bootstrap draws. Publication tables and figures must come from the strict complete-run summary; failed or missing records cannot be dropped independently from estimates and intervals. Every replacement artifact must link to that run’s manifest. The exact saved case-study input data, corrected scripts, verification output, tables and figures are now included under [`CaseStudy/`](CaseStudy/). Rebuild the authoritative paper outputs with `Rscript --vanilla CaseStudy/assemble_publication.R NEW_OUTPUT_DIRECTORY`. `CaseStudy/reproduce.R` reruns the five WDSM fits and flags platform differences; the 12 unchanged comparator rows are explicitly retained references. The September 17 Mac rerun has small SE differences and is stored separately without replacing the verified Bouchet results.

## Full 0727 experiment folder

- [Browse `0727 Test (SW_DSM)`](0727%20Test%20%28SW_DSM%29/)
- [Download the complete folder, including large data and saved results](https://github.com/ykzeng-yale/SW_DSM/releases/tag/0727-full-snapshot-20260907)
- [Restore instructions, complete inventory, and checksums](0727-snapshot/README.md)

The browsable copy contains code and files up to 10 MB. The release archive preserves every original file, symbolic link, and subdirectory.


Final summaries use `Tables/summarize_wdsm_final.R`. Render four publication tables with `Tables/generate_wdsm_final_tables.R` and all figure variants/M values with `Figures/generate_wdsm_final_figures.R`; both take explicit `--summary` and `--output` directories and verify the complete-summary checksum. Pilot rendering requires `--pilot-preview` and is visibly labeled. `Simulations/finalize_wdsm.sbatch` runs these sequentially after a successful production array.
