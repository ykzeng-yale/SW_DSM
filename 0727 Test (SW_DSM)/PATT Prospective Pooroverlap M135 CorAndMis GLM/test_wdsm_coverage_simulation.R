#!/usr/bin/env Rscript

# Simulation to test nominal coverage of WDSM bootstrap confidence intervals
# This will run many simulations and check if the 95% CI covers the true value 95% of the time

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
cat("WDSM Bootstrap Coverage Simulation\n")
cat("Testing Nominal 95% Coverage\n")
cat("=======================================================\n\n")

# Simulation parameters
n_sims <- 500          # Number of simulations
n_sample <- 300        # Sample size per simulation
n_boot <- 200          # Number of bootstrap replicates per simulation
use_parallel <- TRUE   # Use parallel processing
n_cores <- 4           # Number of cores for parallel processing

# True population values
true_pate <- ate_sp
true_patt <- att_sp

cat("Simulation Setup:\n")
cat("- Number of simulations:", n_sims, "\n")
cat("- Sample size per simulation:", n_sample, "\n")
cat("- Bootstrap replicates per simulation:", n_boot, "\n")
cat("- True PATE in population:", round(true_pate, 4), "\n")
cat("- Parallel processing:", ifelse(use_parallel, paste("Yes,", n_cores, "cores"), "No"), "\n\n")

# Function to run one simulation
run_one_simulation <- function(sim_id, n_sample, n_boot, true_pate, data, N, n_covar) {
  
  tryCatch({
    # Set seed for reproducibility
    set.seed(sim_id + 1000)
    
    # Draw a random sample from the super population
    sample_idx <- sample(1:N, n_sample, replace = FALSE)
    sample_data <- data[sample_idx, ]
    
    # Extract variables
    X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
    Z <- sample_data$z
    Y <- sample_data$y
    
    # For prospective sampling, weights only depend on X
    # Using simple equal weights for this simulation
    weights <- rep(N/n_sample, n_sample)
    
    # Run WDSM with bootstrap
    results <- bootstrap_wdsm_pate_prospective(
      X = X,
      Z = Z,
      Y = Y,
      weights = weights,
      n_boot = n_boot,
      method = "ps",
      n_matches = 1,
      caliper = NULL,
      parallel = FALSE  # Don't use nested parallelization
    )
    
    # Check coverage
    covers <- (true_pate >= results$ci_lower) & (true_pate <= results$ci_upper)
    
    # Return results
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
    # Return NA results if simulation fails
    return(data.frame(
      sim_id = sim_id,
      estimate = NA,
      se = NA,
      ci_lower = NA,
      ci_upper = NA,
      ci_width = NA,
      covers = NA,
      true_value = true_pate
    ))
  })
}

# Run simulations
cat("Starting simulations...\n")
start_time <- Sys.time()

if (use_parallel) {
  # Set up parallel cluster
  cl <- makeCluster(n_cores)
  registerDoParallel(cl)
  
  # Export necessary objects to cluster
  clusterExport(cl, c("bootstrap_wdsm_pate_prospective", "weighted_local_poly", 
                      "compute_matching_reuse", "estimate_double_score_params",
                      "compute_double_scores", "n_sample", "n_boot", "true_pate",
                      "data", "N", "n_covar"))
  
  # Run simulations in parallel
  simulation_results <- foreach(
    sim_id = 1:n_sims,
    .combine = rbind,
    .packages = c("MASS", "nloptr")
  ) %dopar% {
    run_one_simulation(sim_id, n_sample, n_boot, true_pate, data, N, n_covar)
  }
  
  # Stop cluster
  stopCluster(cl)
  
} else {
  # Run simulations sequentially
  simulation_results <- do.call(rbind, lapply(1:n_sims, function(sim_id) {
    if (sim_id %% 10 == 0) cat("Completed", sim_id, "simulations\n")
    run_one_simulation(sim_id, n_sample, n_boot, true_pate, data, N, n_covar)
  }))
}

end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\nSimulations completed in", round(total_time, 2), "minutes\n\n")

# Remove failed simulations
valid_results <- simulation_results[!is.na(simulation_results$estimate), ]
n_valid <- nrow(valid_results)
n_failed <- n_sims - n_valid

# Calculate coverage and other statistics
coverage <- mean(valid_results$covers) * 100
avg_estimate <- mean(valid_results$estimate)
avg_se <- mean(valid_results$se)
avg_ci_width <- mean(valid_results$ci_width)
bias <- avg_estimate - true_pate
relative_bias <- (bias / true_pate) * 100
mse <- mean((valid_results$estimate - true_pate)^2)
rmse <- sqrt(mse)

# Coverage by CI width quantiles
valid_results$width_quartile <- cut(valid_results$ci_width, 
                                   breaks = quantile(valid_results$ci_width, probs = seq(0, 1, 0.25)),
                                   include.lowest = TRUE, labels = paste0("Q", 1:4))
coverage_by_width <- aggregate(covers ~ width_quartile, data = valid_results, FUN = function(x) mean(x) * 100)

