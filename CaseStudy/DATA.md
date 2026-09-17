# Case-study source and historical inputs

The **current complete source datasets and corrected analysis samples** are
documented in [provenance/RAW_DATA.md](provenance/RAW_DATA.md). They are included
in `NHANES/data/raw/` and `NSDUH/data/raw/`; the current reconstruction yields
NHANES n=3,790 and NSDUH n=17,471. All 17 current comparison rows were rerun.

## Preserved September 9 analytic inputs

The remainder describes the earlier frozen reproduction baseline, not the
current missing-code/tie-corrected analysis.

These are the exact saved analytic inputs used by the September 9, 2026 Bouchet
verification, included at the author's request on September 17. The SHA-256 and
MD5 identities are recorded in `data_manifest.json` and `case_rerun_config.R`.
The runner rejects changed inputs. No download or absolute local path is needed.

| File | Analytic sample | Treatment |
|---|---|---|
| `NHANES/data/WDSM_M1_M3_M5_ANALYSIS_10.rda` | 3,793 adults; 1,002 treated | sleep below 7 hours |
| `NSDUH/data/complete_case_data.rds` | 17,471 adults; 1,877 treated | saved `early_mj_use` |

## NHANES

The R workspace contains `data_prep` (3,793 rows, 1,048 columns) and a historical
`wdsm_res` object. **Only `data_prep` is read. The historical fit is not a current
result and must not be used for reporting.** Keeping the original container
preserves its previously verified checksum.

The saved sample has survey-cycle codes 9 and 10 (1,935 and 1,858 rows), corresponding
to 2015–2018. Outcome: `lbxgh`; treatment: `sld012 < 7`; weights: `wtmec2yr`.
Covariates, in the recorded order: `ridageyr`, `riagendr`, `ridreth1`, `dmdeduc2`,
`indfmpir`, `bmxbmi`, `smq020`. The saved sample already applies the age 40–70,
reported-diabetes and complete-case restrictions. Numeric category/special-code
handling is preserved, including refused/unknown codes; this release is not a
new recoding or population-selection analysis.

## NSDUH

The RDS contains the original 17,471-row, 27-column analytic data frame. The
recorded treatment, outcomes `AMIPY`/`SMIPY`, and `ANALWT2_C` survey weights are
unchanged. `NSDUH/prepare_nsduh.R` reconstructs all 14 model covariates and checks
the shared two-outcome complete-case sample. `QUESTID2` is the source public-use
record identifier; no names or contact information are added.

## Scope and provenance

These are saved analytic extracts from the local `Case Study Data/NHANES/` and
`Case Study Data/SAMHSA 0914/Analysis/Results/03_analytic_dataset/` directories.
They are sufficient to reproduce all five corrected WDSM fits. This package
does not claim to reconstruct these extracts from all original survey downloads.
The input identity, rather than folder modification date, establishes that they
are the files used on Bouchet.

The other 12 estimates in the combined comparison remain the frozen September 9
comparator results. `reference/comparators_20260909.csv` preserves their full
precision and variance descriptions. `row_provenance.csv` in each finalized run
explicitly distinguishes these retained rows from newly rerun WDSM rows.
