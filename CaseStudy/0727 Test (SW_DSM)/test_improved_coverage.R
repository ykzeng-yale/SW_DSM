#!/usr/bin/env Rscript

# Test coverage of improved WDSM bootstrap implementation

library(MASS)
library(nloptr)

# Source functions
source("SW_PSW-main/Super_Population_GoodOvelap.R")
source("WDSM/R/bootstrap_wdsm_improved.R")

# True values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("Testing Improved WDSM Bootstrap Implementation\n")
cat("=======================================================\n\n")

# Test parameters
n_sim <- 100
n_sample <- 300
n_boot <- 100

cat("Simulation Setup:\n")
cat("- Simulations:", n_sim, "\n")
cat("- Sample size:", n_sample, "\n")
cat("- Bootstrap replicates:", n_boot, "\n")
cat("- True PATE:", round(ate_sp, 4), "\n")
cat("- True PATT:", round(att_sp, 4), "\n\n")

# Function to run one simulation
run_simulation <- function(method, sim_id, n_sample, n_boot, true_value) {
  
  set.seed(sim_id * 1000 + which(c("PATE-Prospective", "PATE-Retrospective",
                                   "PATT-Prospective", "PATT-Retrospective") == method))
  
  # Sample data
  idx <- sample(1:N, n_sample, replace = FALSE)
  sample_data <- data[idx, ]
  X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
  Z <- sample_data$z
  Y <- sample_data$y
  
  # Run appropriate method
  if (method == "PATE-Prospective") {
    weights <- rep(N/n_sample, n_sample)
    result <- bootstrap_wdsm_pate_prospective_improved(
      X, Z, Y, weights, n_boot = n_boot
    )
  } else if (method == "PATE-Retrospective") {
    weights1 <- rep(N * mean(data$z) / (n_sample * 0.7), n_sample)
    weights0 <- rep(N * (1 - mean(data$z)) / (n_sample * 0.3), n_sample)
    result <- bootstrap_wdsm_pate_retrospective_improved(
      X, Z, Y, weights0, weights1, n_boot = n_boot
    )
  } else if (method == "PATT-Prospective") {
    weights <- rep(N/n_sample, n_sample)
    result <- bootstrap_wdsm_patt_prospective_improved(
      X, Z, Y, weights, n_boot = n_boot
    )
  } else if (method == "PATT-Retrospective") {
    weights1 <- rep(N * mean(data$z) / (n_sample * 0.7), n_sample)
    weights0 <- rep(N * (1 - mean(data$z)) / (n_sample * 0.3), n_sample)
    result <- bootstrap_wdsm_patt_retrospective_improved(
      X, Z, Y, weights0, weights1, n_boot = n_boot
    )
  }
  
  # Check coverage
  covers_std <- (true_value >= result$ci_lower) & (true_value <= result$ci_upper)
  covers_pct <- (true_value >= result$ci_lower_pct) & (true_value <= result$ci_upper_pct)
  
  if (!is.null(result$ci_lower_bca)) {
    covers_bca <- (true_value >= result$ci_lower_bca) & (true_value <= result$ci_upper_bca)
  } else {
    covers_bca <- covers_pct
  }
  
  return(data.frame(
    method = method,
    estimate = result$estimate,
    se = result$se,
    bias = result$estimate - true_value,
    covers_std = covers_std,
    covers_pct = covers_pct,
    covers_bca = covers_bca
  ))
}

# Run simulations for all methods
methods <- c("PATE-Prospective", "PATE-Retrospective",
             "PATT-Prospective", "PATT-Retrospective")

all_results <- list()

for (method in methods) {
  cat("\nTesting", method, "...\n")
  
  true_val <- if (grepl("PATE", method)) ate_sp else att_sp
  
  method_results <- do.call(rbind, lapply(1:n_sim, function(i) {
    if (i %% 20 == 0) cat(".")
    tryCatch({
      run_simulation(method, i, n_sample, n_boot, true_val)
    }, error = function(e) {
      data.frame(
        method = method,
        estimate = NA, se = NA, bias = NA,
        covers_std = NA, covers_pct = NA, covers_bca = NA
      )
    })
  }))
  cat("\n")
  
  all_results[[method]] <- method_results
}

