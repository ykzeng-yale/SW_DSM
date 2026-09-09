#!/usr/bin/env bash
# Submit with afterok:<complete-production-array-id>; keep outputs separate.
# Required: WDSM_ANALYSIS_REPO, WDSM_RUN_INPUT, WDSM_FINAL_OUTPUT.
#SBATCH --job-name=wdsm_final_artifacts
#SBATCH --cpus-per-task=1
#SBATCH --mem=12G
#SBATCH --time=02:00:00
#SBATCH --output=wdsm_final_artifacts_%j.out
#SBATCH --error=wdsm_final_artifacts_%j.err
set -euo pipefail
: "${WDSM_ANALYSIS_REPO:?Set frozen analysis checkout}"
: "${WDSM_RUN_INPUT:?Set complete final production output}"
: "${WDSM_FINAL_OUTPUT:?Set new final artifact directory}"
if [[ -n "${WDSM_R_MODULE:-}" ]]; then module load "$WDSM_R_MODULE"; fi
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
Rscript --vanilla "$WDSM_ANALYSIS_REPO/Tables/summarize_wdsm_final.R" \
  --input "$WDSM_RUN_INPUT" --output "$WDSM_FINAL_OUTPUT/summary"
Rscript --vanilla "$WDSM_ANALYSIS_REPO/Tables/generate_wdsm_final_tables.R" \
  --summary "$WDSM_FINAL_OUTPUT/summary" --output "$WDSM_FINAL_OUTPUT/Tables"
Rscript --vanilla "$WDSM_ANALYSIS_REPO/Figures/generate_wdsm_final_figures.R" \
  --summary "$WDSM_FINAL_OUTPUT/summary" --output "$WDSM_FINAL_OUTPUT/Figures"
