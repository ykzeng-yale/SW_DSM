#!/bin/bash
#SBATCH --job-name=pate_m5_cormis
#SBATCH --output=pate_m5_cormis_%j.out
#SBATCH --error=pate_m5_cormis_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m135_cormis

# Record start time
echo "============================================================"
echo "Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "============================================================"

# Load R module
module load R/4.3.2-foss-2022b

# Run the R script
echo "Starting R script execution..."
Rscript compare_methods_pate_retrospective_mccleary.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
