#!/bin/bash
#SBATCH --job-name=pate_MisCor_M5_100r
#SBATCH --output=pate_retrospective_pooroverlap_MisCor_M5_100reps_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_MisCor_M5_100reps_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_100reps_lifan

# Record start time
echo "============================================================"
echo "Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: MisCor (Day Partition, M=5, 100 Reps)"
echo "Cores: 20, Memory: 160GB total"
echo "Batch size: 20 replications per batch"
echo "============================================================"

# Load R module
module load R

# Run the R script (M=5, 100 reps version)
echo "Starting R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
