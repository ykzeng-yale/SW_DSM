#!/bin/bash
#SBATCH --job-name=CorCor_bouchet
#SBATCH --output=output_CorCor_%j.txt
#SBATCH --error=error_CorCor_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=4G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load R module (check if same module system as McCleary)
module load R/4.3.2-foss-2022b || module load R

cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_bouchet_m135_corcor_final

# Set environment variable for scenario
export SCENARIO="CorCor"
export SLURM_CPUS_PER_TASK=64

# Copy dsmatch-master if not present
if [ ! -d "dsmatch-master" ]; then
    if [ -d "/gpfs/gibbs/project/tong/yz2324/dsmatch-master" ]; then
        cp -r /gpfs/gibbs/project/tong/yz2324/dsmatch-master .
    else
        echo "ERROR: dsmatch-master not found"
        exit 1
    fi
fi

# Run the R script
echo "Starting R script for CorCor on Bouchet at $(date)"
echo "Using ${SLURM_CPUS_PER_TASK} cores"
Rscript compare_methods_pate_retrospective_bouchet.R
echo "Completed R script for CorCor at $(date)"
