# Current case-study analysis — September 17, 2026

The complete local source datasets, reconstructed analysis samples, updated
estimators, all 17 newly estimated comparison rows, full execution records,
verification, and figures are included here.

- [Verified results and interpretation changes](Results/TieCorrection_20260917/README.md)
- [Complete numerical table](Results/TieCorrection_20260917/table.md)
- [Updated combined figure](Results/TieCorrection_20260917/Figures/CaseStudy_Combined_WDSM.pdf)
- [Exact changes from the preceding results](Results/TieCorrection_20260917/comparison_with_previous.csv)
- [Copy-ready application edits](Results/TieCorrection_20260917/manuscript_changes.md)
- [Full source data and reconstruction provenance](provenance/RAW_DATA.md)
- [Complete July 27 folder hydration and checksum verification](provenance/0727_hydration_verification.json)

## Data and corrections

`NSDUH/data/raw/NSDUH_2023.Rdata` contains the full 56,705-person, 2,636-variable
source dataset. `NHANES/data/raw/nhanes_2007_2018.rda` contains the full local
merged 59,842-person, 1,048-variable dataset. Both are exact copies from the
July 27 folder. Every regular file in that folder was fully read and matched
against the preserved snapshot; no iCloud placeholders or substitute data were used.

`prepare_from_raw.R` reproduces the saved original analysis variables and row
order, then excludes three refused/unknown NHANES responses. The corrected
NHANES sample is 3,790; the 167 borderline-diabetes participants remain.
NSDUH remains 17,471, including 1,877 early-marijuana-use participants.

Both case functions and the main/stabilized simulation core now share
recipient-specific randomized boundary-tie selection. The tie seed is separate
from sampling and bootstrap streams. Original matches and reuse coefficients
are fixed during every replication. In cleaned NHANES, M=1/3 have no relevant
ties and M=5 has two tied recipients. At the primary seed, all numerical changes
relative to the old sample are reproduced by the three exclusions alone. NSDUH has substantial
exact ties and its WDSM estimates change under the corrected allocation.

Three primary intervals change whether they include zero. In particular,
NSDUH AMIPY's narrow primary exclusion is sensitive to tie seed: 15/20 additional
seed runs exclude zero and five include zero. These numerical checks do not
prove a discrete-score CLT or replication theorem. See the results discussion
before updating the manuscript's interpretation.

## Reproduce from the full source data

From a committed Git checkout:

```sh
Rscript --vanilla CaseStudy/reproduce_tie_correction.R /path/to/new-case-run
```

Requires R, the comparator packages listed in `R/comparators_final.R`, Python 3
and matplotlib. It independently reconstructs both samples from the full raw
sources, checks the saved data, runs all 17 primary rows and eight paired WDSM
controls, checks every saved record and draw, and renders the figure. A new
output directory is required. Some NSDUH comparator computations require more
than 8 GiB RAM; the Bouchet array requests 32 GiB per task.

For Bouchet use `submit_tie_correction.sbatch` with `WDSM_REPO`,
`WDSM_CODE_COMMIT`, and a new `CASE_OUTPUT_DIR`. Array tasks 0–15 cover all primary
and paired-control results. The full R module plus required comparator packages
must be available. `assemble_tie_correction.R` independently checks all 16 records.
The separate `tie_seed_sensitivity.R` and `assemble_tie_sensitivity.R` reproduce
and verify the 20-seed-per-outcome NSDUH diagnostic.

## Numerical specification

Matching uses probability propensity scores and own-arm prognostic predictions,
with pooled unweighted component standardization. Bias correction uses a
survey-weighted complete quadratic in the corresponding two-dimensional score.
NHANES propensity fits use survey weights; NSDUH propensity fits are unweighted.
The prognostic fits are unweighted within treatment arm. These fitting labels
do not establish the application-specific conditional sampling assumptions.

WDSM uses 200 nuisance-refitted replications, the B-divisor variance, and normal
Wald intervals. Vendor DSM/PGM/PSM retain their fixed-reuse bootstrap, B-1 divisor,
and original 1.96 reporting constant. SW-PSM uses the matched-subclass covariance;
survey and matching weights are combined once. No failed bootstrap draws are omitted.

## Preserved history

`Results/Final_20260917/` is the September 9 numerical baseline repackaged before
this tie/raw-data correction. `assemble_publication.R`, `reproduce.R`,
`rerun_wdsm_final.R`, and the older per-study `run_wdsm_corrected.R` files are
explicitly historical reproduction checks; they retain the original 3,793-person
NHANES sample and row-order tie rule. They do not produce the new final analysis.
The immutable July 27 snapshot remains unchanged.
