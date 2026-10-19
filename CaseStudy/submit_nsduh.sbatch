#!/usr/bin/env bash
# sbatch --account=... --partition=day CaseStudy/submit_nsduh.sbatch
# Required: WDSM_REPO, WDSM_CASE_PREPARED_DIR, CASE_OUTPUT_DIR.
# The full R module includes the comparator dependencies; R_LIBS_USER may add them.
#SBATCH --job-name=wdsm_nsduh
#SBATCH --array=3-4,14-15
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=nsduh_%A_%a.out
#SBATCH --error=nsduh_%A_%a.err
set -euo pipefail
: "${WDSM_REPO:?}"
: "${CASE_OUTPUT_DIR:?}"
: "${WDSM_CASE_PREPARED_DIR:?}"
module load "${WDSM_R_MODULE:-R/4.4.2-gfbf-2024a}"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1
export CASE_TASK_ID="${SLURM_ARRAY_TASK_ID:?}"
Rscript --vanilla "$WDSM_REPO/CaseStudy/analyze_nsduh.R" "$CASE_OUTPUT_DIR" "$CASE_TASK_ID"
