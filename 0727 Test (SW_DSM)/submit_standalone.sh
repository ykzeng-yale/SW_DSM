#!/bin/bash
#SBATCH --job-name=wdsm_standalone
#SBATCH --output=wdsm_standalone_%j.out
#SBATCH --error=wdsm_standalone_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=36
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --partition=day

module load R/4.4.1

echo "Running on node: $(hostname)"
echo "Job started at: $(date)"
echo "Working directory: $(pwd)"
echo "Files in directory:"
ls -la

Rscript compare_methods_pate_retrospective_standalone.R

echo "Job completed at: $(date)"
