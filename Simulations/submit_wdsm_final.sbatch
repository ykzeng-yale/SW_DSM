#!/usr/bin/env bash
# Final PATE/PATT array. Preserve the pilot and validate all 32 cells before production.
# Account/partition are supplied by the caller: sbatch --account=... --partition=... .
# Required: WDSM_REPO, WDSM_DATA_DIR (or WDSM_DATA_FILE), WDSM_OUTPUT_DIR.
# Pilot is the default (5 sample replicates); production: WDSM_PILOT=0 WDSM_REPS=1000.
# Optional: WDSM_R_MODULE, WDSM_B, WDSM_START, WDSM_END, WDSM_RESUME, WDSM_RETRY_FAILED.
# Resource directives can be overridden with sbatch flags. Logs appear in the submission directory.
#SBATCH --job-name=wdsm_final
#SBATCH --array=0-31
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=wdsm_final_%A_%a.out
#SBATCH --error=wdsm_final_%A_%a.err

set -euo pipefail
: "${WDSM_REPO:?Set WDSM_REPO to the corrected repository checkout}"
: "${WDSM_OUTPUT_DIR:?Set WDSM_OUTPUT_DIR to a new rerun directory}"
if [[ -z "${WDSM_DATA_DIR:-}" && -z "${WDSM_DATA_FILE:-}" ]]; then
  printf '%s\n' 'Set WDSM_DATA_DIR or WDSM_DATA_FILE to the verified population input.' >&2
  exit 2
fi
if [[ -n "${WDSM_R_MODULE:-}" ]]; then
  module load "$WDSM_R_MODULE"
fi
command -v Rscript >/dev/null || { printf '%s\n' 'Load an R module or set WDSM_R_MODULE.' >&2; exit 2; }

task_id="${SLURM_ARRAY_TASK_ID:?Submit this script as an array job}"
if [[ ! "$task_id" =~ ^[0-9]+$ ]] || (( task_id < 0 || task_id > 31 )); then
  printf '%s\n' 'SLURM_ARRAY_TASK_ID must be between 0 and 31.' >&2
  exit 2
fi
estimands=(PATE PATT)
designs=(retrospective prospective)
overlaps=(GoodOverlap PoorOverlap)
scenarios=(CorCor MisCor CorMis MisMis)
export WDSM_ESTIMAND="${estimands[$((task_id / 16))]}"
export WDSM_DESIGN="${designs[$(((task_id % 16) / 8))]}"
export WDSM_OVERLAP="${overlaps[$(((task_id % 8) / 4))]}"
export WDSM_SCENARIO="${scenarios[$((task_id % 4))]}"
export WDSM_PILOT="${WDSM_PILOT:-1}"
export WDSM_CORES="${SLURM_CPUS_PER_TASK:-1}"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1

printf 'Cell: %s / %s / %s / %s; job %s; pilot=%s\n' \
  "$WDSM_ESTIMAND" "$WDSM_DESIGN" "$WDSM_OVERLAP" "$WDSM_SCENARIO" "$SLURM_JOB_ID" "$WDSM_PILOT"
Rscript --vanilla "$WDSM_REPO/Simulations/rerun_wdsm_final.R"
