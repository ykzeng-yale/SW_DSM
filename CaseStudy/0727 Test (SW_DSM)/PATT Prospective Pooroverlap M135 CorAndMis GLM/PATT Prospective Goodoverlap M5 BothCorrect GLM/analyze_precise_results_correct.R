# Load and analyze results with high precision
load("comprehensive_patt_comparison_results_1000.RData")

# Extract estimates and SEs from each replicate
n_reps <- length(all_results)

# Initialize storage
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "dsm_weighted")
method_labels <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)", 
                   "PS Full (Survey-Weighted)", "WDSM V1 (Survey-Weighted)")

results_matrix <- list()
for (method in methods) {
  estimates <- numeric(n_reps)
  ses <- numeric(n_reps)
  ci_lower <- numeric(n_reps)
  ci_upper <- numeric(n_reps)
  
  for (i in 1:n_reps) {
    if (!is.null(all_results[[i]][[method]])) {
      estimates[i] <- all_results[[i]][[method]]$estimate
      ses[i] <- all_results[[i]][[method]]$se
      ci_lower[i] <- all_results[[i]][[method]]$ci_lower
      ci_upper[i] <- all_results[[i]][[method]]$ci_upper
    } else {
      estimates[i] <- NA
      ses[i] <- NA
      ci_lower[i] <- NA
      ci_upper[i] <- NA
    }
  }
  
  results_matrix[[method]] <- list(
    estimates = estimates,
    ses = ses,
    ci_lower = ci_lower,
    ci_upper = ci_upper
  )
}

# Calculate precise metrics
cat("\nPrecise Results (1000 replicates) - All Values to 3 Decimal Places:\n")
cat(paste(rep("=", 90), collapse=""), "\n\n")

# Header
cat(sprintf("%-30s %10s %10s %10s %10s %10s %10s\n", 
            "Method", "Bias", "Rel_Bias%", "Coverage", "Rel_Eff", "SE_Ratio", "Emp_SD"))
cat(paste(rep("-", 90), collapse=""), "\n")

# Get PS empirical SD for relative efficiency calculation
ps_emp_sd <- sd(results_matrix[["ps_unweighted"]]$estimates, na.rm = TRUE)
ps_var <- ps_emp_sd^2

# Store detailed results
detailed_results <- list()

for (i in 1:length(methods)) {
  method <- methods[i]
  label <- method_labels[i]
  res <- results_matrix[[method]]
  
  # Calculate metrics
  estimates <- res$estimates[!is.na(res$estimates)]
  ses <- res$ses[!is.na(res$ses)]
  n_valid <- length(estimates)
  
  mean_est <- mean(estimates)
  emp_sd <- sd(estimates)
  bias <- mean_est - true_patt
  rel_bias <- (bias / true_patt) * 100
  
  # Coverage
  covered <- (res$ci_lower <= true_patt & res$ci_upper >= true_patt)
  coverage <- mean(covered, na.rm = TRUE)
  
  # Relative efficiency (PS variance / method variance)
  rel_eff <- ps_var / (emp_sd^2)
  
  # SE ratio (average reported SE / empirical SD)
  mean_se <- mean(ses)
  se_ratio <- mean_se / emp_sd
  
  # Store detailed results
  detailed_results[[label]] <- list(
    mean_estimate = mean_est,
    bias = bias,
    relative_bias = rel_bias,
    empirical_sd = emp_sd,
    mean_se = mean_se,
    se_ratio = se_ratio,
    coverage = coverage,
    relative_efficiency = rel_eff,
    n_valid = n_valid
  )
  
  # Print with 3 decimal places
  cat(sprintf("%-30s %10.4f %10.3f %10.3f %10.3f %10.3f %10.4f\n",
              label, bias, rel_bias, coverage, rel_eff, se_ratio, emp_sd))
}

cat(paste(rep("-", 90), collapse=""), "\n\n")

# Additional detailed stats for WDSM
cat("Detailed WDSM V1 Statistics:\n")
wdsm_res <- results_matrix[["dsm_weighted"]]
wdsm_est <- wdsm_res$estimates[!is.na(wdsm_res$estimates)]
wdsm_se <- wdsm_res$ses[!is.na(wdsm_res$ses)]

cat(sprintf("  Mean Estimate: %.6f\n", mean(wdsm_est)))
cat(sprintf("  True PATT: %.6f\n", true_patt))
cat(sprintf("  Bias: %.6f\n", mean(wdsm_est) - true_patt))
cat(sprintf("  Relative Bias: %.4f%%\n", (mean(wdsm_est) - true_patt) / true_patt * 100))
cat(sprintf("  Empirical SD: %.6f\n", sd(wdsm_est)))
cat(sprintf("  Mean Reported SE: %.6f\n", mean(wdsm_se)))
cat(sprintf("  Coverage: %.4f (%.3f%%)\n", 
            mean(wdsm_res$ci_lower <= true_patt & wdsm_res$ci_upper >= true_patt, na.rm = TRUE),
            mean(wdsm_res$ci_lower <= true_patt & wdsm_res$ci_upper >= true_patt, na.rm = TRUE) * 100))
cat(sprintf("  Bootstrap Failures: %d/%d\n", sum(is.na(wdsm_res$estimates)), length(wdsm_res$estimates)))
cat(sprintf("  95%% CI Width: %.6f\n", mean(wdsm_res$ci_upper - wdsm_res$ci_lower, na.rm = TRUE)))

# Save detailed results
save(detailed_results, file = "detailed_results_1000.RData")