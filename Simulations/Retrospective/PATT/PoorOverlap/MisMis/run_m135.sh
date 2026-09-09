#!/usr/bin/env bash
# Compatibility entry point for PATT / Retrospective / PoorOverlap / MisMis.
# Requires WDSM_OUTPUT_DIR and WDSM_DATA_DIR (or WDSM_DATA_FILE).
# A pilot is the default; set WDSM_PILOT=0 WDSM_REPS=1000 for production.
# Submit with: bash run_m135.sh --account=ACCOUNT --partition=PARTITION
#SBATCH --job-name=wdsm_final_cell
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
set -euo pipefail
entry_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export WDSM_REPO="${WDSM_REPO:-$(cd -- "$entry_dir/../../../../.." && pwd)}"
: "${WDSM_OUTPUT_DIR:?Set WDSM_OUTPUT_DIR to a new rerun directory}"
if [[ -z "${WDSM_DATA_DIR:-}" && -z "${WDSM_DATA_FILE:-}" ]]; then
  printf '%s\n' 'Set WDSM_DATA_DIR or WDSM_DATA_FILE to the verified population input.' >&2
  exit 2
fi
export WDSM_PILOT="${WDSM_PILOT:-1}"
if [[ -n "${SLURM_JOB_ID:-}" ]]; then
  export SLURM_ARRAY_TASK_ID=23
  exec bash "$WDSM_REPO/Simulations/submit_wdsm_final.sbatch"
fi
for arg in "$@"; do
  if [[ "$arg" == --array* || "$arg" == -a* ]]; then
    printf '%s\n' 'This entry point fixes one cell. Use submit_wdsm_final.sbatch for a different array.' >&2
    exit 2
  fi
done
exec sbatch --array=23 "$@" "$WDSM_REPO/Simulations/submit_wdsm_final.sbatch"
