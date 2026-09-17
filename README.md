# Weighted Double Score Matching (WDSM)

## September 17 tie and full-source correction

Full NSDUH 2023 and merged NHANES 2007–2018 sources are now in
[`CaseStudy/`](CaseStudy/provenance/RAW_DATA.md). A full byte-read of the July 27
folder verified every one of its 7,106 regular files against the preserved
snapshot; no unavailable iCloud placeholders or substitute datasets are used.

Current WDSM uses recipient-specific randomized selection at tied distance
boundaries, with an independent reproducible RNG stream and fixed original
match sets in replication. The active main/stabilized simulations and both
case estimators share `R/wdsm_ties.R`. NHANES preprocessing now excludes three
refused/unknown responses (n=3,790); NSDUH remains n=17,471.

The [new complete case comparison](CaseStudy/Results/TieCorrection_20260917/README.md)
is verified, including all 17 rows, paired controls, and 40 tie-seed sensitivity
fits. The full 32-cell, 1,000-replicate stabilized rerun is complete: all 95,928
successful estimates are exactly unchanged, and the same 72 positivity rejections
remain. The [independent comparison](audit/ties_20260917/stabilized_pairing/comparison_summary.txt)
found no allocation-relevant ties in any of the 96,000 estimator pairs.
The full main rerun and final pairing/summary checks are still in progress.
The main pilot passed all settings with exact numerical parity and no ties. See the
[correction protocol](audit/ties_20260917/PROTOCOL.md) and
[Bouchet job record](audit/ties_20260917/submitted_workflow.json). The completed
September 9 studies described below remain the preserved baseline; their tables
and figures do not yet represent the new tie correction.

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

The completed September 9 production run contains 32,000 sample-analysis records
(4,000 distinct sampled data sets reused across estimands/specifications),
224,000 method results, and 38.4 million WDSM/vendor bootstrap draws. The new
September 17 tie-corrected production runs are still in progress. Publication
simulation tables and figures must come from their strict complete-run summary;
failed or missing records cannot be silently dropped.

For the current applications, use
`CaseStudy/Results/TieCorrection_20260917/` and reproduce all 17 comparison rows
from the full raw sources with `CaseStudy/reproduce_tie_correction.R`.
The September 9 case commands (`assemble_publication.R`, `reproduce.R`) retain
the old sample/tie convention and are historical reproductions only.

## Full 0727 experiment folder

- [Browse `0727 Test (SW_DSM)`](0727%20Test%20%28SW_DSM%29/)
- [Download the complete folder, including large data and saved results](https://github.com/ykzeng-yale/SW_DSM/releases/tag/0727-full-snapshot-20260907)
- [Restore instructions, complete inventory, and checksums](0727-snapshot/README.md)

The browsable copy contains code and files up to 10 MB. The release archive preserves every original file, symbolic link, and subdirectory.


Final summaries use `Tables/summarize_wdsm_final.R`. Render four publication tables with `Tables/generate_wdsm_final_tables.R` and all figure variants/M values with `Figures/generate_wdsm_final_figures.R`; both take explicit `--summary` and `--output` directories and verify the complete-summary checksum. Pilot rendering requires `--pilot-preview` and is visibly labeled. `Simulations/finalize_wdsm.sbatch` runs these sequentially after a successful production array.
