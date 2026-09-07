#!/bin/bash
#SBATCH --job-name=pate_m5_mismis_tong
#SBATCH --output=pate_m5_mismis_tong_%j.out
#SBATCH --error=pate_m5_mismis_tong_%j.err
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load required modules
module load R/4.3.2-foss-2022b

# Set up environment
export OMP_NUM_THREADS=1
export R_LIBS_USER=/gpfs/gibbs/project/tong/yz2324/R_libs

# Run the R script
echo "Starting PATE Retrospective M5 mismis comparison at $(date)"
echo "Running on node: $(hostname)"
echo "Using account: tong"
echo "Number of CPUs: ${SLURM_CPUS_PER_TASK}"
echo "Memory per CPU: 8G"

Rscript compare_methods_pate_retrospective_mccleary.R

echo "Completed at $(date)"
