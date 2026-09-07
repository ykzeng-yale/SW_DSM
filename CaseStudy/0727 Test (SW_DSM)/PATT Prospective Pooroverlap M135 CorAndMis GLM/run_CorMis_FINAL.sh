#!/bin/bash
#SBATCH --job-name=CorMis_FIN
#SBATCH --output=CorMis_FINAL_%j.out
#SBATCH --error=CorMis_FINAL_%j.err
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

module load R/4.3.2-foss-2022b
cd /gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822
Rscript final_fixed_comprehensive_patt_comparison_CorMis_M5_1000rep.R
