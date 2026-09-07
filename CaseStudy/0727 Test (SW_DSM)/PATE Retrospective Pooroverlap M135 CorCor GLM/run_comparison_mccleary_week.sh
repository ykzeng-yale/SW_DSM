#!/bin/bash
#SBATCH --job-name=pate_poor_CorCor_wk
#SBATCH --output=pate_retrospective_pooroverlap_CorCor_week_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_CorCor_week_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=7-00:00:00
#SBATCH --partition=week
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorCor_week

# Record start time
echo "============================================================"
echo "Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: CorCor (Week Partition, Full M=1,3,5)"
echo "============================================================"

# Load R module
module load R

# Run the R script
echo "Starting R script execution..."
Rscript compare_methods_pate_retrospective_mccleary.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
