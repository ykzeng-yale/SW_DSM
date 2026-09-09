#!/usr/bin/env Rscript

# Load the results
load("comprehensive_patt_comparison_M135_results.RData")

# Recalculate summary statistics correctly
library(dplyr)
library(tidyr)

# Method names
method_names <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
                  "ps_weighted", "dsm_weighted")
method_labels <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                   "PS Full (Survey-Weighted)", "WDSM V1 (Survey-Weighted)")

# Initialize summary statistics for each M value
summary_stats_all <- list()

for (M_val in M_values) {
  M_key <- paste0("M", M_val)
  cat("\n============================================================\n")
  cat("Calculating summary statistics for M =", M_val, "\n")
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
  
  # Calculate summary statistics
  summary_stats <- data.frame(
    Method = method_labels,
    M = M_val,
    Mean_Estimate = round(colMeans(estimates, na.rm = TRUE), 4),
    Mean_SE = round(colMeans(ses, na.rm = TRUE), 4),
    Empirical_SD = round(apply(estimates, 2, sd, na.rm = TRUE), 4),
    stringsAsFactors = FALSE
  )
  
  # Add bias and RMSE
  summary_stats$Bias <- round(summary_stats$Mean_Estimate - true_patt, 4)
  summary_stats$Relative_Bias <- paste0(round(summary_stats$Bias / true_patt * 100, 1), "%")
  summary_stats$RMSE <- round(sqrt(summary_stats$Bias^2 + summary_stats$Empirical_SD^2), 4)
  
  # Calculate coverage
  coverage <- numeric(length(method_names))
  for (j in 1:length(method_names)) {
    coverage[j] <- mean(ci_lowers[,j] <= true_patt & ci_uppers[,j] >= true_patt, na.rm = TRUE) * 100
  }
  summary_stats$Coverage <- paste0(round(coverage, 1), "%")
  
  # Mean CI width
  summary_stats$Mean_CI_Width <- round(colMeans(ci_uppers - ci_lowers, na.rm = TRUE), 4)
  
  # Count failures
  summary_stats$N_Failed <- colSums(is.na(estimates))
  summary_stats$N_Success <- colSums(!is.na(estimates))
  
  # Calculate relative efficiency (using PS unweighted as reference)
  ps_var <- var(estimates[, "ps_unweighted"], na.rm = TRUE)
  summary_stats$Relative_Efficiency <- round(ps_var / apply(estimates, 2, var, na.rm = TRUE), 3)
  
  summary_stats_all[[M_key]] <- summary_stats
  
  # Print summary
  print(summary_stats[, c("Method", "Mean_Estimate", "Bias", "Relative_Bias", 
                          "RMSE", "Coverage", "N_Success")])
}

# Save updated results
save(all_results, summary_stats_all, true_patt, M_values, 
     file = "comprehensive_patt_comparison_M135_results_fixed.RData")

# Print final summary
cat("\n============================================================\n")
cat("CORRECTED SUMMARY STATISTICS\n")
cat("True PATT:", true_patt, "\n")
cat("============================================================\n")

for (M_val in M_values) {
  cat("\n--- M =", M_val, "---\n")
  print(summary_stats_all[[paste0("M", M_val)]][, c("Method", "Mean_Estimate", 
                                                      "Relative_Bias", "Coverage", 
                                                      "Relative_Efficiency")])
}
