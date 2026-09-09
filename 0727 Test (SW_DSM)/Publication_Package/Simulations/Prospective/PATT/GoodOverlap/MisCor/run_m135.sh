#!/bin/bash
#SBATCH --job-name=A10_PGood_MisCor
#SBATCH --output=output_m135_%j.txt
#SBATCH --error=error_m135_%j.txt
#SBATCH --account=pi_gt353
#SBATCH --partition=day_amd
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=5G
#SBATCH --time=23:00:00

echo "PATT 1000-rep M=1,3,5 MisCor Prospective GoodOverlap"
echo "Job: $SLURM_JOB_ID | Node: $(hostname) | CPUs: $SLURM_CPUS_PER_TASK | Start: $(date)"

cd /nfs/roberts/project/pi_gt353/yz2324/PATT_Prospective_GoodOverlap_10TERM/MisCor_M135_1000rep
module load R/4.4.2-gfbf-2024a
export R_LIBS_USER=/nfs/roberts/home/yz2324/R/libs
export SCENARIO="MisCor"

Rscript preprocess_and_run_patt.R

echo "Results:"; ls -lh *.RData 2>/dev/null | grep -v SuperPop
echo "Done: $(date)"
