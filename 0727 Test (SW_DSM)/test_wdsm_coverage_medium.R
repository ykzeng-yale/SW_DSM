#!/usr/bin/env Rscript

# Medium-sized WDSM coverage simulation (faster than full but more reliable than quick test)

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
cat("WDSM Bootstrap Coverage - MEDIUM SIMULATION\n")
cat("=======================================================\n\n")

# Medium simulation parameters
n_sims <- 200          # Reasonable number for reliable coverage estimate
n_sample <- 250        # Medium sample size
n_boot <- 100          # Moderate bootstrap replicates
use_parallel <- TRUE
n_cores <- 4

# True population values
true_pate <- ate_sp

cat("Simulation Setup:\n")
cat("- Number of simulations:", n_sims, "\n")
cat("- Sample size:", n_sample, "\n")
cat("- Bootstrap replicates:", n_boot, "\n")
cat("- True PATE:", round(true_pate, 4), "\n")
cat("- Parallel processing:", n_cores, "cores\n\n")

# Function to run one simulation
run_one_simulation <- function(sim_id) {
  tryCatch({
    set.seed(sim_id + 2000)  # Different seed from other simulations
    
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
      ci_width = results$ci_upper - results$ci_lower,
      covers = covers,
      true_value = true_pate
    ))
    
  }, error = function(e) {
    return(data.frame(
      sim_id = sim_id,
      estimate = NA, se = NA,
      ci_lower = NA, ci_upper = NA,
      ci_width = NA, covers = NA,
      true_value = true_pate
    ))
  })
}

# Run simulations
cat("Starting", n_sims, "simulations...\n")
start_time <- Sys.time()

if (use_parallel) {
  cl <- makeCluster(n_cores)
  registerDoParallel(cl)
  
  clusterExport(cl, c("bootstrap_wdsm_pate_prospective", "weighted_local_poly", 
                      "compute_matching_reuse", "estimate_double_score_params",
                      "compute_double_scores", "n_sample", "n_boot", "true_pate",
                      "data", "N", "n_covar", "run_one_simulation"))
  
  # Show progress
  pb <- txtProgressBar(min = 0, max = n_sims, style = 3)
  progress <- function(n) setTxtProgressBar(pb, n)
  opts <- list(progress = progress)
  
  simulation_results <- foreach(
    sim_id = 1:n_sims,
    .combine = rbind,
    .packages = c("MASS", "nloptr"),
    .options.snow = opts
  ) %dopar% {
    run_one_simulation(sim_id)
  }
  
  close(pb)
  stopCluster(cl)
} else {
  simulation_results <- do.call(rbind, lapply(1:n_sims, function(sim_id) {
    if (sim_id %% 10 == 0) cat("Completed", sim_id, "simulations\n")
    run_one_simulation(sim_id)
  }))
}

end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\nCompleted in", round(total_time, 2), "minutes\n\n")

# Analyze results
valid_results <- simulation_results[!is.na(simulation_results$estimate), ]
n_valid <- nrow(valid_results)
n_failed <- n_sims - n_valid

# Calculate coverage and statistics
coverage <- mean(valid_results$covers) * 100
avg_estimate <- mean(valid_results$estimate)
avg_se <- mean(valid_results$se)
avg_ci_width <- mean(valid_results$ci_width)
bias <- avg_estimate - true_pate
relative_bias <- (bias / true_pate) * 100
mse <- mean((valid_results$estimate - true_pate)^2)
rmse <- sqrt(mse)

# Binomial test for coverage
coverage_test <- binom.test(sum(valid_results$covers), n_valid, p = 0.95)

# Display results
cat("=======================================================\n")
cat("COVERAGE SIMULATION RESULTS\n")
cat("=======================================================\n\n")

cat("Sample Statistics:\n")
cat("- Valid simulations:", n_valid, "/", n_sims, "\n")
cat("- Failed simulations:", n_failed, "\n\n")

cat("Coverage Results:\n")
cat("- Nominal level: 95%\n")
cat("- Empirical coverage:", sprintf("%.1f%%", coverage), "\n")
cat("- 95% CI for coverage: [", sprintf("%.1f%%", coverage_test$conf.int[1] * 100), 
    ",", sprintf("%.1f%%", coverage_test$conf.int[2] * 100), "]\n")
cat("- p-value (H0: coverage = 95%):", format.pval(coverage_test$p.value), "\n")
cat("- Monte Carlo SE:", sprintf("%.1f%%", sqrt(coverage * (100-coverage) / n_valid)), "\n\n")

cat("Estimation Performance:\n")
cat("- True PATE:", round(true_pate, 4), "\n")
cat("- Average estimate:", round(avg_estimate, 4), "\n")
cat("- Bias:", round(bias, 4), sprintf("(%.1f%%)\n", relative_bias))
cat("- RMSE:", round(rmse, 4), "\n")
cat("- Average SE:", round(avg_se, 4), "\n")
cat("- Average CI width:", round(avg_ci_width, 4), "\n\n")

# Coverage by CI width quartiles
valid_results$width_quartile <- cut(valid_results$ci_width, 
                                   breaks = quantile(valid_results$ci_width, probs = seq(0, 1, 0.25)),
                                   include.lowest = TRUE, labels = paste0("Q", 1:4))
coverage_by_width <- aggregate(covers ~ width_quartile, data = valid_results, FUN = function(x) mean(x) * 100)

cat("Coverage by CI Width Quartile:\n")
print(coverage_by_width)
cat("\n")

# Final assessment
cat("=======================================================\n")
cat("ASSESSMENT: ")
if (coverage >= 93 && coverage <= 97) {
  cat("EXCELLENT - Achieves nominal 95% coverage ✓\n")
} else if (coverage >= 90 && coverage <= 98) {
  cat("ACCEPTABLE - Close to nominal coverage\n")
} else {
  cat("POOR - Does not achieve nominal coverage ✗\n")
}
cat("=======================================================\n\n")

# Save results
save(simulation_results, valid_results, coverage, coverage_test, 
     file = "wdsm_coverage_medium_results.RData")
cat("Results saved to: wdsm_coverage_medium_results.RData\n") 