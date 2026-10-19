# Case-study analyses

[Results/Publication](Results/Publication/) contains the 17 final estimates,
their standard errors and confidence intervals, a LaTeX table, and the combined
figure. NHANES uses 3,783 participants; NSDUH uses 17,471. The appendix's NSDUH
tie-seed sensitivity results are in `Results/Publication/tie_seed_sensitivity/`.

## Data and software

Participant data and fitted objects are not distributed. Set
`WDSM_CASE_DATA_DIR` to an external directory containing these exact analysis
workspaces (either directly or in `<study>/data/raw/`):

| File | R object | Dimensions | MD5 |
|---|---|---|---|
| `nhanes_2007_2018.rda` | `nhanes_2007_2018` | 59,842 × 1,048 | `affadc09f1c6390c5e546281cae5bd08` |
| `NSDUH_2023.Rdata` | `data` | 56,705 × 2,636 | `a2736da9213ec34c0717475dcb96c5a0` |

Survey sources are available from [NHANES](https://www.cdc.gov/nchs/nhanes/)
and [SAMHSA](https://www.samhsa.gov/data/). The merged workspaces above are
available from the authors; this repository does not build them from individual
survey downloads. Keep all preparation and fitting outputs outside the repository.

Use R with Matching, boot, MatchIt, optmatch, marginaleffects and sandwich,
and Python 3 with matplotlib for figures. The analyses used R 4.4.2 (NSDUH)
and R 4.4.3 (NHANES).
Some NSDUH comparator fits require more than 8 GiB of memory.

## Run the final analyses

From the repository root, using new output directories:

```sh
export WDSM_CASE_DATA_DIR=/path/to/source-data
Rscript --vanilla CaseStudy/prepare_from_raw.R /path/to/prepared-data
export WDSM_CASE_PREPARED_DIR=/path/to/prepared-data
Rscript --vanilla CaseStudy/analyze_nhanes.R /path/to/nhanes-output
Rscript --vanilla CaseStudy/analyze_nsduh.R /path/to/nsduh-output
Rscript --vanilla CaseStudy/assemble_publication.R /path/to/nhanes-output /path/to/publication-output /path/to/nsduh-output/results.csv
python3 CaseStudy/Figures/plot_case_studies.py --results /path/to/publication-output/results.csv --output /path/to/publication-figures
```

The NHANES analysis excludes recorded pregnancies, uses categorical sex,
race/ethnicity, education and never/former/current smoking, and combines the two
cycles with `WTMEC2YR/2`. NSDUH uses `ANALWT2_C` and the covariates constructed
in `NSDUH/prepare_nsduh.R`. The resampled methods use 200 draws for NHANES and
200 for NSDUH. Each method starts from seed 2024; WDSM boundary-tie seeds are
20260917 + M. SW-PSM instead uses matched-subclass covariance.

For Slurm, `submit_nsduh.sbatch` runs the same four NSDUH tasks separately;
after they finish, run `assemble_nsduh.R /path/to/nsduh-output` before combining
the studies. Set the environment variables listed in the Slurm script.

For the appendix tie-seed sensitivity, set `CASE_SENSITIVITY_OUTPUT`, select
`CASE_TASK_ID` 0–39, and run `tie_seed_sensitivity.R`; then run
`assemble_tie_sensitivity.R INPUT_DIR NEW_OUTPUT_DIR`. These 20 additional seeds
per outcome do not replace the primary analysis seed.
