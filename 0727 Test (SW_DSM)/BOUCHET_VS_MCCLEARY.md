# Bouchet vs McCleary Comparison

## Quick Reference Table

| Feature | McCleary | Bouchet | Notes |
|---------|----------|---------|-------|
| **Login** | `ssh yz2324@mccleary.hpc.yale.edu` | `ssh yz2324@bouchet.hpc.yale.edu` | Same credentials |
| **Account Name** | `li_fan`, `tong` | `pi_[netid]` format | Run `slurm_checkup.sh` to confirm |
| **GPU Access** | V100, A100 | **H200** (newest) | Better for AI/ML workloads |
| **Current Load** | High (many users) | **Low** (new cluster) | Faster job starts |
| **Queue Times** | Can be hours | **Minimal/None** | Per Xi's testing |
| **CPU Quota** | Standard | **Larger** | More resources available |
| **Storage Path** | `/gpfs/gibbs/project/li_fan/` | `/gpfs/gibbs/project/pi_[netid]/` | Check after login |
| **Module System** | Same | Same | R/4.3.2-foss-2022b available |
| **Cost** | Free tier + Priority | Free tier + Priority | Same pricing model |

## Recommended Migration Strategy

### Phase 1: Testing (This Week)
1. Test basic access
2. Run a small R simulation job
3. Verify storage paths and quotas

### Phase 2: Gradual Migration
1. Start new jobs on Bouchet
2. Keep ongoing McCleary jobs running
3. Compare performance

### Phase 3: Full Migration
1. Move primary workloads to Bouchet
2. Keep McCleary as backup
3. Share with all PhD students

## Quick Test Commands

```bash
# 1. Test connection (from your local machine)
ssh yz2324@bouchet.hpc.yale.edu "hostname; echo 'Connection successful!'"

# 2. Check your accounts
ssh yz2324@bouchet.hpc.yale.edu "slurm_checkup.sh"

# 3. Check available resources
ssh yz2324@bouchet.hpc.yale.edu "sinfo -o '%P %a %l %D %N'"

# 4. Check R availability
ssh yz2324@bouchet.hpc.yale.edu "module avail R 2>&1 | grep -i 'R/'"
```

## Sample SLURM Script for Bouchet

Save this as `test_bouchet_r.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=test_r_bouchet
#SBATCH --output=test_r_%j.out
#SBATCH --error=test_r_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4
#SBATCH --partition=day  # Or check available partitions with sinfo

# Load R module
module load R/4.3.2-foss-2022b  # Adjust based on available versions

# Run a simple R test
Rscript -e "
cat('Bouchet R Test\n')
cat('R Version:', R.version.string, '\n')
cat('Number of cores detected:', parallel::detectCores(), '\n')
cat('Working directory:', getwd(), '\n')
cat('User:', Sys.getenv('USER'), '\n')
cat('Slurm Job ID:', Sys.getenv('SLURM_JOB_ID'), '\n')
cat('Slurm Account:', Sys.getenv('SLURM_JOB_ACCOUNT'), '\n')

# Simple parallel test
library(parallel)
result <- mclapply(1:4, function(x) {
  Sys.sleep(1)
  return(x^2)
}, mc.cores = 4)
cat('Parallel test result:', unlist(result), '\n')
cat('Test completed successfully!\n')
"
```

## Performance Comparison Test

Once you have access, you can run the same job on both clusters:

```r
# benchmark_test.R
library(microbenchmark)
library(parallel)

# Matrix operations benchmark
matrix_test <- function(n = 1000) {
  A <- matrix(rnorm(n*n), n, n)
  B <- matrix(rnorm(n*n), n, n)
  C <- A %*% B
  return(sum(C))
}

# Run benchmark
cat("Starting benchmark on", Sys.info()["nodename"], "\n")
start_time <- Sys.time()

results <- microbenchmark(
  matrix_1000 = matrix_test(1000),
  matrix_2000 = matrix_test(2000),
  times = 10
)

end_time <- Sys.time()
cat("Total time:", difftime(end_time, start_time, units = "secs"), "seconds\n")
print(results)

# Save results
cluster_name <- ifelse(grepl("bouchet", Sys.info()["nodename"]), "bouchet", "mccleary")
saveRDS(results, paste0("benchmark_", cluster_name, ".rds"))
```

## Action Items

1. **Immediate**: Try `ssh yz2324@bouchet.hpc.yale.edu`
2. **Today**: Run `slurm_checkup.sh` to get your exact account names
3. **This Week**: Run a test R simulation job
4. **Share**: Once confirmed working, inform all PhD students

## Support Contacts

- **Technical Issues**: research.support@yale.edu
- **Mention**: You're a McCleary user testing Bouchet with the li_fan account
- **Xi Fang**: Has successfully tested and can provide peer support





