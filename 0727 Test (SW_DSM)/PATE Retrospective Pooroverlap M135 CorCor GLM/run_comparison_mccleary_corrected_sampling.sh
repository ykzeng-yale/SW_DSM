#!/bin/bash
#SBATCH --job-name=Poor_CorCor_CORR
#SBATCH --output=pooroverlap_corrected_CorCor_%j.out
#SBATCH --error=pooroverlap_corrected_CorCor_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G

cd "$SLURM_SUBMIT_DIR"

# Load R module
module load R

echo "=========================================="
echo "Starting CORRECTED SAMPLING CorCor job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Starting at: $(date)"
echo "Working directory: $(pwd)"
echo ""

# Run the R script with corrected sampling
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R

echo ""
echo "Completed at: $(date)"
echo "=========================================="
