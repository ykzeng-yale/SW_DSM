#!/usr/bin/env Rscript

library(tidyverse)

# True PATE for poor overlap
true_pate <- 0.8664

# Load and analyze results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

# Collect all results
all_results <- list()

for (scenario in scenarios) {
  cat("\n========================================\n")
  cat(sprintf("Analyzing %s scenario\n", scenario))
  cat("========================================\n")
  
  # Load results
  file_name <- sprintf("pooroverlap_%s_20rep_results.RData", scenario)
  if (file.exists(file_name)) {
    load(file_name)
    
    if (exists("all_results")) {
      results_df <- all_results
      
      # Check structure
      cat(sprintf("\nLoaded results with %d rows\n", nrow(results_df)))
      cat("Methods included:", paste(unique(results_df$method), collapse=", "), "\n")
      
      # Calculate metrics
      summary_stats <- results_df %>%
        group_by(method) %>%
        summarise(
          n = n(),
          mean_estimate = mean(estimate, na.rm = TRUE),
          bias = mean(estimate - true_pate, na.rm = TRUE),
          relative_bias = 100 * bias / true_pate,
          empirical_se = sd(estimate, na.rm = TRUE),
          mean_se = mean(se, na.rm = TRUE),
          se_ratio = mean_se / empirical_se,
          coverage = mean(ci_lower <= true_pate & ci_upper >= true_pate, na.rm = TRUE) * 100,
          rmse = sqrt(mean((estimate - true_pate)^2, na.rm = TRUE)),
          .groups = "drop"
        ) %>%
        arrange(abs(relative_bias))
      
      cat("\nPerformance Metrics:\n")
      print(summary_stats, n = Inf)
      
      # Store for comparison
      all_results[[scenario]] <- summary_stats
      
      # Highlight WDSM performance
      wdsm_row <- summary_stats %>% filter(method == "WDSM")
      if (nrow(wdsm_row) > 0) {
        cat("\n*** WDSM Performance ***\n")
        cat(sprintf("  Relative Bias: %.2f%%\n", wdsm_row$relative_bias))
        cat(sprintf("  Coverage: %.1f%%\n", wdsm_row$coverage))
        cat(sprintf("  SE Ratio: %.3f\n", wdsm_row$se_ratio))
      }
      
      # Clean up the loaded object
      rm(all_results)
    } else {
      cat("ERROR: 'all_results' object not found in file\n")
    }
  } else {
    cat(sprintf("File not found: %s\n", file_name))
  }
}

# Create comparison table
cat("\n\n========================================\n")
cat("COMPARISON ACROSS SCENARIOS (WDSM Only)\n")
cat("========================================\n")

wdsm_comparison <- data.frame()
for (scenario in names(all_results)) {
  wdsm_row <- all_results[[scenario]] %>% 
    filter(method == "WDSM") %>%
    mutate(scenario = scenario) %>%
    select(scenario, relative_bias, coverage, se_ratio)
  
  if (nrow(wdsm_row) > 0) {
    wdsm_comparison <- rbind(wdsm_comparison, wdsm_row)
  }
}

if (nrow(wdsm_comparison) > 0) {
  cat("\nWDSM Performance Across Model Specifications:\n")
  print(wdsm_comparison)
  
  # Check expected patterns
  cat("\n*** Checking Expected Patterns ***\n")
  
  # CorCor should have best performance
  corcor_bias <- abs(wdsm_comparison$relative_bias[wdsm_comparison$scenario == "CorCor"])
  corcor_cov <- wdsm_comparison$coverage[wdsm_comparison$scenario == "CorCor"]
  
  if (length(corcor_bias) > 0) {
    if (corcor_bias < 1) {
      cat("✅ CorCor: Bias < 1% (", sprintf("%.2f%%", corcor_bias), ")\n")
    } else {
      cat("⚠️ CorCor: Bias > 1% (", sprintf("%.2f%%", corcor_bias), ")\n")
    }
    
    if (corcor_cov > 90) {
      cat("✅ CorCor: Coverage > 90% (", sprintf("%.1f%%", corcor_cov), ")\n")
    } else {
      cat("⚠️ CorCor: Coverage < 90% (", sprintf("%.1f%%", corcor_cov), ")\n")
    }
  }
}

# Save summary
save(all_results, file = "pooroverlap_20rep_summary.RData")
cat("\n\nResults saved to pooroverlap_20rep_summary.RData\n")
