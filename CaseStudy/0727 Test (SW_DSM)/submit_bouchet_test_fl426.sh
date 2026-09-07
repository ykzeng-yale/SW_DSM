#!/bin/bash
################################################################################
# Bouchet Test Job - pi_fl426 Account (li_fan mapping)
# Testing the alternative account with 0.184 fairshare
################################################################################

# SLURM Parameters
#SBATCH --job-name=test_fl426
#SBATCH --output=test_fl426_%j.out
#SBATCH --error=test_fl426_%j.err
#SBATCH --account=pi_fl426        # Alternative account (0.184 fairshare)
#SBATCH --partition=day           # Day partition
#SBATCH --cpus-per-task=8         # 8 CPUs for test
#SBATCH --mem=16G                 # 16GB RAM
#SBATCH --time=00:15:00           # 15 minutes

echo "=========================================="
echo "Bouchet Test - pi_fl426 Account"
echo "=========================================="
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "Account: $SLURM_JOB_ACCOUNT (FairShare: 0.184)"
echo "=========================================="
echo ""

# Load R module
module load R/4.4.2-gfbf-2024a

# Show environment
echo "Environment Information:"
echo "  CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "  Memory allocated: $SLURM_MEM_PER_NODE MB"
echo "  Partition: $SLURM_JOB_PARTITION"
echo ""

# Create working directory for this account
WORK_DIR="/gpfs/gibbs/project/pi_fl426/yz2324"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working directory: $WORK_DIR"
echo ""

# Quick R test with more cores
Rscript -e "
cat('================================================================================\n')
cat('R TEST FOR PI_FL426 ACCOUNT\n')
cat('================================================================================\n\n')

cat('R Version:', R.version.string, '\n')
cat('Number of cores detected:', parallel::detectCores(), '\n')
cat('Account:', Sys.getenv('SLURM_JOB_ACCOUNT'), '\n\n')

# Test parallel computation with 8 cores
library(parallel)
n_cores <- as.integer(Sys.getenv('SLURM_CPUS_PER_TASK', '8'))
cat('Running parallel test with', n_cores, 'cores\n')

start <- Sys.time()
results <- mclapply(1:n_cores, function(x) {
  # Simulate some work
  m <- matrix(rnorm(1000*1000), 1000, 1000)
  sum(eigen(m)\$values)
}, mc.cores = n_cores)

elapsed <- difftime(Sys.time(), start, units = 'secs')
cat('Parallel computation completed in', round(elapsed, 2), 'seconds\n')

# Test write permissions
test_file <- paste0('test_fl426_', Sys.getenv('SLURM_JOB_ID'), '.txt')
writeLines(c('Test successful for pi_fl426 account',
             paste('Job ID:', Sys.getenv('SLURM_JOB_ID')),
             paste('Timestamp:', Sys.time())), 
           test_file)
cat('Test file written:', test_file, '\n')

cat('\n================================================================================\n')
cat('SUCCESS: pi_fl426 account is working!\n')
cat('This account maps to your li_fan allocation\n')
cat('FairShare: 0.184 (medium priority, may have short queue wait)\n')
cat('================================================================================\n')
"

echo ""
echo "=========================================="
echo "Test completed for pi_fl426 account"
echo "Results saved in: $WORK_DIR"
echo "=========================================="
echo "Job finished at: $(date)"
