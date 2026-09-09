#!/usr/bin/env bash
# Submit with --dependency=afterany:<production-array-job> so failures are audited too.
# Required: WDSM_SUMMARY_CODE, WDSM_RERUN_INPUT, WDSM_BASELINE, WDSM_SUMMARY_OUTPUT.
# Account and partition are supplied by the caller; outputs must be a fresh directory.
#SBATCH --job-name=wdsm_pate_summary
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=wdsm_pate_summary_%j.out
#SBATCH --error=wdsm_pate_summary_%j.err

set -euo pipefail
: "${WDSM_SUMMARY_CODE:?Set WDSM_SUMMARY_CODE to the analysis code directory}"
: "${WDSM_RERUN_INPUT:?Set WDSM_RERUN_INPUT to the completed rerun root}"
: "${WDSM_BASELINE:?Set WDSM_BASELINE to the archived PATE result directory}"
: "${WDSM_SUMMARY_OUTPUT:?Set WDSM_SUMMARY_OUTPUT to a fresh output directory}"
if [[ -n "${WDSM_R_MODULE:-}" ]]; then
  module load "$WDSM_R_MODULE"
fi
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla "$WDSM_SUMMARY_CODE/Tables/summarize_pate_wald.R" \
  --input "$WDSM_RERUN_INPUT" --baseline "$WDSM_BASELINE" \
  --output "$WDSM_SUMMARY_OUTPUT" --strict-complete true
