#!/bin/bash
#SBATCH --job-name=tong_CorMis_M5
#SBATCH --output=tong_CorMis_M5_%j.out
#SBATCH --error=tong_CorMis_M5_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --account=tong
#SBATCH --nodes=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=8G

# Load R module
module load R/4.3.0-foss-2022b

echo "============================================================"
echo "PATT COMPARISON: M=5 Only, Model Spec: CorMis (POOR OVERLAP)"
echo "DAY PARTITION - TONG ACCOUNT - 22 HOUR TIMEOUT"
echo "============================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: $SLURM_JOB_ACCOUNT"
echo "Hostname: $(hostname)"
echo "Start time: $(date)"
echo "Working directory: $(pwd)"
echo "CPUs requested: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8GB"
echo "============================================================"

# Run R script
echo "Starting PATT comparison for CorMis M=5 Only (Poor Overlap) at: $(date)"
Rscript comprehensive_patt_comparison_CorMis_M5.R

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
