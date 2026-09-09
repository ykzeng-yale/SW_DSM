#!/usr/bin/env bash
# Required: WDSM_REPO, WDSM_CODE_COMMIT, CASE_OUTPUT_DIR, NHANES_INPUT, NSDUH_INPUT.
# The caller supplies an account and partition; participant inputs stay outside GitHub.
#SBATCH --job-name=wdsm_cases_final
#SBATCH --array=0-4
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=wdsm_cases_final_%A_%a.out
#SBATCH --error=wdsm_cases_final_%A_%a.err
set -euo pipefail
: "${WDSM_REPO:?Set frozen source directory}"
: "${WDSM_CODE_COMMIT:?Set frozen source commit}"
: "${CASE_OUTPUT_DIR:?Set isolated output directory}"
: "${NHANES_INPUT:?Set verified original NHANES input}"
: "${NSDUH_INPUT:?Set verified original NSDUH input}"
if [[ -n "${WDSM_R_MODULE:-}" ]]; then module load "$WDSM_R_MODULE"; fi
command -v Rscript >/dev/null || { printf '%s\n' 'Load R or set WDSM_R_MODULE.' >&2; exit 2; }
export CASE_TASK_ID="${SLURM_ARRAY_TASK_ID:?Submit as an array job}"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
Rscript --vanilla "$WDSM_REPO/CaseStudy/rerun_wdsm_final.R"
