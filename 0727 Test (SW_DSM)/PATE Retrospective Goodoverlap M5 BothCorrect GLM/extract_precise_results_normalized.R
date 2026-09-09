#!/usr/bin/env Rscript
# Extract precise results with 3 decimal places from normalized weights run

# Load the results
load("pate_retrospective_comparison_results_mccleary.RData")

# True PATE value
true_pate <- 0.8664

# Function to compute metrics with high precision
compute_precise_metrics <- function(results, true_value) {
  estimates <- sapply(results, function(x) x$estimate)
  ses <- sapply(results, function(x) x$se)
  ci_lowers <- sapply(results, function(x) x$ci_lower)
  ci_uppers <- sapply(results, function(x) x$ci_upper)
  
  # Remove NA values
  valid <- !is.na(estimates) & !is.na(ses)
  estimates <- estimates[valid]
  ses <- ses[valid]
  ci_lowers <- ci_lowers[valid]
  ci_uppers <- ci_uppers[valid]
  
  n_valid <- length(estimates)
  
  # Calculate metrics with high precision
  mean_est <- mean(estimates)
  bias <- mean_est - true_value
  mean_se <- mean(ses)
  emp_sd <- sd(estimates)
  relative_bias <- bias / true_value * 100
  
  # Variance relative efficiency (using PS unweighted as reference)
  # Will be calculated later with reference variance
  
  # Coverage
  coverage <- mean(ci_lowers <= true_value & true_value <= ci_uppers) * 100
  
  # CI Width
  ci_width <- mean(ci_uppers - ci_lowers)
  
  # MSE
  mse <- mean((estimates - true_value)^2)
  
  return(list(
    n_valid = n_valid,
    mean_est = mean_est,
    bias = bias,
    mean_se = mean_se,
    emp_sd = emp_sd,
    relative_bias = relative_bias,
    coverage = coverage,
    ci_width = ci_width,
    mse = mse,
    se_sd_ratio = mean_se / emp_sd
  ))
}

# Extract results for each method
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
             "ps_weighted", "wdsm_multinomial")
method_names <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                  "PS Full (Survey-Weighted)", "WDSM (Multinomial Bootstrap)")

# Compute metrics for each method
all_metrics <- list()
for (i in 1:length(methods)) {
  method_results <- lapply(all_results, function(x) x[[methods[i]]])
  all_metrics[[methods[i]]] <- compute_precise_metrics(method_results, true_pate)
}

# Calculate relative efficiency using PS unweighted as reference
ps_var <- all_metrics$ps_unweighted$emp_sd^2
for (method in methods) {
  all_metrics[[method]]$rel_eff <- ps_var / all_metrics[[method]]$emp_sd^2
}

# Print detailed results with 3 decimal places
cat("\n============================================================\n")
cat("PRECISE RESULTS WITH WEIGHT NORMALIZATION (3 decimal places)\n")
cat("============================================================\n\n")
cat(sprintf("True PATE: %.4f\n", true_pate))
cat(sprintf("Total replicates: %d\n\n", length(all_results)))

for (i in 1:length(methods)) {
  method <- methods[i]
  metrics <- all_metrics[[method]]
  
  cat(sprintf("\n%s:\n", method_names[i]))
  cat(sprintf("  Complete replicates: %d\n", metrics$n_valid))
  cat(sprintf("  Mean Estimate: %.6f\n", metrics$mean_est))
  cat(sprintf("  Bias: %.6f\n", metrics$bias))
  cat(sprintf("  Relative Bias: %.3f%%\n", metrics$relative_bias))
  cat(sprintf("  Mean SE: %.6f\n", metrics$mean_se))
  cat(sprintf("  Empirical SD: %.6f\n", metrics$emp_sd))
  cat(sprintf("  SE/SD Ratio: %.4f\n", metrics$se_sd_ratio))
  cat(sprintf("  Coverage: %.3f%%\n", metrics$coverage))
  cat(sprintf("  Relative Efficiency: %.3f\n", metrics$rel_eff))
  cat(sprintf("  CI Width: %.6f\n", metrics$ci_width))
  cat(sprintf("  MSE: %.8f\n", metrics$mse))
}

# Create summary table with precise values
cat("\n\n============================================================\n")
cat("SUMMARY TABLE (3 decimal places)\n")
cat("============================================================\n\n")

cat(sprintf("%-30s | %8s | %8s | %8s | %8s | %8s\n", 
            "Method", "Rel.Bias%", "Coverage%", "Rel.Eff", "SE/SD", "MSE"))
cat(paste(rep("-", 85), collapse=""), "\n")

for (i in 1:length(methods)) {
  method <- methods[i]
  metrics <- all_metrics[[method]]
  
  cat(sprintf("%-30s | %8.3f | %8.3f | %8.3f | %8.4f | %8.6f\n",
              method_names[i],
              metrics$relative_bias,
              metrics$coverage,
              metrics$rel_eff,
              metrics$se_sd_ratio,
              metrics$mse))
}

cat("\n============================================================\n")
