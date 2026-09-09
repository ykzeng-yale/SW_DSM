#!/usr/bin/env bash
# Submit afterok for both the stabilized array and corrected-main array.
# Final pairing requires the complete main point estimates and ordered sample IDs.
# Required: WDSM_ANALYSIS_REPO, WDSM_RUN_INPUT, WDSM_BASELINE_INPUT,
# WDSM_FINAL_OUTPUT. Keep outputs separate from historical results and raw runs.
#SBATCH --job-name=wdsm_stabilized_outputs
#SBATCH --cpus-per-task=1
#SBATCH --mem=12G
#SBATCH --time=02:00:00
#SBATCH --output=wdsm_stabilized_outputs_%j.out
#SBATCH --error=wdsm_stabilized_outputs_%j.err
set -euo pipefail
: "${WDSM_ANALYSIS_REPO:?Set frozen analysis checkout}"
: "${WDSM_RUN_INPUT:?Set complete stabilized production output}"
: "${WDSM_BASELINE_INPUT:?Set complete corrected-main production output}"
: "${WDSM_FINAL_OUTPUT:?Set new final artifact directory}"
if [[ -n "${WDSM_R_MODULE:-}" ]]; then module load "$WDSM_R_MODULE"; fi
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
Rscript --vanilla "$WDSM_ANALYSIS_REPO/StabilizedWDSM/Tables/summarize_stabilized.R" \
  --input "$WDSM_RUN_INPUT" --baseline-root "$WDSM_BASELINE_INPUT" \
  --output "$WDSM_FINAL_OUTPUT/summary"
Rscript --vanilla "$WDSM_ANALYSIS_REPO/StabilizedWDSM/Tables/generate_performance_outputs.R" \
  --summary "$WDSM_FINAL_OUTPUT/summary" --output "$WDSM_FINAL_OUTPUT/performance"
