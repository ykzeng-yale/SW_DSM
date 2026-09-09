#!/bin/bash
#SBATCH --job-name=FINAL_CorMis_100
#SBATCH --output=pate_retrospective_pooroverlap_CorMis_M5_100reps_final_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_CorMis_M5_100reps_final_%j.err
#SBATCH --account=tong
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorMis_100reps_FINAL

# Record start time
echo "============================================================"
echo "FINAL VERSION - Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: tong"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: CorMis (Day Partition, M=5, 100 Reps - FINAL)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"
echo ""
echo "Implementation Details:"
echo "1. DSM: X for PS model, model.pg='linpred' with lp.pg for PG model"
echo "2. PS/PG matching: Only covariate changes via interaction term"
echo "3. Truly independent PS and PG specifications"
echo ""
echo "Expected Results (CorCor):"
echo "- WDSM: <1% bias, ~95% coverage"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "============================================================"

# Load R module
module load R

# Run the final R script
echo "Starting FINAL R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
