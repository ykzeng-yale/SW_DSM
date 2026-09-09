#!/bin/bash
#SBATCH --job-name=MisMis_bouchet
#SBATCH --output=output_MisMis_%j.txt
#SBATCH --error=error_MisMis_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=4G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load R module
module load R/4.3.2-foss-2022b || module load R/4.4.1-foss-2022b || module load R

cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_bouchet_m135_mismis_final

# Set environment variable for scenario
export SCENARIO="MisMis"
export SLURM_CPUS_PER_TASK=64

# Copy dsmatch-master if not present
if [ ! -d "dsmatch-master" ]; then
    if [ -d "/gpfs/gibbs/project/tong/yz2324/dsmatch-master" ]; then
        cp -r /gpfs/gibbs/project/tong/yz2324/dsmatch-master .
    else
        echo "Warning: dsmatch-master not found - needs manual upload"
    fi
fi

# Run the R script
echo "Starting R script for MisMis on Bouchet at $(date)"
echo "Using ${SLURM_CPUS_PER_TASK} cores"
Rscript compare_methods_pate_retrospective_bouchet.R
echo "Completed R script for MisMis at $(date)"
