#!/bin/bash
#SBATCH --job-name=CorMis_final
#SBATCH --output=output_CorMis_%j.txt
#SBATCH --error=error_CorMis_%j.txt
#SBATCH --account=pi_fl426
#SBATCH --partition=day
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=4G
#SBATCH --time=23:00:00

echo "Job: CorMis | Node: $(hostname) | Time: $(date)"
echo "CPUs: $SLURM_CPUS_PER_TASK | Account: $SLURM_JOB_ACCOUNT"

module load R/4.4.2-gfbf-2024a
export SCENARIO="CorMis"
Rscript compare_methods_pate_retrospective.R

echo "Completed at $(date)"
