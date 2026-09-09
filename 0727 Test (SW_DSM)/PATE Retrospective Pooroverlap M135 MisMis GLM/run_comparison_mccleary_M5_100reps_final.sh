#!/bin/bash
#SBATCH --job-name=FINAL_MisMis
#SBATCH --output=pate_retrospective_pooroverlap_MisMis_M5_100reps_final_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_MisMis_M5_100reps_final_%j.err
#SBATCH --account=tong
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_100reps_FINAL

# Record start time
echo "============================================================"
echo "FINAL VERSION - Job started at: $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: tong"
echo "Node: $HOSTNAME"
echo "Working directory: $(pwd)"
echo "Scenario: MisMis (Day Partition, M=5, 100 Reps - FINAL)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"
echo ""
echo "Key fixes applied:"
echo "1. ✅ REMOVED M parameter from all dsmatchATE calls"
echo "2. ✅ NO individual timeouts (job has 23 hour limit)"
echo "3. ✅ Source dsmatch files INSIDE worker"
echo "4. ✅ DSM: X_ps for X, X_pg for lp.pg"
echo "5. ✅ PG: model.pg='glm'"
echo "6. ✅ Matching Good Overlap CORRECTED exactly"
echo ""
echo "Expected Results (CorCor):"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "- PG: ~2-3% bias, ~93-95% coverage"
echo "- PS: ~2-3% bias, ~93-95% coverage"
echo "- PS Weighted: ~1-2% bias, ~94-96% coverage"
echo "- WDSM: <1% bias, ~95% coverage"
echo "============================================================"

# Load R module
module load R

# Run the R script
echo "Starting R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: $(date)"
echo "============================================================"
