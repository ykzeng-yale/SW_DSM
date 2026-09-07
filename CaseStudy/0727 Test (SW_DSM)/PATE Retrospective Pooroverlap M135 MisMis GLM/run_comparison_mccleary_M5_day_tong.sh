#!/bin/bash
#SBATCH --job-name=pate_poor_MisMis_M5_tong
#SBATCH --output=pate_retrospective_pooroverlap_MisMis_M5_tong_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_MisMis_M5_tong_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --account=tong
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_day_tong

# Record start time
echo "============================================================"
echo "Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: MisMis (Day Partition, M=5 Only)"
echo "Account: tong"
echo "============================================================"

# Load R module
module load R

# Run the R script (M=5 version)
echo "Starting R script execution (M=5 only, tong account)..."
Rscript compare_methods_pate_retrospective_mccleary_M5.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