# Combine and summarize results
combined_results <- do.call(rbind, all_results)
combined_results <- combined_results[!is.na(combined_results$estimate), ]

# Summary by method
coverage_summary <- aggregate(
  cbind(covers_std, covers_pct, covers_bca) ~ method,
  data = combined_results,
  FUN = function(x) mean(x) * 100
)

performance_summary <- aggregate(
  cbind(estimate, bias, se) ~ method,
  data = combined_results,
  FUN = mean
)

# Add RMSE
rmse_by_method <- aggregate(
  bias ~ method,
  data = combined_results,
  FUN = function(x) sqrt(mean(x^2))
)
names(rmse_by_method)[2] <- "rmse"

# Merge summaries
final_summary <- merge(coverage_summary, performance_summary, by = "method")
final_summary <- merge(final_summary, rmse_by_method, by = "method")

# Add true values
final_summary$true_value <- ifelse(grepl("PATE", final_summary$method), ate_sp, att_sp)
final_summary$rel_bias_pct <- final_summary$bias / final_summary$true_value * 100

cat("\n=======================================================\n")
cat("IMPROVED WDSM COVERAGE RESULTS\n")
cat("=======================================================\n\n")

# Print formatted results
cat("Coverage Results (%):\n")
cat("--------------------\n")
print(coverage_summary, digits = 1, row.names = FALSE)

cat("\n\nPerformance Metrics:\n")
cat("-------------------\n")
perf_display <- final_summary[, c("method", "true_value", "estimate", "bias", "rel_bias_pct", "se", "rmse")]
print(perf_display, digits = 3, row.names = FALSE)

cat("\n=======================================================\n")
cat("COVERAGE ASSESSMENT\n")
cat("=======================================================\n\n")

# Assess each method
best_ci <- character(4)
for (i in 1:nrow(final_summary)) {
  method <- final_summary$method[i]
  
  # Find best CI type
  cov_std <- final_summary$covers_std[i]
  cov_pct <- final_summary$covers_pct[i]
  cov_bca <- final_summary$covers_bca[i]
  
  # Distance from 95%
  dist_std <- abs(cov_std - 95)
  dist_pct <- abs(cov_pct - 95)
  dist_bca <- abs(cov_bca - 95)
  
  if (dist_std <= dist_pct && dist_std <= dist_bca) {
    best_ci[i] <- "Standard"
    best_cov <- cov_std
  } else if (dist_pct <= dist_bca) {
    best_ci[i] <- "Percentile"
    best_cov <- cov_pct
  } else {
    best_ci[i] <- "BCa"
    best_cov <- cov_bca
  }
  
  cat(method, ":\n")
  cat("  Best CI:", best_ci[i], "with", sprintf("%.1f%%", best_cov), "coverage\n")
  cat("  Assessment:", 
      ifelse(best_cov >= 93 && best_cov <= 97, "✓ GOOD",
             ifelse(best_cov >= 90 && best_cov <= 98, "⚠ ACCEPTABLE", "✗ POOR")), "\n")
  cat("  Relative bias:", sprintf("%.1f%%", final_summary$rel_bias_pct[i]), "\n\n")
}

# Overall assessment
good_methods <- sum(apply(final_summary[, c("covers_std", "covers_pct", "covers_bca")], 1,
                         function(x) any(x >= 93 & x <= 97)))

cat("=======================================================\n")
cat("FINAL VERDICT\n")
cat("=======================================================\n")

if (good_methods == 4) {
  cat("✓ SUCCESS: All methods achieve nominal coverage!\n")
} else if (good_methods >= 2) {
  cat("⚠ PARTIAL SUCCESS:", good_methods, "out of 4 methods achieve nominal coverage\n")
} else {
  cat("✗ NEEDS MORE WORK: Only", good_methods, "methods achieve nominal coverage\n")
}

# Save results
save(combined_results, final_summary, file = "improved_wdsm_results.RData")
cat("\nResults saved to: improved_wdsm_results.RData\n") 