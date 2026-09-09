#!/bin/bash
#SBATCH --job-name=tong_m5_miscor_100rep_fixed
#SBATCH --output=pate_retrospective_miscor_100rep_%j.out
#SBATCH --error=pate_retrospective_miscor_100rep_%j.err
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --time=04:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load R module
module load R/4.3.2-foss-2022b

# Navigate to working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_miscor_100rep_fixed

# Run R script
Rscript compare_methods_pate_retrospective_100rep.R
