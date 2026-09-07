#!/bin/bash
#SBATCH --job-name=Poor_CorCor_PROP
#SBATCH --output=pooroverlap_properly_sourced_CorCor_%j.out
#SBATCH --error=pooroverlap_properly_sourced_CorCor_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd /gpfs/gibbs/project/tong/yz2324/pooroverlap_properly_sourced_CorCor_100reps

# Load R module
module load R

echo "=========================================="
echo "Starting PROPERLY_SOURCED CorCor job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Starting at: $(date)"
echo "Working directory: $(pwd)"
echo ""
echo "Files in directory:"
ls -la
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R

echo ""
echo "Completed at: $(date)"
echo "=========================================="
