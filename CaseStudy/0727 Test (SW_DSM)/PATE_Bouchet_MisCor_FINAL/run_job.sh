#!/bin/bash
#SBATCH --job-name=MisCor_final
#SBATCH --output=output_MisCor_%j.txt
#SBATCH --error=error_MisCor_%j.txt
#SBATCH --account=pi_fl426
#SBATCH --partition=day
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=4G
#SBATCH --time=23:00:00

echo "Job: MisCor | Node: $(hostname) | Time: $(date)"
echo "CPUs: $SLURM_CPUS_PER_TASK | Account: $SLURM_JOB_ACCOUNT"

module load R/4.4.2-gfbf-2024a
export SCENARIO="MisCor"
Rscript compare_methods_pate_retrospective.R

echo "Completed at $(date)"
