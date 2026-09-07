#!/bin/bash
#SBATCH --job-name=lifan_CorMis_10rep
#SBATCH --output=lifan_CorMis_10rep_%j.out
#SBATCH --error=lifan_CorMis_10rep_%j.err
#SBATCH --time=2:00:00
#SBATCH --partition=day
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=8G
#SBATCH --account=li_fan

echo "============================================================"
echo "PATT TEST: M=5, 10 Replications, Model Spec: CorMis (POOR OVERLAP)"
echo "LI_FAN ACCOUNT - DAY PARTITION - 10 REP TEST"
echo "============================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: $SLURM_JOB_ACCOUNT"
echo "Hostname: $HOSTNAME"
echo "Start time: $(date)"
echo "Working directory: $PWD"
echo "CPUs requested: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8GB"
echo "============================================================"
echo "Starting PATT test for CorMis M=5 10rep (Poor Overlap) at: $(date)"
echo ""

module load R
Rscript comprehensive_patt_comparison_CorMis_M5_10rep.R

echo ""
echo "============================================================"
if [ $? -eq 0 ]; then
    echo "Job completed successfully at: $(date)"
else
    echo "Job failed at: $(date)"
fi
echo "============================================================"
