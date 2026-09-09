#!/usr/bin/env Rscript

library(dplyr)

# True PATE for poor overlap
true_pate <- 0.8664

# Process all scenarios
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_summaries <- list()

for (scenario in scenarios) {
  cat("\n========================================\n")
  cat(sprintf("Processing %s scenario\n", scenario))
  cat("========================================\n")
  
  file_name <- sprintf("pooroverlap_%s_20rep_results.RData", scenario)
  if (!file.exists(file_name)) {
    cat(sprintf("File not found: %s\n", file_name))
    next
  }
  
  load(file_name)
  
  # Collect results
  results_list <- list()
  for (i in 1:length(all_results)) {
    rep_data <- all_results[[i]][[1]]  # Get the scenario data
    
    if (is.list(rep_data)) {
      for (method_name in names(rep_data)) {
        method_data <- rep_data[[method_name]]
        
        if (is.list(method_data) && !is.null(method_data$estimate)) {
          # Check different CI formats
          ci_lower <- NA
          ci_upper <- NA
          
          if (!is.null(method_data$ci_lower) && !is.null(method_data$ci_upper)) {
            ci_lower <- method_data$ci_lower
            ci_upper <- method_data$ci_upper
          } else if (!is.null(method_data$ci) && length(method_data$ci) >= 2) {
            ci_lower <- method_data$ci[1]
            ci_upper <- method_data$ci[2]
          }
          
          results_list[[length(results_list) + 1]] <- data.frame(
            scenario = scenario,
            rep = i,
            method = method_name,
            estimate = method_data$estimate,
            se = ifelse(!is.null(method_data$se), method_data$se, NA),
            ci_lower = ci_lower,
            ci_upper = ci_upper,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  
  if (length(results_list) > 0) {
    combined_results <- do.call(rbind, results_list)
    
    # Calculate summary statistics
    summary_stats <- combined_results %>%
      group_by(method) %>%
      summarise(
        n = n(),
        mean_estimate = mean(estimate, na.rm = TRUE),
        bias = mean(estimate - true_pate, na.rm = TRUE),
        relative_bias = 100 * bias / true_pate,
        empirical_se = sd(estimate, na.rm = TRUE),
        mean_se = mean(se, na.rm = TRUE),
        se_ratio = ifelse(empirical_se > 0, mean_se / empirical_se, NA),
        coverage = mean(ci_lower <= true_pate & ci_upper >= true_pate, na.rm = TRUE) * 100,
        rmse = sqrt(mean((estimate - true_pate)^2, na.rm = TRUE)),
        .groups = "drop"
      ) %>%
      mutate(scenario = scenario) %>%
      arrange(abs(relative_bias))
    
    cat(sprintf("\nMethods with results: %s\n", 
                paste(unique(combined_results$method), collapse=", ")))
    cat(sprintf("Total results: %d\n", nrow(combined_results)))
    
    # Print summary
    print(as.data.frame(summary_stats %>% select(method, n, relative_bias, coverage, se_ratio)), 
          digits = 2)
    
    all_summaries[[scenario]] <- summary_stats
  } else {
    cat("No valid results found!\n")
  }
  
  rm(all_results)  # Clean up
}

# Create final comparison table
cat("\n\n========================================\n")
cat("FINAL COMPARISON ACROSS ALL SCENARIOS\n")
cat("========================================\n")

if (length(all_summaries) > 0) {
  final_table <- bind_rows(all_summaries) %>%
    select(scenario, method, relative_bias, coverage, se_ratio) %>%
    arrange(scenario, method)
  
  # Print as formatted table
  cat("\nAll Methods:\n")
  print(as.data.frame(final_table), digits = 2, row.names = FALSE)
  
  # WDSM only
  wdsm_only <- final_table %>% 
    filter(grepl("wdsm", method, ignore.case = TRUE))
  
  if (nrow(wdsm_only) > 0) {
    cat("\n\nWDSM Performance Only:\n")
    print(as.data.frame(wdsm_only), digits = 2, row.names = FALSE)
    
    # Check if CorCor meets expectations
    corcor_wdsm <- wdsm_only %>% filter(scenario == "CorCor")
    if (nrow(corcor_wdsm) > 0) {
      cat("\n*** WDSM in CorCor (Expected: <1% bias, ~95% coverage) ***\n")
      cat(sprintf("  Actual Bias: %.2f%%\n", corcor_wdsm$relative_bias))
      cat(sprintf("  Actual Coverage: %.1f%%\n", corcor_wdsm$coverage))
      
      if (abs(corcor_wdsm$relative_bias) < 1) {
        cat("  ✅ Bias < 1% achieved!\n")
      } else {
        cat("  ⚠️ Bias > 1% - may need more replications or further debugging\n")
      }
      
      if (corcor_wdsm$coverage > 90 && corcor_wdsm$coverage < 98) {
        cat("  ✅ Coverage is nominal (90-98%)!\n")
      } else {
        cat(sprintf("  ⚠️ Coverage %.1f%% is outside nominal range\n", corcor_wdsm$coverage))
      }
    }
  }
  
  # Save combined results
  save(all_summaries, file = "pooroverlap_20rep_all_summaries.RData")
  cat("\n\nResults saved to pooroverlap_20rep_all_summaries.RData\n")
}