cat("=======================================================\n")
cat("SIMULATION RESULTS\n")
cat("=======================================================\n\n")

cat("Sample Statistics:\n")
cat("- Valid simulations:", n_valid, "/", n_sims, "\n")
cat("- Failed simulations:", n_failed, "\n\n")

cat("Coverage Results:\n")
cat("- Nominal coverage level: 95%\n")
cat("- Empirical coverage: ", sprintf("%.1f%%", coverage), "\n")
cat("- Coverage assessment: ", 
    ifelse(coverage >= 93 && coverage <= 97, "GOOD ✓", 
           ifelse(coverage >= 90 && coverage <= 98, "ACCEPTABLE", "POOR ✗")), "\n\n")

cat("Estimation Performance:\n")
cat("- True PATE:", round(true_pate, 4), "\n")
cat("- Average estimate:", round(avg_estimate, 4), "\n")
cat("- Bias:", round(bias, 4), "\n")
cat("- Relative bias:", sprintf("%.1f%%", relative_bias), "\n")
cat("- RMSE:", round(rmse, 4), "\n")
cat("- Average SE:", round(avg_se, 4), "\n")
cat("- Average CI width:", round(avg_ci_width, 4), "\n\n")

cat("Coverage by CI Width Quartile:\n")
print(coverage_by_width)
cat("\n")

# Plot results if in interactive mode
if (interactive()) {
  par(mfrow = c(2, 2))
  
  # 1. Histogram of estimates
  hist(valid_results$estimate, breaks = 30, 
       main = "Distribution of WDSM Estimates",
       xlab = "PATE Estimate", col = "lightblue")
  abline(v = true_pate, col = "red", lwd = 2, lty = 2)
  abline(v = avg_estimate, col = "blue", lwd = 2)
  legend("topright", legend = c("True PATE", "Average Est."),
         col = c("red", "blue"), lty = c(2, 1), lwd = 2)
  
  # 2. Coverage over simulations (cumulative)
  cum_coverage <- cumsum(valid_results$covers) / seq_along(valid_results$covers)
  plot(cum_coverage * 100, type = "l", 
       main = "Cumulative Coverage Rate",
       xlab = "Simulation Number", ylab = "Coverage (%)",
       ylim = c(85, 100))
  abline(h = 95, col = "red", lty = 2)
  abline(h = coverage, col = "blue", lty = 1)
  
  # 3. CI width vs coverage
  boxplot(ci_width ~ covers, data = valid_results,
          names = c("Not Covered", "Covered"),
          main = "CI Width by Coverage Status",
          ylab = "CI Width")
  
  # 4. Estimates vs true value
  plot(valid_results$sim_id, valid_results$estimate,
       pch = 16, cex = 0.5,
       col = ifelse(valid_results$covers, "blue", "red"),
       main = "Estimates Across Simulations",
       xlab = "Simulation ID", ylab = "PATE Estimate")
  abline(h = true_pate, col = "green", lwd = 2)
  legend("topright", legend = c("Covered", "Not Covered", "True PATE"),
         col = c("blue", "red", "green"), pch = c(16, 16, NA), lty = c(NA, NA, 1))
  
  par(mfrow = c(1, 1))
}

# Additional diagnostics
cat("Additional Diagnostics:\n")
cat("- CI lower bound range: [", round(min(valid_results$ci_lower), 3), ",", 
    round(max(valid_results$ci_lower), 3), "]\n")
cat("- CI upper bound range: [", round(min(valid_results$ci_upper), 3), ",", 
    round(max(valid_results$ci_upper), 3), "]\n")
cat("- Proportion of CIs below true value:", 
    round(mean(valid_results$ci_upper < true_pate) * 100, 1), "%\n")
cat("- Proportion of CIs above true value:", 
    round(mean(valid_results$ci_lower > true_pate) * 100, 1), "%\n\n")

# Test for correct coverage using binomial test
coverage_test <- binom.test(sum(valid_results$covers), n_valid, p = 0.95)
cat("Binomial Test for Coverage:\n")
cat("- Null hypothesis: Coverage = 95%\n")
cat("- Observed coverage:", sprintf("%.1f%%", coverage), "\n")
cat("- 95% CI for coverage: [", sprintf("%.1f%%", coverage_test$conf.int[1] * 100), 
    ",", sprintf("%.1f%%", coverage_test$conf.int[2] * 100), "]\n")
cat("- p-value:", format.pval(coverage_test$p.value), "\n")
cat("- Conclusion:", ifelse(coverage_test$p.value > 0.05, 
                           "Cannot reject null (coverage is consistent with 95%)",
                           "Reject null (coverage differs from 95%)"), "\n\n")

# Save results
save(simulation_results, valid_results, coverage, file = "wdsm_coverage_simulation_results.RData")
cat("Results saved to: wdsm_coverage_simulation_results.RData\n\n")

cat("=======================================================\n")
cat("SUMMARY: The WDSM bootstrap method ",
    ifelse(coverage >= 93 && coverage <= 97, "ACHIEVES", "DOES NOT ACHIEVE"),
    " nominal 95% coverage\n")
cat("=======================================================\n") 