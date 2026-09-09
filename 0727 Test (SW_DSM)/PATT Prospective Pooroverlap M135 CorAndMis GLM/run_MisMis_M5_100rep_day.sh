#!/bin/bash
#SBATCH --job-name=MisMis_M5_100rep
#SBATCH --output=MisMis_M5_100rep_%j.out
#SBATCH --error=MisMis_M5_100rep_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G

# Load R module
module load R/4.3.0-foss-2022b

echo "============================================================"
echo "PATT COMPARISON: M=5 Only, 100 Replications, Model Spec: MisMis (POOR OVERLAP)"
echo "DAY PARTITION - 22 HOUR TIMEOUT - 100 REPLICATIONS"
echo "============================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Hostname: $(hostname)"
echo "Start time: $(date)"
echo "Working directory: $(pwd)"
echo "CPUs requested: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8GB"
echo "============================================================"

# Run R script
echo "Starting PATT comparison for MisMis M=5 100rep (Poor Overlap) at: $(date)"
Rscript comprehensive_patt_comparison_MisMis_M5_100rep.R

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
