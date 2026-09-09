#!/usr/bin/env Rscript

# Load the results
load("comprehensive_patt_comparison_M135_results.RData")

# Set options for more digits
options(digits = 10)

# Method names
method_names <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
                  "ps_weighted", "dsm_weighted")
method_labels <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                   "PS Full (Survey-Weighted)", "WDSM V1 (Survey-Weighted)")

# Initialize summary statistics for each M value
precise_summary <- list()

cat("\n============================================================\n")
cat("PRECISE SUMMARY STATISTICS (3 decimal places)\n")
cat("True PATT:", format(true_patt, nsmall = 6), "\n")
cat("============================================================\n")

for (M_val in M_values) {
  M_key <- paste0("M", M_val)
  cat("\n============================================================\n")
  cat("M =", M_val, "\n")
  cat("============================================================\n")
  
  # Extract results for this M value
  estimates <- matrix(NA, nrow = length(all_results), ncol = length(method_names))
  ses <- matrix(NA, nrow = length(all_results), ncol = length(method_names))
  ci_lowers <- matrix(NA, nrow = length(all_results), ncol = length(method_names))
  ci_uppers <- matrix(NA, nrow = length(all_results), ncol = length(method_names))
  
  colnames(estimates) <- method_names
  colnames(ses) <- method_names
  colnames(ci_lowers) <- method_names
  colnames(ci_uppers) <- method_names
  
  # Loop through replicates
  for (i in 1:length(all_results)) {
    if (!is.null(all_results[[i]][[M_key]])) {
      for (j in 1:length(method_names)) {
        method <- method_names[j]
        if (!is.null(all_results[[i]][[M_key]][[method]])) {
          estimates[i, j] <- all_results[[i]][[M_key]][[method]]$estimate
          ses[i, j] <- all_results[[i]][[M_key]][[method]]$se
          ci_lowers[i, j] <- all_results[[i]][[M_key]][[method]]$ci_lower
          ci_uppers[i, j] <- all_results[[i]][[M_key]][[method]]$ci_upper
        }
      }
    }
  }
  
  # Calculate precise summary statistics
  mean_estimates <- colMeans(estimates, na.rm = TRUE)
  mean_ses <- colMeans(ses, na.rm = TRUE)
  empirical_sds <- apply(estimates, 2, sd, na.rm = TRUE)
  
  # Bias
  biases <- mean_estimates - true_patt
  relative_biases <- (biases / true_patt) * 100
  
  # RMSE
  rmses <- sqrt(biases^2 + empirical_sds^2)
  
  # Coverage (proportion of CIs containing true value)
  coverage <- numeric(length(method_names))
  for (j in 1:length(method_names)) {
    coverage[j] <- mean(ci_lowers[,j] <= true_patt & ci_uppers[,j] >= true_patt, na.rm = TRUE) * 100
  }
  
  # Mean CI width
  mean_ci_widths <- colMeans(ci_uppers - ci_lowers, na.rm = TRUE)
  
  # Relative efficiency (using PS unweighted as reference)
  ps_var <- var(estimates[, "ps_unweighted"], na.rm = TRUE)
  relative_efficiencies <- ps_var / apply(estimates, 2, var, na.rm = TRUE)
  
  # Count successes
  n_success <- colSums(!is.na(estimates))
  
  # Create results data frame
  results_df <- data.frame(
    Method = method_labels,
    Mean_Estimate = mean_estimates,
    Mean_SE = mean_ses,
    Empirical_SD = empirical_sds,
    Bias = biases,
    Relative_Bias_Pct = relative_biases,
    RMSE = rmses,
    Coverage_Pct = coverage,
    CI_Width = mean_ci_widths,
    Relative_Efficiency = relative_efficiencies,
    N_Success = n_success,
    stringsAsFactors = FALSE
  )
  
  # Print formatted results
  cat("\n")
  for (k in 1:nrow(results_df)) {
    cat(sprintf("%-30s\n", results_df$Method[k]))
    cat(sprintf("  Mean Estimate:       %8.6f\n", results_df$Mean_Estimate[k]))
    cat(sprintf("  Bias:                %8.6f\n", results_df$Bias[k]))
    cat(sprintf("  Relative Bias:       %7.3f%%\n", results_df$Relative_Bias_Pct[k]))
    cat(sprintf("  Empirical SD:        %8.6f\n", results_df$Empirical_SD[k]))
    cat(sprintf("  RMSE:                %8.6f\n", results_df$RMSE[k]))
    cat(sprintf("  Coverage:            %7.3f%%\n", results_df$Coverage_Pct[k]))
    cat(sprintf("  Relative Efficiency: %8.3f\n", results_df$Relative_Efficiency[k]))
    cat(sprintf("  Success Rate:        %4d/1000\n", results_df$N_Success[k]))
    cat("\n")
  }
  
  precise_summary[[M_key]] <- results_df
}

# Create comparison table
cat("\n============================================================\n")
cat("COMPARISON TABLE: RELATIVE BIAS (%) BY M VALUE\n")
cat("============================================================\n")
cat(sprintf("%-30s %10s %10s %10s\n", "Method", "M=1", "M=3", "M=5"))
cat(paste(rep("-", 62), collapse=""), "\n")
for (i in 1:length(method_labels)) {
  cat(sprintf("%-30s", method_labels[i]))
  for (M_val in M_values) {
    bias_pct <- precise_summary[[paste0("M", M_val)]]$Relative_Bias_Pct[i]
    cat(sprintf(" %9.3f%%", bias_pct))
  }
  cat("\n")
}

cat("\n============================================================\n")
cat("COMPARISON TABLE: COVERAGE (%) BY M VALUE\n")
cat("============================================================\n")
cat(sprintf("%-30s %10s %10s %10s\n", "Method", "M=1", "M=3", "M=5"))
cat(paste(rep("-", 62), collapse=""), "\n")
for (i in 1:length(method_labels)) {
  cat(sprintf("%-30s", method_labels[i]))
  for (M_val in M_values) {
    cov <- precise_summary[[paste0("M", M_val)]]$Coverage_Pct[i]
    cat(sprintf(" %9.3f%%", cov))
  }
  cat("\n")
}

cat("\n============================================================\n")
cat("COMPARISON TABLE: RELATIVE EFFICIENCY BY M VALUE\n")
cat("============================================================\n")
cat(sprintf("%-30s %10s %10s %10s\n", "Method", "M=1", "M=3", "M=5"))
cat(paste(rep("-", 62), collapse=""), "\n")
for (i in 1:length(method_labels)) {
  cat(sprintf("%-30s", method_labels[i]))
  for (M_val in M_values) {
    eff <- precise_summary[[paste0("M", M_val)]]$Relative_Efficiency[i]
    cat(sprintf(" %10.3f", eff))
  }
  cat("\n")
}

# Save precise results
save(precise_summary, true_patt, M_values, file = "precise_summary_results.RData")

cat("\n============================================================\n")
cat("Results saved to: precise_summary_results.RData\n")
cat("============================================================\n")
