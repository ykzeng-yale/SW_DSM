#!/bin/bash
#SBATCH --job-name=tong_MisCor_10rep
#SBATCH --output=tong_MisCor_10rep_%j.out
#SBATCH --error=tong_MisCor_10rep_%j.err
#SBATCH --time=02:00:00
#SBATCH --partition=day
#SBATCH --account=tong
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=8G

# Load R module
module load R/4.3.0-foss-2022b

echo "============================================================"
echo "PATT TEST: M=5, 10 Replications, Model Spec: MisCor (POOR OVERLAP)"
echo "TONG ACCOUNT - DAY PARTITION - 10 REP TEST"
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
echo "Starting PATT test for MisCor M=5 10rep (Poor Overlap) at: $(date)"
Rscript comprehensive_patt_comparison_MisCor_M5_10rep.R

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
