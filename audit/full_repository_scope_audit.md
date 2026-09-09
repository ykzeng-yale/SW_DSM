# Full simulation scope and comparator audit

September 9, 2026. Initial audit checkout: `/Users/yukang/Documents/WDSM_PATE_bootstrap_20260909`. Active checkout after migration out of iCloud-backed Documents: `/Users/yukang/.codex/workspaces/WDSM_final_20260909`. The historical source baseline is Git `3356769`; the original 0727 archive, historical Results, and vendored `R/dsmatch` files were not modified. This report concerns the simulation/comparator audit and subsequent compatibility routing. It is not a completed 1,000-replication rerun or a new case-study numerical validation.

## Scope and decision

The complete grid has **32 cells**: PATE/PATT × retrospective/prospective × good/poor overlap × CorCor/MisCor/CorMis/MisMis. WDSM has three matching ratios, M=1,3,5. PSM, PGM and DSM use the author's **M=1** nearest-neighbor methods; SWPSM uses optimal full matching. The final run therefore needs seven method results per sampled data set, not separate M=3/5 variants of the comparators.

The confirmed WDSM defects and alignment changes are documented separately in `propensity_numerical_audit.md` and the main bootstrap audit. **This comparator audit found no additional confirmed numerical defect that, by itself, invalidates every historical comparator result.** Nevertheless, all four comparators are being recomputed with the final WDSM run to give one complete provenance record, explicit failure checks, and separate deterministic method RNG streams. This is a clean rerun decision; it is not a claim that the comparator equations must be replaced.

## Verified comparator behavior

All 32 pre-routing comparison scripts were inventoried in `simulation_wrapper_inventory.csv`, including their source SHA-256 values. They consistently:

- Call `dsmatchATE` for PATE and `dsmatchATT` for PATT, with separate `X_ps`/`X_pg` matrices for DSM's independently correct or misspecified score models.
- Fit PSM/DSM propensity models without survey weights; fit prognostic models without survey weights. The active vendored ATE/ATT bootstrap functions refit these nuisance models after resampling and retain the original reuse counts.
- Use full-match estimand ATE and a survey-weighted population average for SWPSM PATE; use ATT and average over treated observations for SWPSM PATT.
- Normalize SWPSM survey weights to mean one before propensity fitting. Thus SWPSM does **not** inherit the confirmed raw-weight initialization failure from the former retrospective WDSM propensity code.
- Construct symmetric Wald intervals for all four comparators. Vendor bootstrap variance uses `var(bootstrap_draws)`, divisor **B−1**; SWPSM uses subclass-cluster sandwich/delta-method SEs. These are the comparator-specific variance methods, not WDSM's B-divisor replication formula.

The SWPSM adjusted outcome regression is deliberately always correctly specified, including treatment interactions with all six main effects and X1×X2, even in the PG-misspecified scenarios. This existing comparator design is preserved and must be described accurately; its PG column is not an independently misspecified prognostic matching model.

Active source review covered `dsmatchATE.R`, `dsmatchATT.R`, `is.lp.R`, `is.ps.R`, `is.pg.R`, and the six `estforboot_{ds,ps,pg}{ATE,ATT}.R` paths. QTE/QTT, direct-covariate matching, zero-inflated outcome branches, and caliper variants are unused by these simulations and were not treated as active numerical paths. The author's DSM geometry and bias correction remain comparator-specific; they are not silently rewritten into the new WDSM algorithm.

## Historical saved-output checks

`comparator_saved_output_audit.R` reads all 32 canonical result files without refitting. Its CSV contains 384 rows: 32 cells × three historical M-loop labels × four comparators, each containing 1,000 records.

**All 384,000 saved comparator records have finite estimates, SEs and endpoints; every SE is positive, no interval is reversed, and every interval is Wald within 8.9×10⁻¹⁶.** This establishes the saved-output algebra and completeness, but cannot recover unrecorded nuisance warnings or prove that no inner bootstrap draws were discarded. The old vendor uses `na.rm=TRUE` and does not save its draw-level failure count in the outer results.

