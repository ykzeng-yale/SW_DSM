#!/bin/bash
#SBATCH --job-name=patt_CorCor_Poor
#SBATCH --output=patt_CorCor_Poor_%j.out
#SBATCH --error=patt_CorCor_Poor_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=8G

# Load R module
module load R/4.3.0-foss-2022b

echo "============================================================"
echo "COMPREHENSIVE PATT COMPARISON: M=1,3,5, Model Spec: CorCor (POOR OVERLAP)"
echo "============================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Hostname: $(hostname)"
echo "Start time: $(date)"
echo "Working directory: $(pwd)"
echo "CPUs requested: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8GB"
echo "============================================================"

# Run R script
echo "Starting PATT comparison for CorCor (Poor Overlap) at: $(date)"
Rscript comprehensive_patt_comparison_CorCor.R

# Check exit status
if [ $? -eq 0 ]; then
    echo "============================================================"
    echo "Job completed successfully at: $(date)"
    echo "============================================================"
else
    echo "============================================================"
    echo "Job failed at: $(date)"
    echo "============================================================"
    exit 1
fi
