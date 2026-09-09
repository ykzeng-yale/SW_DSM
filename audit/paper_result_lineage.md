# Paper simulation result provenance audit — 2026-09-09

Read-only scope: `/Users/yukang/Downloads/main (8).tex`, original `0727 Test (SW_DSM)` directory, canonical repository checkout at `/Users/yukang/Documents/WDSM_PATE_bootstrap_20260909`, and parent-supplied read-only Bouchet validation snapshots. No original manuscript, local results, or old code was changed. Canonical Git baseline is commit `3356769`; two working R-file edits by the parent are excluded from original-source comparisons.

## Decisive finding

The active paper simulation narrative corresponds to the canonical GitHub saved results AND the original local `0727/Doc` publication data. These are the same result set, not competing sources. The whole four-table text was reconstructed exactly from original `Doc/Results` (PATE) and `Doc/Results_PATT` by evaluating original `Doc/generate_tables.R` without its write call. The reconstructed text is byte-identical to `Doc/All_12_Simulation_Tables.txt`, `Publication_Package/Tables/All_12_Simulation_Tables.txt`, and canonical `Tables/All_12_Simulation_Tables.txt`.

This establishes the tables' numerical provenance. Parent's separate cluster hash audit identifies the production copies in Tong's `pi_gt353` project; see `result_hash_lineage.json`. It does not establish that the currently saved source files are exactly those executed historically.

## Manuscript and scripts

- Active manuscript lines 1802–1803 include `dots_hollow.png` and describe the retrospective horizontal layout. Lines 1835, 1846, 1853, 1855, 1857, 1869, and 1871 quote the exact numerical sequences below. Commented older results beginning around line 1883 were excluded from the active-paper check.
- `Doc/generate_tables.R` lines 40–58 selects exact unsuffixed result filenames and computes coverage directly using stored `ci_lower` and `ci_upper`. It does not rebuild Wald intervals from SE.
- `Doc/generate_figures_transposed.R` lines 6–39 uses the same inputs, selects M5, and computes coverage from those same stored endpoints. This horizontal layout matches the manuscript caption.
- Table script and both figure scripts are byte-identical among `Doc`, `Publication_Package`, and canonical repository. All 98 files in `Publication_Package/Simulations` are byte-identical to canonical simulation files. All 32 `Publication_Package/R` files match Git HEAD (ignoring parent working edits).
- All 32 canonical PATE/PATT result files match the corresponding `Publication_Package` result files. All 16 canonical PATE results match `Doc/Results` unsuffixed files; the original PATT table is regenerated from `Doc/Results_PATT`.
- Canonical and local `Doc/Figures/Retrospective/horizontal/png/dots_hollow.png` are byte-identical. The precise figure embedded with the downloaded TeX cannot be proven from TeX alone: it references a generic basename and no accompanying image was supplied. The layout, filename, and numerical narrative support this figure family.
- The canonical table/figure scripts retain their original `Doc` working-directory assumptions (`Results` / `Results_PATT`), while canonical data are organized under `Results/PATE` / `Results/PATT`; running those scripts from the canonical repository without path setup will not reproduce the tables as-is. The read-only reconstruction used the original `Doc` layout.

## PATE M5 values matching the paper

`Stored coverage` is the actual paper input. `Same-SE Wald` only replaces endpoints using the saved historical SE, and is a diagnostic contrast, not a validated corrected analysis. Correcting the replication formula can also change SE and requires rerunning the variance computation.

| Sampling/overlap | Scenario | Relative bias (%) | Stored coverage (%) | Same-SE Wald coverage (%) |
|---|---|---:|---:|---:|
| Retrospective GoodOverlap | CorCor | -0.3 | 94.7 | 94.4 |
| Retrospective GoodOverlap | MisCor | -0.3 | 95.0 | 95.3 |
| Retrospective GoodOverlap | CorMis | 3.7 | 94.7 | 93.1 |
| Retrospective GoodOverlap | MisMis | 4.6 | 91.3 | 93.4 |
| Retrospective PoorOverlap | CorCor | -0.1 | 93.8 | 91.6 |
| Retrospective PoorOverlap | MisCor | 0.1 | 93.5 | 91.4 |
| Retrospective PoorOverlap | CorMis | 0.6 | 94.1 | 92.1 |
| Retrospective PoorOverlap | MisMis | 12.2 | 81.3 | 85.5 |
| Prospective GoodOverlap | CorCor | -0.6 | 93.7 | 93.7 |
| Prospective GoodOverlap | MisCor | -0.6 | 93.8 | 94.1 |
| Prospective GoodOverlap | CorMis | -0.2 | 95.0 | 94.8 |
| Prospective GoodOverlap | MisMis | 4.0 | 91.1 | 93.2 |
| Prospective PoorOverlap | CorCor | -0.9 | 93.7 | 93.1 |
| Prospective PoorOverlap | MisCor | -0.9 | 94.2 | 94.0 |
| Prospective PoorOverlap | CorMis | -0.6 | 94.8 | 94.2 |
| Prospective PoorOverlap | MisMis | 11.2 | 85.1 | 89.9 |

