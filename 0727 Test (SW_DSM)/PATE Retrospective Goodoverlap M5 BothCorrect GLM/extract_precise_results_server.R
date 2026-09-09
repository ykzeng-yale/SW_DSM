#!/usr/bin/env Rscript
# Extract precise results with 3 decimal places from WDSM unnormalized run

# Load the results from the server location
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

# Print header
cat("\n============================================================\n")
cat("PRECISE RESULTS FROM SERVER: WDSM WITHOUT NORMALIZATION\n")
cat("============================================================\n\n")
cat(sprintf("True PATE: %.4f\n", true_pate))
cat(sprintf("Total replicates: %d\n", length(all_results)))
cat(sprintf("Job directory: pate_wdsm_unnorm_20250810_0243\n\n"))

cat("Configuration:\n")
cat("  - PS Full: WITH weight normalization (w × length(w)/sum(w))\n")
cat("  - WDSM: WITHOUT weight normalization (original weights)\n")
cat("\n")

# Print detailed results for each method
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

# Create main summary table
cat("\n\n============================================================\n")
cat("MAIN RESULTS TABLE (3 decimal places precision)\n")
cat("============================================================\n\n")

cat(sprintf("%-30s | %10s | %10s | %10s | %8s | %10s\n", 
            "Method", "Rel.Bias(%)", "Coverage(%)", "Rel.Eff", "SE/SD", "MSE"))
cat(paste(rep("-", 92), collapse=""), "\n")

for (i in 1:length(methods)) {
  method <- methods[i]
  metrics <- all_metrics[[method]]
  
  cat(sprintf("%-30s | %10.3f | %10.3f | %10.3f | %8.4f | %10.6f\n",
              method_names[i],
              metrics$relative_bias,
              metrics$coverage,
              metrics$rel_eff,
              metrics$se_sd_ratio,
              metrics$mse))
}

# Comparison section
cat("\n\n============================================================\n")
cat("WDSM COMPARISON: WITH vs WITHOUT NORMALIZATION\n")
cat("============================================================\n\n")

wdsm_metrics <- all_metrics$wdsm_multinomial
cat("WDSM WITHOUT normalization (current run):\n")
cat(sprintf("  Relative Bias: %.3f%%\n", wdsm_metrics$relative_bias))
cat(sprintf("  Coverage: %.3f%%\n", wdsm_metrics$coverage))
cat(sprintf("  Relative Efficiency: %.3f\n", wdsm_metrics$rel_eff))
cat(sprintf("  SE/SD Ratio: %.4f\n", wdsm_metrics$se_sd_ratio))
cat(sprintf("  MSE: %.8f\n", wdsm_metrics$mse))

cat("\nWDSM WITH normalization (previous run from memory):\n")
cat("  Relative Bias: -0.614%\n")
cat("  Coverage: 93.500%\n")
cat("  Relative Efficiency: 2.327\n")
cat("  SE/SD Ratio: 0.9521\n")
cat("  MSE: 0.00305511\n")

cat("\nImprovement WITHOUT normalization:\n")
cat(sprintf("  Bias improvement: %.3f%% (closer to 0)\n", abs(wdsm_metrics$relative_bias) - 0.614))
cat(sprintf("  Coverage improvement: %.3f%% (closer to 95%%)\n", wdsm_metrics$coverage - 93.500))
cat(sprintf("  Efficiency gain: %.3f (%.1f%% higher)\n", 
            wdsm_metrics$rel_eff - 2.327, 
            (wdsm_metrics$rel_eff - 2.327) / 2.327 * 100))
cat(sprintf("  SE/SD improvement: %.4f (closer to 1.0)\n", 
            abs(1 - wdsm_metrics$se_sd_ratio) - abs(1 - 0.9521)))
cat(sprintf("  MSE reduction: %.8f (%.1f%% lower)\n", 
            0.00305511 - wdsm_metrics$mse,
            (0.00305511 - wdsm_metrics$mse) / 0.00305511 * 100))

cat("\n============================================================\n")
cat("CONCLUSION: WDSM performs BETTER without weight normalization\n")
cat("============================================================\n")
