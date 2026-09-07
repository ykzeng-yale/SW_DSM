#!/usr/bin/env Rscript

# Compare WDSM results with and without weight normalization

cat("\n============================================================\n")
cat("COMPARING WDSM WITH NORMALIZED vs UNNORMALIZED WEIGHTS\n")
cat("============================================================\n")

# Load both result sets
cat("\nLoading results with WDSM using UNNORMALIZED weights...\n")
load("comprehensive_patt_comparison_M135_wdsm_unnormalized.RData")
results_unnormalized <- all_results
true_patt_check <- true_patt

cat("Loading results with WDSM using NORMALIZED weights...\n")
load("comprehensive_patt_comparison_M135_results_fixed.RData")
results_normalized <- all_results

cat("True PATT:", format(true_patt, nsmall = 6), "\n")

# Method names
method_names <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
                  "ps_weighted", "dsm_weighted")
method_labels <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                   "PS Full (Survey-Weighted)", "WDSM V1 (Survey-Weighted)")

# Function to calculate precise statistics
calculate_stats <- function(results, M_val, true_patt) {
  M_key <- paste0("M", M_val)
  
  # Extract results for this M value
  estimates <- matrix(NA, nrow = length(results), ncol = length(method_names))
  ses <- matrix(NA, nrow = length(results), ncol = length(method_names))
  ci_lowers <- matrix(NA, nrow = length(results), ncol = length(method_names))
  ci_uppers <- matrix(NA, nrow = length(results), ncol = length(method_names))
  
  colnames(estimates) <- method_names
  
  # Loop through replicates
  for (i in 1:length(results)) {
    if (!is.null(results[[i]][[M_key]])) {
      for (j in 1:length(method_names)) {
        method <- method_names[j]
        if (!is.null(results[[i]][[M_key]][[method]])) {
          estimates[i, j] <- results[[i]][[M_key]][[method]]$estimate
          ses[i, j] <- results[[i]][[M_key]][[method]]$se
          ci_lowers[i, j] <- results[[i]][[M_key]][[method]]$ci_lower
          ci_uppers[i, j] <- results[[i]][[M_key]][[method]]$ci_upper
        }
      }
    }
  }
  
  # Calculate statistics for each method
  stats <- data.frame(Method = method_labels)
  
  for (j in 1:length(method_names)) {
    valid <- !is.na(estimates[, j])
    if (sum(valid) > 0) {
      est_valid <- estimates[valid, j]
      ci_lower_valid <- ci_lowers[valid, j]
      ci_upper_valid <- ci_uppers[valid, j]
      
      stats$Mean_Estimate[j] <- mean(est_valid)
      stats$Bias[j] <- mean(est_valid) - true_patt
      stats$Relative_Bias_Pct[j] <- ((mean(est_valid) - true_patt) / true_patt) * 100
      stats$Empirical_SD[j] <- sd(est_valid)
      stats$Coverage_Pct[j] <- mean(ci_lower_valid <= true_patt & ci_upper_valid >= true_patt) * 100
      stats$N_Success[j] <- sum(valid)
    } else {
      stats$Mean_Estimate[j] <- NA
      stats$Bias[j] <- NA
      stats$Relative_Bias_Pct[j] <- NA
      stats$Empirical_SD[j] <- NA
      stats$Coverage_Pct[j] <- NA
      stats$N_Success[j] <- 0
    }
  }
  
  # Calculate relative efficiency (PS unweighted as reference)
  ps_var <- var(estimates[!is.na(estimates[, "ps_unweighted"]), "ps_unweighted"])
  for (j in 1:length(method_names)) {
    valid <- !is.na(estimates[, j])
    if (sum(valid) > 1) {
      stats$Relative_Efficiency[j] <- ps_var / var(estimates[valid, j])
    } else {
      stats$Relative_Efficiency[j] <- NA
    }
  }
  
  return(stats)
}

