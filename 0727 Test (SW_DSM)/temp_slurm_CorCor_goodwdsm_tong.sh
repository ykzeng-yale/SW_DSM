#!/bin/bash
#SBATCH --job-name=CorCor_100rep_goodwdsm
#SBATCH --output=CorCor_100rep_goodwdsm_%j.out
#SBATCH --error=CorCor_100rep_goodwdsm_%j.err
#SBATCH --time=04:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=14
#SBATCH --mem-per-cpu=4G
#SBATCH --account=tong

echo "=========================================="
echo "Starting 100-REP CorCor with Good Overlap WDSM"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Starting at: $(date)"
echo "Working directory: /gpfs/gibbs/project/tong/yz2324/pooroverlap_goodwdsm_100rep_20250824_125101/CorCor"

cd /gpfs/gibbs/project/tong/yz2324/pooroverlap_goodwdsm_100rep_20250824_125101/CorCor

# Load R module
module load R/4.3.2-foss-2022b

# Run R script
Rscript compare_methods_pate_retrospective_mccleary_100reps_GOODOVERLAP_WDSM.R

echo ""
echo "Completed at: $(date)"
echo "=========================================="
