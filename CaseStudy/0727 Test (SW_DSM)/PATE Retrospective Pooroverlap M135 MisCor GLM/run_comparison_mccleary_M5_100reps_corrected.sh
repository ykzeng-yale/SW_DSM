#!/bin/bash
#SBATCH --job-name=CORR_MisCor_100
#SBATCH --output=pate_retrospective_pooroverlap_MisCor_M5_100reps_corrected_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_MisCor_M5_100reps_corrected_%j.err
#SBATCH --account=tong
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_100reps_CORRECTED

# Record start time
echo "============================================================"
echo "CORRECTED VERSION - Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: tong"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: MisCor (Day Partition, M=5, 100 Reps - CORRECTED)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"
echo ""
echo "Implementation based on Good Overlap structure:"
echo "1. Source dsmatch files INSIDE worker function"
echo "2. DSM: X_ps for X parameter, X_pg for lp.pg parameter"
echo "3. PG: model.pg='glm' (not 'linpred')"
echo "4. All methods properly handle interaction terms"
echo ""
echo "Expected Results (CorCor):"
echo "- WDSM: <1% bias, ~95% coverage"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "- All unweighted methods should produce results"
echo "============================================================"

# Load R module
module load R

# Run the corrected R script
echo "Starting CORRECTED R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
