#!/usr/bin/env Rscript

# Coverage simulation for all WDSM bootstrap methods
# Tests nominal 95% coverage for PATE/PATT × Prospective/Retrospective

# Load required libraries
library(MASS)
library(nloptr)
library(doParallel)
library(foreach)

# Source the corrected bootstrap functions
source("WDSM/R/bootstrap_wdsm_corrected.R")

# Source the super population generation
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Calculate true population values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("WDSM Bootstrap Coverage Simulation - All Methods\n")
cat("=======================================================\n\n")

# Simulation parameters
n_sims <- 100          # Number of simulations per method
n_sample <- 300        # Sample size
n_boot <- 50           # Bootstrap replicates (reduced for speed)
use_parallel <- TRUE
n_cores <- 4

cat("Simulation Setup:\n")
cat("- Simulations per method:", n_sims, "\n")
cat("- Sample size:", n_sample, "\n")
cat("- Bootstrap replicates:", n_boot, "\n")
cat("- True PATE:", round(ate_sp, 4), "\n")
cat("- True PATT:", round(att_sp, 4), "\n")
cat("- Parallel processing:", ifelse(use_parallel, paste("Yes,", n_cores, "cores"), "No"), "\n\n")

# Function to run one simulation for a given method
run_one_simulation <- function(sim_id, method_name, n_sample, n_boot, true_pate, true_patt, 
                              data, N, n_covar) {
  
  tryCatch({
    set.seed(sim_id + 1000 * which(c("PATE-Prospective", "PATE-Retrospective", 
                                     "PATT-Prospective", "PATT-Retrospective") == method_name))
    
    # Draw sample
    sample_idx <- sample(1:N, n_sample, replace = FALSE)
    sample_data <- data[sample_idx, ]
    
    # Extract variables
    X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
    Z <- sample_data$z
    Y <- sample_data$y
    
    # Create weights based on sampling design
    if (grepl("Prospective", method_name)) {
      weights <- rep(N/n_sample, n_sample)
      weights1 <- weights0 <- NULL
    } else {
      # Retrospective with different selection probabilities
      prob_select_treated <- 0.7
      prob_select_control <- 0.3
      weights1 <- rep(N * mean(data$z) / (n_sample * prob_select_treated), n_sample)
      weights0 <- rep(N * (1 - mean(data$z)) / (n_sample * prob_select_control), n_sample)
      weights <- NULL
    }
    
    # Run appropriate bootstrap method
    if (method_name == "PATE-Prospective") {
      results <- bootstrap_wdsm_pate_prospective(
        X = X, Z = Z, Y = Y, weights = weights,
        n_boot = n_boot, method = "ps", parallel = FALSE
      )
      true_value <- true_pate
    } else if (method_name == "PATE-Retrospective") {
      results <- bootstrap_wdsm_pate_retrospective(
        X = X, Z = Z, Y = Y, weights0 = weights0, weights1 = weights1,
        n_boot = n_boot, method = "ps", parallel = FALSE
      )
      true_value <- true_pate
    } else if (method_name == "PATT-Prospective") {
      results <- bootstrap_wdsm_patt_prospective(
        X = X, Z = Z, Y = Y, weights = weights,
        n_boot = n_boot, method = "ps", parallel = FALSE
      )
      true_value <- true_patt
    } else if (method_name == "PATT-Retrospective") {
      results <- bootstrap_wdsm_patt_retrospective(
        X = X, Z = Z, Y = Y, weights0 = weights0, weights1 = weights1,
        n_boot = n_boot, method = "ps", parallel = FALSE
      )
      true_value <- true_patt
    }
    
    # Check coverage
    covers <- (true_value >= results$ci_lower) & (true_value <= results$ci_upper)
    covers_bc <- (true_value >= results$ci_lower_bc) & (true_value <= results$ci_upper_bc)
    
    return(data.frame(
      sim_id = sim_id,
      method = method_name,
      estimate = results$estimate,
      se = results$se,
      ci_lower = results$ci_lower,
      ci_upper = results$ci_upper,
      ci_lower_bc = results$ci_lower_bc,
      ci_upper_bc = results$ci_upper_bc,
      covers = covers,
      covers_bc = covers_bc,
      true_value = true_value,
      bias = results$bias
    ))
    
  }, error = function(e) {
    return(data.frame(
      sim_id = sim_id,
      method = method_name,
      estimate = NA, se = NA,
      ci_lower = NA, ci_upper = NA,
      ci_lower_bc = NA, ci_upper_bc = NA,
      covers = NA, covers_bc = NA,
      true_value = ifelse(grepl("PATE", method_name), true_pate, true_patt),
      bias = NA
    ))
  })
}

# Run simulations for all methods
methods <- c("PATE-Prospective", "PATE-Retrospective", 
             "PATT-Prospective", "PATT-Retrospective")

all_results <- list()

