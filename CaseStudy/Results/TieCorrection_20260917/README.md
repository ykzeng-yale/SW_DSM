# Case-study correction verified September 17, 2026

All 17 primary method/outcome rows were rerun on Bouchet R 4.4.2 from the
complete source datasets recovered from the July 27 folder. No unavailable
placeholder, simulated case-study input, or simplified substitute was used.
Source/data recovery is documented in [RAW_DATA.md](../../provenance/RAW_DATA.md).

## What changed

- **NHANES:** 3,793 → **3,790** observations after excluding three distinct
  refused/unknown responses. All 167 borderline-diabetes records remain.
  The cleaned M=1/3 fits have no allocation-relevant ties; M=5 has two tied
  recipients. At the prespecified primary seed, paired row-order controls
  reproduce every new WDSM number exactly. Thus the reported before/after
  differences at that seed come from preprocessing; this does not assert
  invariance to every possible tie seed.
- **NSDUH:** the original 17,471 participants and 14 binary covariates are unchanged.
  There are 1,276 distinct profiles. Random donor selection is performed separately
  for each recipient at the Mth-distance boundary. Original match sets remain
  fixed during all 200 nuisance-refitted replications.
- The five same-runtime historical WDSM controls reproduce the preceding
  published values. The separate 3,793-person NHANES comparator control reproduces
  all old point estimates within 1e-15; the largest SW-PSM interval difference is
  4.63e-8, a numerical discrepancy far smaller than the preprocessing changes.

## Numerical and interpretation changes

| Analysis | Previous estimate [95% CI] | Updated estimate [95% CI] |
|---|---|---|
| NHANES WDSM M=1 | 0.070467 [0.003999, 0.136935] | 0.097921 [0.043019, 0.152822] |
| NHANES WDSM M=3 | 0.074021 [0.014426, 0.133617] | 0.080989 [0.026621, 0.135357] |
| NHANES WDSM M=5 | 0.074145 [0.014335, 0.133954] | 0.076147 [0.019223, 0.133071] |
| NSDUH AMIPY WDSM M=5 | 0.065414 [-0.004755, 0.135583] | 0.072620 [0.002030, 0.143209] |
| NSDUH SMIPY WDSM M=5 | 0.018153 [-0.016619, 0.052925] | 0.016319 [-0.017500, 0.050139] |

These are not solely last-decimal changes. Three primary intervals change their
zero-exclusion classification: NSDUH AMIPY WDSM and NHANES PSM now exclude zero;
NHANES SW-PSM now includes zero. NHANES WDSM remains positive at every M, and
NSDUH SMIPY continues to include zero. WDSM point estimates in NHANES now decrease
from M=1 to M=5; its SEs are not monotonically decreasing. Application estimates
alone cannot establish which method is closer to an unknown causal truth.

**The NSDUH AMIPY threshold is fragile.** With 20 additional prespecified tie
seeds and the same data and bootstrap stream, AMIPY estimates span 6.939–7.398
percentage points; 15/20 intervals exclude zero and 5/20 include zero. SMIPY
estimates span 1.440–1.819 percentage points and all 20 intervals include zero.
These are algorithmic sensitivity ranges, not confidence intervals or bias
estimates. The primary seed 20260922 was fixed before inspecting results and
was not changed to select a preferred conclusion.

Randomized ties fix the demonstrated row-order concentration. They do not
independently prove a finite-support/discrete-score CLT or replication theorem.
The reported WDSM intervals retain the manuscript's B-divisor Wald procedure;
a theoretical claim extending continuous-score results to NSDUH remains separate.

The separately pasted validation is numerically reconciled at its reported
precision; see [the seed and bootstrap-state comparison](cross_review/README.md).

## Contents and verification

- `results.csv`, `table.md`, `table.tex`, `Figures/`: all 17 newly estimated primary rows.
- `records/`: all 16 execution records, including full WDSM matches/fits, draws,
  propensity diagnostics, source/input hashes, RNG states and runtime metadata.
- `all_25_rerun_rows.csv` and `change_decomposition.csv`: primary fits plus five
  historical controls and three cleaned NHANES/old-tie controls.
- `comparison_with_previous.csv`: exact changes in estimates, SEs and endpoints.
- `all_bootstrap_draws.csv`: 2,600 WDSM and 1,800 comparator draws from the primary
  and paired-control run; no failed draws omitted.
- `independent_checks.csv`: 2,613 checked WDSM propensity fits, B-divisor/Wald,
  match-set and RNG verification.
- `historical_comparator_control/`: the separate old-sample NHANES comparator check.
- `tie_seed_sensitivity/`: all 40 sensitivity fits, 8,000 draws, 8,040 checked
  propensity fits, full seed audit and summaries.
- `manuscript_changes.md`: replacement application text and required figure/table updates.

Source execution commits: `d36607bee407d88c6ceeae64bd2298c182af3362` for the main
case array, `4e4340c` for sensitivity, and `ae13be8` for the historical comparator
control. Subsequent preprocessing documentation removed a no-op recode of
nonexistent sleep codes and added cycle-specific valid-range checks; both
prepared analysis datasets were verified byte-identical to the executed inputs.
The combined figure was visually checked with every CI visible below its legend.

## Reproduce

From a committed Git checkout with R, the comparator packages listed in
`R/comparators_final.R`, Python 3 and matplotlib:

```sh
Rscript --vanilla CaseStudy/reproduce_tie_correction.R /path/to/new-case-run
```

This reads the full raw sources, reconstructs and verifies the prepared data,
runs the 17 primary rows plus eight WDSM controls, checks all records, and renders
the figure. The separate sensitivity scripts reproduce the 40 diagnostic fits.
`CaseStudy/reproduce.R` and `assemble_publication.R` are historical September 9
reproduction commands and intentionally retain the old samples/tie rule.