Every WDSM row has 1,000 saved simulation replicates for each M. Canonical PATE endpoints are non-Wald; PATT endpoints equal estimate ± qnorm(.975) × saved SE. For example, retrospective good CorCor PATT coverage is 94.9%; retrospective poor CorCor PATT is 94.4%, matching active manuscript line 1846. Thus the paper's PATE/PATT CI inconsistency is present in the actual saved inputs, not just a currently visible helper file.

## Dates and older local alternatives

Recorded local modification dates corroborate, but do not independently prove, lineage:

- Original table/figure scripts: April 9, 2026.
- PATT `Doc/Results_PATT`: April 9 around 00:36.
- PATE retrospective `Doc/Results`: April 10 around 13:14.
- Eight earlier prospective PATE `Doc/Results/* 2.RData`: April 10 around 13:14.
- Eight final unsuffixed prospective PATE files: April 13 around 23:49.
- Saved four-table text: April 13 at 23:50; saved horizontal retrospective figure: April 14 at 15:52.
- Eight `Publication_Package/Results/PATE/* 3.RData` files are byte-identical duplicates of final unsuffixed results, not an additional analysis.
- Root-level `visualize_stacked_overlap_results.R` and `visualize_prospective_stacked_results.R` are November 22, 2025 scripts with hard-coded metric arrays. They report different results (e.g. retrospective good WDSM CorCor coverage 94.0 rather than 94.7; prospective good 95.0 rather than 93.7). They do not load the final result inputs and are not the source of the active manuscript's current numerical narrative.
- No `wdsmatch_validation` reference was found in local R/MD/SH scripts; local publication plots and tables load exact unsuffixed results.

## Newer Bouchet `wdsmatch_validation_1000rep` result audit

Parent downloaded all 32 newer results for read-only inspection. A newer timestamp is not evidence these replace the published inputs.

- Across all 96 scenario × M rows, each 1,000-element WDSM point-estimate vector is exactly identical to canonical. The estimates are NOT identical across M1, M3, and M5: no M-insensitivity is observed.
- All 24 retrospective PATE rows also have SE and both CI vectors exactly identical to canonical, despite differences in whole-file hashes.
- All 24 prospective PATE rows have changed SE/CI vectors relative to canonical. Remarkably, all these vectors are exactly identical to the older April 10 local `Doc/Results/* 2.RData` values, while their point estimates match the corrected April 13 unsuffixed results. This is an observed content identity, not a claim about how the files were generated. It indicates corrected point-estimator behavior with old bootstrap behavior in the newer validation outputs; source inspection must establish the mechanism.
- PATT retrospective SE vectors are exactly identical to canonical, but both CI endpoints differ; PATT prospective SE and endpoints also differ.
- All 96,000 WDSM results in newer validation have non-Wald endpoints. The validation wrapper calls the package and returns `fit$ci[1:2]`; it does not reconstruct Wald endpoints.
- Representative M5 stored coverages: prospective PATE good CorCor 94.4% (paper 93.7%); prospective PATE good CorMis 94.3% (paper 95.0%); retrospective PATT good CorCor 92.8% (paper 94.9%); prospective PATT good CorCor 93.3% (paper 94.2%). Therefore the newer validation folder is not the paper's joint numerical input and does not resolve the CI problem.

## Audit artifacts

- `paper_table_reconstructed.txt`: exact four-table reconstruction from the original data and script; no changes to original files.
- `paper_local_result_lineage.csv`: 120 WDSM summaries (including older prospective duplicates), with mean SE, MC SD, stored and same-SE-Wald coverage, and midpoint discrepancy.
- `newer_validation_lineage.csv`: 96 newer validation summaries.
- `newer_vs_canonical_fields.csv`: exact comparison of estimate/SE/CI vectors for all 96 rows.

## Content hashes

| Artifact | SHA-256 |
|---|---|
| `Doc/generate_tables.R` | `ce6a1a5b9d8d70fce6a8b1fc067f6762b7c321366104988d211586555afb1fda` |
| `Doc/All_12_Simulation_Tables.txt` | `1063589c23a1d197a6d9db941717a20fc7bdbe0b294c0f854e0b0e9a6c56ab2e` |
| `Doc/generate_figures.R` | `cb6b2dd9a304d68065a3926e9807762bf8962d5dfe3cfc3f5ba7b845ec151180` |
| `Doc/generate_figures_transposed.R` | `d951d52580eb34b2fb780df0c16e68efb909751cd3d9665d7d37c6aea12a5ec2` |
| `Doc/Figures/Retrospective/horizontal/png/dots_hollow.png` | `f63344ae56f0456cfc67e4fc3828f2152574679d1114ea53dbc9575bf51600b5` |