for (method in methods) {
  cat("\nRunning simulations for", method, "...\n")
  start_time <- Sys.time()
  
  if (use_parallel) {
    cl <- makeCluster(n_cores)
    registerDoParallel(cl)
    
    clusterExport(cl, c("bootstrap_wdsm_pate_prospective", "bootstrap_wdsm_pate_retrospective",
                        "bootstrap_wdsm_patt_prospective", "bootstrap_wdsm_patt_retrospective",
                        "weighted_local_poly_corrected", "adaptive_bandwidth",
                        "estimate_double_score_params_stable", "compute_double_scores_corrected",
                        "n_sample", "n_boot", "ate_sp", "att_sp",
                        "data", "N", "n_covar", "run_one_simulation", "method"))
    
    method_results <- foreach(
      sim_id = 1:n_sims,
      .combine = rbind,
      .packages = c("MASS", "nloptr")
    ) %dopar% {
      run_one_simulation(sim_id, method, n_sample, n_boot, ate_sp, att_sp, 
                        data, N, n_covar)
    }
    
    stopCluster(cl)
  } else {
    method_results <- do.call(rbind, lapply(1:n_sims, function(sim_id) {
      if (sim_id %% 10 == 0) cat(".")
      run_one_simulation(sim_id, method, n_sample, n_boot, ate_sp, att_sp,
                        data, N, n_covar)
    }))
  }
  
  end_time <- Sys.time()
  cat("\nCompleted in", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")
  
  all_results[[method]] <- method_results
}

# Combine all results
combined_results <- do.call(rbind, all_results)

# Calculate coverage for each method
coverage_summary <- aggregate(cbind(covers, covers_bc) ~ method, 
                            data = combined_results[!is.na(combined_results$estimate), ],
                            FUN = function(x) mean(x) * 100)

# Calculate other statistics
stats_summary <- aggregate(cbind(estimate, se, bias) ~ method,
                         data = combined_results[!is.na(combined_results$estimate), ],
                         FUN = mean)

# Calculate RMSE
rmse_summary <- aggregate(estimate ~ method,
                        data = combined_results[!is.na(combined_results$estimate), ],
                        FUN = function(x) {
                          true_val <- unique(combined_results$true_value[
                            combined_results$method == unique(combined_results$method[!is.na(combined_results$estimate)])[1]
                          ])
                          sqrt(mean((x - true_val)^2))
                        })
names(rmse_summary)[2] <- "rmse"

# Merge summaries
summary_table <- merge(coverage_summary, stats_summary, by = "method")
summary_table <- merge(summary_table, rmse_summary, by = "method")

# Add true values
summary_table$true_value <- ifelse(grepl("PATE", summary_table$method), ate_sp, att_sp)

# Calculate relative bias
summary_table$rel_bias <- (summary_table$estimate - summary_table$true_value) / 
                          summary_table$true_value * 100

cat("\n=======================================================\n")
cat("COVERAGE SIMULATION RESULTS\n")
cat("=======================================================\n\n")

# Reorder columns
summary_table <- summary_table[, c("method", "true_value", "estimate", "bias", "rel_bias", 
                                  "se", "rmse", "covers", "covers_bc")]

print(summary_table, digits = 2, row.names = FALSE)

cat("\n=======================================================\n")
cat("COVERAGE ASSESSMENT\n")
cat("=======================================================\n\n")

for (i in 1:nrow(summary_table)) {
  method <- summary_table$method[i]
  cov <- summary_table$covers[i]
  cov_bc <- summary_table$covers_bc[i]
  
  cat(method, ":\n")
  cat("  Standard CI coverage:", sprintf("%.1f%%", cov), 
      ifelse(cov >= 93 && cov <= 97, "✓ GOOD", 
             ifelse(cov >= 90 && cov <= 98, "⚠ ACCEPTABLE", "✗ POOR")), "\n")
  cat("  Bias-corrected CI coverage:", sprintf("%.1f%%", cov_bc), 
      ifelse(cov_bc >= 93 && cov_bc <= 97, "✓ GOOD", 
             ifelse(cov_bc >= 90 && cov_bc <= 98, "⚠ ACCEPTABLE", "✗ POOR")), "\n")
}

cat("\n=======================================================\n")
cat("FINAL VERDICT\n")
cat("=======================================================\n")

good_coverage <- sum(summary_table$covers >= 93 & summary_table$covers <= 97)
acceptable_coverage <- sum(summary_table$covers >= 90 & summary_table$covers <= 98)

if (good_coverage == 4) {
  cat("✓ EXCELLENT: All methods achieve nominal 95% coverage\n")
} else if (acceptable_coverage == 4) {
  cat("⚠ ACCEPTABLE: All methods have reasonable coverage\n")
} else {
  cat("✗ NEEDS IMPROVEMENT: Some methods fail to achieve nominal coverage\n")
}

# Save results
save(combined_results, summary_table, file = "all_wdsm_coverage_results.RData")
cat("\nDetailed results saved to: all_wdsm_coverage_results.RData\n") 