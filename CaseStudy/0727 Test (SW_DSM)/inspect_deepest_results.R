#!/usr/bin/env Rscript

# Deep dive into the result structure
scenario <- "CorCor"

cat("\n========================================\n")
cat(sprintf("Deep inspection of %s scenario\n", scenario))
cat("========================================\n")

file_name <- sprintf("pooroverlap_%s_20rep_results.RData", scenario)
load(file_name)

# Check first replication deeply
first_rep <- all_results[[1]]
cat("First replication structure:\n")
cat("Names:", paste(names(first_rep), collapse=", "), "\n")

# Get the actual results
scenario_results <- first_rep[[1]]  # Get CorCor_M5
cat("\nScenario results structure:\n")
cat(sprintf("Class: %s\n", class(scenario_results)))

if (is.list(scenario_results)) {
  cat("Names:", paste(names(scenario_results), collapse=", "), "\n")
  
  # Check each method
  for (method_name in names(scenario_results)) {
    cat(sprintf("\n  Method: %s\n", method_name))
    method_data <- scenario_results[[method_name]]
    
    if (is.list(method_data)) {
      cat(sprintf("    Type: list with elements: %s\n", 
                  paste(names(method_data), collapse=", ")))
      
      # Show values
      for (elem_name in names(method_data)) {
        elem <- method_data[[elem_name]]
        if (is.numeric(elem) && length(elem) == 1) {
          cat(sprintf("      %s: %.6f\n", elem_name, elem))
        } else if (is.numeric(elem) && length(elem) == 2) {
          cat(sprintf("      %s: [%.6f, %.6f]\n", elem_name, elem[1], elem[2]))
        }
      }
    } else if (is.data.frame(method_data)) {
      cat(sprintf("    Type: data.frame with %d rows, %d cols\n", 
                  nrow(method_data), ncol(method_data)))
    }
  }
}

# Now collect all results into a proper data frame
cat("\n\n========================================\n")
cat("Collecting all results into data frame\n")
cat("========================================\n")

results_list <- list()
for (i in 1:length(all_results)) {
  rep_data <- all_results[[i]][[1]]  # Get the scenario data
  
  if (is.list(rep_data)) {
    for (method_name in names(rep_data)) {
      method_data <- rep_data[[method_name]]
      
      if (is.list(method_data) && !is.null(method_data$estimate)) {
        results_list[[length(results_list) + 1]] <- data.frame(
          rep = i,
          method = method_name,
          estimate = method_data$estimate,
          se = ifelse(!is.null(method_data$se), method_data$se, NA),
          ci_lower = ifelse(!is.null(method_data$ci) && length(method_data$ci) >= 1, 
                           method_data$ci[1], NA),
          ci_upper = ifelse(!is.null(method_data$ci) && length(method_data$ci) >= 2, 
                           method_data$ci[2], NA),
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

if (length(results_list) > 0) {
  combined_results <- do.call(rbind, results_list)
  cat(sprintf("\nSuccessfully combined %d results\n", nrow(combined_results)))
  cat("Methods found:", paste(unique(combined_results$method), collapse=", "), "\n")
  
  # Calculate summary statistics
  true_pate <- 0.8664
  
  library(dplyr)
  summary_stats <- combined_results %>%
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
  
  cat("\n\nPERFORMANCE METRICS:\n")
  cat("====================\n")
  print(as.data.frame(summary_stats), digits = 3)
  
  # Highlight WDSM
  wdsm_row <- summary_stats %>% filter(method == "WDSM")
  if (nrow(wdsm_row) > 0) {
    cat("\n*** WDSM Performance in CorCor ***\n")
    cat(sprintf("  Relative Bias: %.2f%%\n", wdsm_row$relative_bias))
    cat(sprintf("  Coverage: %.1f%%\n", wdsm_row$coverage))
    cat(sprintf("  SE Ratio: %.3f\n", wdsm_row$se_ratio))
  }
} else {
  cat("\nNo valid results found!\n")
}