The old M loop called the same M=1 comparator three times with advancing RNG streams. Tables and figures select the loop label `_M5`. Their points are not always identical across loop labels: comparing 32,000 M1/M5 pairs per method gives DSM 1 differing pair (maximum absolute difference 0.0005051), PGM 8,558 (0.0083126), and PSM 15,602 (0.0108971). All 32,000 vendor SE pairs differ. SWPSM estimates and SEs agree for all pairs. See `comparator_repeated_M_records.csv`. The vendor's `ties=FALSE` matching resolves tied candidates using the RNG; fresh deterministic matching/bootstrap streams can therefore change comparator points as well as SEs without changing M or the comparator equations.

## Sampling, truth, and output consumers

All 32 wrappers use sample seed `2025 + seed_offset + replicate`. The 16 retrospective cells use Bernoulli inclusion depending on A and six X variables, with inverse inclusion probabilities. The 16 prospective cells use the intended stratified multistage sampling path and inverse final inclusion probability. All 16 PATE truths are the finite-population average of Y1−Y0 (`S` is initialized to one); all 16 PATT truths average Y1−Y0 among population A=1. PATT's stored variable is misleadingly called `true_pate`, but its calculation targets PATT correctly. These source checks do not prove that design-based bootstrap consistency follows from the paper's assumptions.

All four simulation tables and all 24 stored simulation PNG/PDF variants depend on these results. `Tables/generate_tables.R` computes PSM-CorCor Monte Carlo variance as the relative-efficiency reference, displays all three WDSM M values, and selects comparator loop label M5. `Figures/generate_figures_transposed.R` uses WDSM M5 and the same comparator label. Both use saved CI endpoints directly; neither converts old PATE intervals to Wald during plotting.

Two confirmed pipeline defects were identified: the old relative input layout expects `Results` and `Results_PATT` instead of canonical `Results/PATE` and `Results/PATT`, and missing endpoints are filtered independently rather than with a paired complete-case/failure ledger. The latter did not affect the verified complete comparator records, but must not govern new output. Final summaries should require the intended number of successful paired records, list failures explicitly, and regenerate every affected table/figure from the final run directory.

The previously corrected canonical case-study wrappers and figure dependencies are recorded in `case_study_fix_comparison_20260909.md`. The active figure reads `CaseStudy/Figures/results.csv`; the NHANES/NSDUH exact WDSM wrappers source their corrected functions and compare against that CSV. Broad case runners remain a separate API/input problem: NHANES also calls the installed dsmatch package, while NSDUH sources the vendored version. No fresh case-study fits were run for this scope audit, and those callers must not be presumed identical to a generic six-covariate simulation wrapper.

## Implemented comparator checks and routing

`R/comparators_final.R` exposes `compare_final()` and `comparator_final_dependencies`. It loads the active vendor functions in a private environment; leaves their equations, variance convention and source files unchanged; checks every GLM for convergence and finite coefficients/probabilities; checks regression fitted values; and captures all B bootstrap draws before the vendor's `na.rm` operation. Nonfinite or missing draws cause failure. Warnings, regression ranks, model-fit counts, bootstrap counts, package versions and variance convention are returned as diagnostics. SWPSM retains its original mean-one weights, full matching, correctly specified adjusted outcome model and subclass-cluster SEs; its propensity fit is explicitly inspected. All returned intervals use the requested Wald alpha.

Validation in `comparator_final_validation.R/.csv/.log` passed **24 exact estimate/variance comparisons** with untouched vendor calls across both estimands and four PS/PG specifications; **four SWPSM comparisons** with the historical call; and **five invalid-input/draw rejection checks**. These are bounded n=250, B=5 software checks, not evidence that the complete production grid has finished or that every real sampled data set will fit successfully.

