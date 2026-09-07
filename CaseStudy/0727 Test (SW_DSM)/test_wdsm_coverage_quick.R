#!/usr/bin/env Rscript

# Quick test of WDSM coverage simulation (reduced parameters for fast testing)

# Load required libraries
library(MASS)
library(nloptr)
library(doParallel)
library(foreach)

# Source the improved bootstrap functions
source("WDSM/R/bootstrap_wdsm.R")

# Source the super population generation
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Calculate true population values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("WDSM Bootstrap Coverage - QUICK TEST\n")
cat("=======================================================\n\n")

# Reduced simulation parameters for quick test
n_sims <- 50           # Reduced from 500
n_sample <- 200        # Reduced from 300
n_boot <- 50           # Reduced from 200
use_parallel <- TRUE
n_cores <- 2

# True population values
true_pate <- ate_sp

cat("Quick Test Setup:\n")
cat("- Number of simulations:", n_sims, "\n")
cat("- Sample size:", n_sample, "\n")
cat("- Bootstrap replicates:", n_boot, "\n")
cat("- True PATE:", round(true_pate, 4), "\n\n")

# Function to run one simulation
run_one_simulation <- function(sim_id) {
  tryCatch({
    set.seed(sim_id + 1000)
    
    # Draw sample
    sample_idx <- sample(1:N, n_sample, replace = FALSE)
    sample_data <- data[sample_idx, ]
    
    # Extract variables
    X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
    Z <- sample_data$z
    Y <- sample_data$y
    weights <- rep(N/n_sample, n_sample)
    
    # Suppress output for individual runs
    capture.output({
      results <- bootstrap_wdsm_pate_prospective(
        X = X, Z = Z, Y = Y, weights = weights,
        n_boot = n_boot, method = "ps",
        n_matches = 1, caliper = NULL, parallel = FALSE
      )
    })
    
    # Check coverage
    covers <- (true_pate >= results$ci_lower) & (true_pate <= results$ci_upper)
    
    return(data.frame(
      sim_id = sim_id,
      estimate = results$estimate,
      se = results$se,
      ci_lower = results$ci_lower,
      ci_upper = results$ci_upper,
      covers = covers
    ))
    
  }, error = function(e) {
    return(data.frame(
      sim_id = sim_id,
      estimate = NA, se = NA,
      ci_lower = NA, ci_upper = NA,
      covers = NA
    ))
  })
}

# Run simulations
cat("Running", n_sims, "simulations...\n")
start_time <- Sys.time()

if (use_parallel) {
  cl <- makeCluster(n_cores)
  registerDoParallel(cl)
  
  clusterExport(cl, c("bootstrap_wdsm_pate_prospective", "weighted_local_poly", 
                      "compute_matching_reuse", "estimate_double_score_params",
                      "compute_double_scores", "n_sample", "n_boot", "true_pate",
                      "data", "N", "n_covar", "run_one_simulation"))
  
  simulation_results <- foreach(
    sim_id = 1:n_sims,
    .combine = rbind,
    .packages = c("MASS", "nloptr")
  ) %dopar% {
    run_one_simulation(sim_id)
  }
  
  stopCluster(cl)
} else {
  simulation_results <- do.call(rbind, lapply(1:n_sims, run_one_simulation))
}

end_time <- Sys.time()
cat("Completed in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n\n")

# Calculate results
valid_results <- simulation_results[!is.na(simulation_results$estimate), ]
n_valid <- nrow(valid_results)
coverage <- mean(valid_results$covers) * 100

cat("=======================================================\n")
cat("QUICK TEST RESULTS\n")
cat("=======================================================\n")
cat("Valid simulations:", n_valid, "/", n_sims, "\n")
cat("Empirical coverage:", sprintf("%.1f%%", coverage), "\n")
cat("Average estimate:", round(mean(valid_results$estimate), 4), "\n")
cat("Average SE:", round(mean(valid_results$se), 4), "\n")
cat("True PATE:", round(true_pate, 4), "\n\n")

if (n_valid == n_sims) {
  cat("✓ All simulations completed successfully!\n")
  cat("✓ Ready to run full simulation\n")
} else {
  cat("⚠ Some simulations failed. Check for issues before running full simulation.\n")
} 