# Publication simulation results

[`summary/wdsm_final_metrics.csv`](summary/wdsm_final_metrics.csv) contains
224 method-by-setting summaries: 32 combinations of estimand, sampling
design, overlap, and score specification, with 1,000 sample replications
and bootstrap size B=200. WDSM uses M=1, 3, and 5. The four appendix tables
are in [`Tables/`](Tables/); the manuscript figure is in [`Figures/`](Figures/).
These numerical results are unchanged from the completed production run.

## Recreate tables and the manuscript figure

From the repository root, choose new output directories. Rendering requires
R, `ggplot2`, `dplyr`, `gridExtra`, and `cowplot`.

```sh
Rscript --vanilla Tables/generate_wdsm_final_tables.R \
  --summary Results/Publication/summary --output /path/to/new-tables
Rscript --vanilla Figures/generate_wdsm_final_figures.R \
  --summary Results/Publication/summary --output /path/to/new-figures
```

The renderers verify the CSV against its saved summary manifest. Tables
report signed relative bias, relative efficiency, and coverage; the figure
uses absolute relative bias.

## Recompute summaries or run the simulations

The [production-record archive](https://github.com/ykzeng-yale/SW_DSM/releases/tag/tie-corrected-simulations-20260917)
contains the completed original-WDSM records in `production_68e1445/`.
Download its six `WDSM_Ties_20260917.tar.gz.part000` through `part005` files,
verify `SHA256SUMS.txt`, concatenate them in order, and extract the archive.
Then verify its `release_archive/CONTENT_SHA256SUMS.txt` before summarizing:

```sh
Rscript --vanilla Tables/summarize_wdsm_final.R \
  --input /path/to/restored/production_68e1445 \
  --output /path/to/new-summary --strict true
```

A fresh run needs the two fixed simulated population files from the
[population-input release](https://github.com/ykzeng-yale/SW_DSM/releases/tag/final-simulations-20260909).
Their SHA-256 values are:

- `SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData`: `f31b8094adccd6328f147308c8ef4de6df8f95ae19d49d3067ad2e0fabe17133`
- `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`: `05651582c7e84792182b9cc44c6e02e12fff292b02e2bd0234794ffaf1964b4e`

```sh
Rscript --vanilla Simulations/run_simulations.R --help
Rscript --vanilla Simulations/run_simulations.R \
  --data-dir /path/to/populations --output /path/to/new-run \
  --estimand PATE --design retrospective --overlap GoodOverlap \
  --scenario CorCor --reps 1000 --B 200
```

Repeat for PATE/PATT, retrospective/prospective, good/poor overlap, and
CorCor/MisCor/CorMis/MisMis, or use `Simulations/submit_wdsm_final.sbatch`
for the 32-setting Slurm array. All estimators use the same sampled records;
random streams and numerical settings are saved with each run. The original
execution used R 4.4.2. Required analysis packages are listed by the driver.
