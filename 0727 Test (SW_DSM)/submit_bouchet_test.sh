#!/bin/bash
################################################################################
# Bouchet Test Job Submission Script
# Uses pi_gt353 account with 0.991 fairshare for instant queue access
################################################################################

# SLURM Parameters
#SBATCH --job-name=bouchet_test
#SBATCH --output=bouchet_test_%j.out
#SBATCH --error=bouchet_test_%j.err
#SBATCH --account=pi_gt353        # HIGH PRIORITY ACCOUNT (0.991 fairshare!)
#SBATCH --partition=day           # Day partition for quick test
#SBATCH --cpus-per-task=4         # Just 4 CPUs for test
#SBATCH --mem=8G                  # 8GB RAM for test
#SBATCH --time=00:10:00           # 10 minutes is plenty

echo "=========================================="
echo "Bouchet Cluster Test Job Starting"
echo "=========================================="
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: $SLURM_JOB_ACCOUNT (FairShare: 0.991)"
echo "=========================================="
echo ""

# Load R module
module load R/4.4.2-gfbf-2024a

# Show loaded modules
echo "Loaded modules:"
module list 2>&1
echo ""

# Create working directory if needed
WORK_DIR="/gpfs/gibbs/project/pi_gt353/yz2324/bouchet_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working directory: $WORK_DIR"
echo ""

# Copy test script to working directory
cp $HOME/bouchet_test_job.R . 2>/dev/null || echo "Note: Test script will be uploaded"

# Run the test
echo "Starting R test job..."
echo "=========================================="
Rscript bouchet_test_job.R

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Test completed successfully!"
    echo "Results saved in: $WORK_DIR"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "✗ Test failed - check error messages above"
    echo "=========================================="
fi

echo ""
echo "Job completed at: $(date)"
echo "Total runtime: $SECONDS seconds"