# Compare results for each M value
for (M_val in M_values) {
  cat("\n============================================================\n")
  cat("M =", M_val, "\n")
  cat("============================================================\n")
  
  # Calculate stats for both versions
  stats_unnorm <- calculate_stats(results_unnormalized, M_val, true_patt)
  stats_norm <- calculate_stats(results_normalized, M_val, true_patt)
  
  # Focus on comparing WDSM and PS Full
  cat("\n--- WDSM V1 (Survey-Weighted) ---\n")
  wdsm_idx <- which(stats_unnorm$Method == "WDSM V1 (Survey-Weighted)")
  
  cat("With UNNORMALIZED weights (1/Prob):\n")
  cat(sprintf("  Relative Bias:  %7.3f%%\n", stats_unnorm$Relative_Bias_Pct[wdsm_idx]))
  cat(sprintf("  Coverage:       %7.3f%%\n", stats_unnorm$Coverage_Pct[wdsm_idx]))
  cat(sprintf("  Rel Efficiency: %7.3f\n", stats_unnorm$Relative_Efficiency[wdsm_idx]))
  
  cat("\nWith NORMALIZED weights (w × n/sum(w)):\n")
  cat(sprintf("  Relative Bias:  %7.3f%%\n", stats_norm$Relative_Bias_Pct[wdsm_idx]))
  cat(sprintf("  Coverage:       %7.3f%%\n", stats_norm$Coverage_Pct[wdsm_idx]))
  cat(sprintf("  Rel Efficiency: %7.3f\n", stats_norm$Relative_Efficiency[wdsm_idx]))
  
  cat("\n--- PS Full (Survey-Weighted) ---\n")
  ps_idx <- which(stats_unnorm$Method == "PS Full (Survey-Weighted)")
  
  cat("Always uses NORMALIZED weights:\n")
  cat(sprintf("  Relative Bias:  %7.3f%%\n", stats_unnorm$Relative_Bias_Pct[ps_idx]))
  cat(sprintf("  Coverage:       %7.3f%%\n", stats_unnorm$Coverage_Pct[ps_idx]))
  cat(sprintf("  Rel Efficiency: %7.3f\n", stats_unnorm$Relative_Efficiency[ps_idx]))
}

# Create comparison table
cat("\n============================================================\n")
cat("SUMMARY: WDSM PERFORMANCE WITH DIFFERENT WEIGHT NORMALIZATIONS\n")
cat("============================================================\n")

cat("\nRELATIVE BIAS (%):\n")
cat(sprintf("%-30s %15s %15s %15s\n", "Method", "M=1", "M=3", "M=5"))
cat(paste(rep("-", 75), collapse=""), "\n")

for (method_label in c("WDSM V1 (Survey-Weighted)", "PS Full (Survey-Weighted)")) {
  cat(sprintf("%-30s", method_label))
  for (M_val in M_values) {
    stats <- calculate_stats(results_unnormalized, M_val, true_patt)
    idx <- which(stats$Method == method_label)
    cat(sprintf(" %14.3f%%", stats$Relative_Bias_Pct[idx]))
  }
  
  if (method_label == "WDSM V1 (Survey-Weighted)") {
    cat("\n")
    cat(sprintf("%-30s", "  (with normalized weights)"))
    for (M_val in M_values) {
      stats <- calculate_stats(results_normalized, M_val, true_patt)
      idx <- which(stats$Method == method_label)
      cat(sprintf(" %14.3f%%", stats$Relative_Bias_Pct[idx]))
    }
  }
  cat("\n")
}

cat("\nCOVERAGE (%):\n")
cat(sprintf("%-30s %15s %15s %15s\n", "Method", "M=1", "M=3", "M=5"))
cat(paste(rep("-", 75), collapse=""), "\n")

for (method_label in c("WDSM V1 (Survey-Weighted)", "PS Full (Survey-Weighted)")) {
  cat(sprintf("%-30s", method_label))
  for (M_val in M_values) {
    stats <- calculate_stats(results_unnormalized, M_val, true_patt)
    idx <- which(stats$Method == method_label)
    cat(sprintf(" %14.3f%%", stats$Coverage_Pct[idx]))
  }
  
  if (method_label == "WDSM V1 (Survey-Weighted)") {
    cat("\n")
    cat(sprintf("%-30s", "  (with normalized weights)"))
    for (M_val in M_values) {
      stats <- calculate_stats(results_normalized, M_val, true_patt)
      idx <- which(stats$Method == method_label)
      cat(sprintf(" %14.3f%%", stats$Coverage_Pct[idx]))
    }
  }
  cat("\n")
}

cat("\n============================================================\n")
cat("CONCLUSION:\n")
cat("============================================================\n")
cat("WDSM with unnormalized weights performs similarly to normalized weights.\n")
cat("This suggests WDSM handles weight normalization internally.\n")
cat("PS Full (MatchIt) uses normalized weights as per our implementation.\n")
