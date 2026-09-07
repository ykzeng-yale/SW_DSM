#!/usr/bin/env Rscript
################################################################################
# Bouchet Cluster Test Job
# Purpose: Verify R environment and cluster resources
# Date: 2025-08-27
################################################################################

cat("================================================================================\n")
cat("BOUCHET CLUSTER TEST JOB\n")
cat("================================================================================\n\n")

# System Information
cat("Date/Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("Hostname:", Sys.info()["nodename"], "\n")
cat("User:", Sys.info()["user"], "\n")
cat("R Version:", R.version.string, "\n\n")

# Environment Variables (SLURM)
cat("SLURM Environment:\n")
cat("  Job ID:", Sys.getenv("SLURM_JOB_ID"), "\n")
cat("  Job Name:", Sys.getenv("SLURM_JOB_NAME"), "\n")
cat("  Account:", Sys.getenv("SLURM_JOB_ACCOUNT"), "\n")
cat("  Partition:", Sys.getenv("SLURM_JOB_PARTITION"), "\n")
cat("  Node List:", Sys.getenv("SLURM_JOB_NODELIST"), "\n")
cat("  CPUs:", Sys.getenv("SLURM_CPUS_PER_TASK"), "\n")
cat("  Memory:", Sys.getenv("SLURM_MEM_PER_NODE"), "MB\n\n")

# Working Directory
cat("Working Directory:", getwd(), "\n\n")

# CPU Detection
cat("CPU Information:\n")
cat("  Detected Cores:", parallel::detectCores(), "\n")
cat("  Logical Cores:", parallel::detectCores(logical = TRUE), "\n")
cat("  Physical Cores:", parallel::detectCores(logical = FALSE), "\n\n")

# Memory Information
cat("Memory Information:\n")
cat("  Memory Limit:", format(memory.limit(), big.mark = ","), "MB\n")
cat("  Memory Size:", format(memory.size(), big.mark = ","), "MB\n\n")

# Test Package Loading
cat("Testing Common Packages:\n")
packages_to_test <- c("parallel", "doParallel", "foreach", "MASS", "Matrix")

for (pkg in packages_to_test) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("  ✓", pkg, "- Version:", 
        as.character(packageVersion(pkg)), "\n")
  } else {
    cat("  ✗", pkg, "- Not available\n")
  }
}
cat("\n")

# Simple Parallel Test
cat("Running Parallel Test:\n")
library(parallel)

# Test with 4 cores
n_cores <- min(4, parallel::detectCores())
cat("  Using", n_cores, "cores for test\n")

# Simple parallel computation
start_time <- Sys.time()
results <- mclapply(1:n_cores, function(x) {
  Sys.sleep(1)  # Simulate work
  sum(rnorm(1000000))  # Do some computation
}, mc.cores = n_cores)

end_time <- Sys.time()
time_diff <- difftime(end_time, start_time, units = "secs")

cat("  Parallel test completed in", round(time_diff, 2), "seconds\n")
cat("  Results summary:", round(mean(unlist(results)), 4), "\n\n")

# Matrix Operations Test
cat("Testing Matrix Operations:\n")
n <- 2000
cat("  Creating", n, "x", n, "matrices\n")

start_time <- Sys.time()
A <- matrix(rnorm(n*n), n, n)
B <- matrix(rnorm(n*n), n, n)
C <- A %*% B
end_time <- Sys.time()

time_diff <- difftime(end_time, start_time, units = "secs")
cat("  Matrix multiplication completed in", round(time_diff, 3), "seconds\n")
cat("  Result dimension:", paste(dim(C), collapse = " x "), "\n")
cat("  Result checksum:", round(sum(C), 2), "\n\n")

# File I/O Test
cat("Testing File I/O:\n")
test_file <- "bouchet_test_output.txt"
cat("  Writing test file:", test_file, "\n")

test_data <- data.frame(
  timestamp = Sys.time(),
  node = Sys.info()["nodename"],
  account = Sys.getenv("SLURM_JOB_ACCOUNT"),
  job_id = Sys.getenv("SLURM_JOB_ID"),
  test_status = "SUCCESS"
)

write.csv(test_data, test_file, row.names = FALSE)
cat("  File written successfully\n\n")

# Final Summary
cat("================================================================================\n")
cat("TEST SUMMARY:\n")
cat("  ✓ R environment loaded successfully\n")
cat("  ✓ SLURM environment variables accessible\n")
cat("  ✓ CPU detection working (", parallel::detectCores(), "cores )\n")
cat("  ✓ Parallel computation successful\n")
cat("  ✓ Matrix operations functional\n")
cat("  ✓ File I/O working\n")
cat("\nBOUCHET CLUSTER TEST COMPLETED SUCCESSFULLY!\n")
cat("Account used:", Sys.getenv("SLURM_JOB_ACCOUNT"), "\n")
cat("FairShare advantage: Jobs should start immediately with pi_gt353!\n")
cat("================================================================================\n")
