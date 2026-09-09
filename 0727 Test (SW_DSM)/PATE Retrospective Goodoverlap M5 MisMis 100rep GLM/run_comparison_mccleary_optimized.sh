#!/bin/bash
#SBATCH --job-name=m5_mismis_100rep_fix
#SBATCH --output=mismis_100rep_fixed_%j.out
#SBATCH --error=mismis_100rep_fixed_%j.err
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=10:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load required modules
module load R/4.3.2-foss-2022b

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/m5_mismis_100rep_fixed

# Print diagnostic info
echo "============================================"
echo "Job Info:"
echo "Scenario: MisMis"
echo "JobID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_CPU GB per CPU"
echo "Time: $(date)"
echo "Working Directory: $(pwd)"
echo "============================================"

# Run R script
Rscript compare_methods_pate_retrospective_mccleary.R

# Print completion info
echo "============================================"
echo "Job completed at: $(date)"
echo "Exit code: $?"
echo "============================================"
