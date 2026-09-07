#!/bin/bash
#SBATCH --job-name=sw_dsm_simulation
#SBATCH --output=results_%j.out
#SBATCH --error=results_%j.err

# ACCOUNT SELECTION (choose one):
#SBATCH --account=pi_gt353    # High priority (0.991 fairshare) - USE THIS!
# #SBATCH --account=pi_fl426   # Alternative account (0.184 fairshare)

# PARTITION OPTIONS (choose based on runtime):
#SBATCH --partition=day        # For jobs < 24 hours
# #SBATCH --partition=week     # For jobs < 7 days
# #SBATCH --partition=bigmem   # For jobs needing > 1TB RAM

# RESOURCE ALLOCATION:
#SBATCH --cpus-per-task=32     # Full node on day partition
#SBATCH --mem=64G              # Memory allocation
#SBATCH --time=23:00:00        # Time limit (23 hrs for day partition)

# Optional GPU allocation (uncomment if needed):
# #SBATCH --partition=gpu_h200
# #SBATCH --gres=gpu:h200:1

echo "=========================================="
echo "Starting job on Bouchet cluster"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Account: $SLURM_JOB_ACCOUNT"
echo "Partition: $SLURM_JOB_PARTITION"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "=========================================="

# Load R module
module load R/4.4.2-gfbf-2024a

# Create working directory if needed
WORK_DIR="/gpfs/gibbs/project/${SLURM_JOB_ACCOUNT}/${USER}/sw_dsm_results"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Copy your R scripts (adjust paths as needed)
cp $HOME/compare_methods*.R .

# Run your R script
Rscript compare_methods_pate_retrospective_mccleary.R

# Save results back to home or project directory
echo "Job completed at $(date)"
echo "Results saved in: $WORK_DIR"