The first cluster pilot exposed a software-version difference: MatchIt 4.6 does not export `match_data`. The comparator wrapper now uses the historical `MatchIt::match.data` API, also supported by local MatchIt 4.7.2. The 28 numerical comparisons and five rejection checks passed again after that compatibility change; the cluster's own follow-up pilot is the runtime-specific verification.

All 98 old simulation entry points now route to the shared final driver: 32 comparison scripts, 32 preprocessors, 32 shell dispatchers and two generic PATE/PATT scripts. `Simulations/legacy_entrypoint_adapter.R` requires explicit population inputs and a new output directory; uses a pilot by default; and fixes per-cell metadata. Shell callers map each cell exactly once onto array indices 0–31 in `submit_wdsm_final.sbatch`. All 32 shell scripts pass syntax checks, all 68 R entry points/modules parse, and representative PATE/PATT/generic help routes pass. `final_entrypoint_routing.csv` records the mapping. The numerical driver, summary/report replacements and completed cluster-run status remain separately verified deliverables.

The five public legacy R compatibility modules were also independently checked against direct calls to `wdsm_final` on the same n=160, B=3 synthetic data and seed. All five preserve their named retrospective/prospective and PATE/PATT defaults, and return identical estimates, variance, and draws. The six-numeric-covariate restriction and retirement of incompatible separate point/bootstrap interfaces are explicit.

## Final table pipeline

`Tables/generate_wdsm_final_tables.R` now creates four complete TeX tables from the strict summary through the shared `read_final_metrics` publication gate. `Tables/generate_tables.R` delegates to it; the former generator is preserved byte-for-byte at `Tables/legacy/generate_tables_pre_alignment_20260909.R` (SHA-256 `ce6a1a5b9d8d70fce6a8b1fc067f6762b7c321366104988d211586555afb1fda`). Historical table outputs remain untouched.

Tables use signed relative bias to one decimal, relative efficiency to two decimals, and Wald coverage percentage to one decimal. Prospective WDSM's PS fit is correctly marked unweighted, retrospective WDSM survey-weighted; SWPSM is marked survey-weighted under both designs. A new explicit output directory is required, existing outputs are not overwritten, and the complete strict-summary manifest is retained beside each new table set. Pilot output requires an explicit flag and conspicuous diagnostic labels.

`table_pipeline_validation.R/.log` checks all four tables' 14 method rows, 16 columns, design-specific score marks and formatting with fabricated, clearly labeled fixture values. It verifies rejection of pilot-as-production output, altered metrics checksums, and output overwrites. The four-page synthetic preview compiles with no overfull/underfull boxes. These layout/software checks do not supply new manuscript simulation numbers.

## Safe-checkout integration and final active-path review

The comparator module, 98 adapters, table code and audit evidence were restored from `/tmp/wdsm_lineage_agent_backup_20260909` into the safe active checkout. The comparator source was already byte-identical to the frozen runtime source. All 32 shell dispatchers and 69 R entry points/modules passed routing/syntax checks again; the table fixture gates passed again. Parent-owned core, compatibility, README, summary and figure edits were not overwritten.

The strict complete Bouchet pilot summary in `audit/full_pilot_f299946_strict_summary` was accepted by the table publication gate only with `--pilot-preview`. Four explicitly labeled pilot tables were generated under `audit/full_pilot_f299946_tables`; the four-page PDF preview compiled without overfull/underfull boxes. These are actual five-replication pilot diagnostics, not replacement manuscript results. Production N=1000 results remain a separate completion requirement.

Final WDSM fit routing uses the shared probability-score, own-arm, Wald implementation. Historical logit-score/percentile WDSM formulas are confined to the named legacy directory and original archive. Vendored comparator logit scores and unused returned percentile quantiles remain intentional author-package behavior; comparator wrappers use their checked variance for Wald endpoints. The former PATE-only summary/batch entry points were flagged to the parent for retirement/redirect, so users do not mistake a partial earlier-run summary for final all-estimand output. Broad case-study comparator callers remain distinct from the checked simulation comparator wrapper; fresh case-study convergence/variance validation must be established from their own runs.
