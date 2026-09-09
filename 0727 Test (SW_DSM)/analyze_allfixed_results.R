#!/usr/bin/env Rscript

library(dplyr)

# True PATE for poor overlap
true_pate <- 0.8664

# Process all scenarios
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_summaries <- list()

cat("\n========================================\n")
cat("ALL-FIXED RESULTS ANALYSIS\n")
cat("========================================\n")
cat("True PATE:", round(true_pate, 4), "\n\n")

for (scenario in scenarios) {
  cat("========================================\n")
  cat(sprintf("Processing %s scenario\n", scenario))
  cat("========================================\n")
  
  file_name <- sprintf("allfixed_%s_results.RData", scenario)
  if (!file.exists(file_name)) {
    cat(sprintf("File not found: %s\n", file_name))
    next
  }
  
  load(file_name)
  
  # Collect results
  results_list <- list()
  for (i in 1:length(all_results)) {
    if (is.null(all_results[[i]]) || inherits(all_results[[i]], "error") || "error" %in% names(all_results[[i]])) {
      next
    }
    
    rep_data <- all_results[[i]][[paste0(scenario, "_M5")]]
    
    if (is.list(rep_data)) {
      for (method_name in names(rep_data)) {
        method_data <- rep_data[[method_name]]
        
        if (is.list(method_data) && !is.null(method_data$estimate) && !is.na(method_data$estimate)) {
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
    print(as.data.frame(summary_stats %>% 
                       select(method, n, relative_bias, coverage, se_ratio, rmse) %>%
                       mutate(relative_bias = round(relative_bias, 2),
                             coverage = round(coverage, 1),
                             se_ratio = round(se_ratio, 3),
                             rmse = round(rmse, 3))), 
          row.names = FALSE)
    
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
    select(scenario, method, relative_bias, coverage, se_ratio, rmse) %>%
    arrange(scenario, method)
  
  # Print all methods
  cat("\nAll Methods Performance:\n")
  cat("------------------------\n")
  print(as.data.frame(final_table %>%
                     mutate(relative_bias = round(relative_bias, 2),
                           coverage = round(coverage, 1),
                           se_ratio = round(se_ratio, 3),
                           rmse = round(rmse, 3))), 
        row.names = FALSE)
  
  # Check expected patterns
  cat("\n\n========================================\n")
  cat("VERIFICATION OF EXPECTED PATTERNS\n")
  cat("========================================\n")
  
  # Pattern 1: CorCor and CorMis should be similar for PS-based methods
  ps_methods <- c("ps_unweighted", "ps_weighted")
  for (method in ps_methods) {
    corcor_val <- final_table %>% filter(scenario == "CorCor", method == !!method) %>% pull(relative_bias)
    cormis_val <- final_table %>% filter(scenario == "CorMis", method == !!method) %>% pull(relative_bias)
    if (length(corcor_val) > 0 && length(cormis_val) > 0) {
      diff <- abs(corcor_val - cormis_val)
      if (diff < 1) {
        cat(sprintf("✅ %s: CorCor (%.2f%%) ≈ CorMis (%.2f%%) - Pattern confirmed!\n", 
                   method, corcor_val, cormis_val))
      } else {
        cat(sprintf("⚠️ %s: CorCor (%.2f%%) vs CorMis (%.2f%%) - Difference %.2f%%\n", 
                   method, corcor_val, cormis_val, diff))
      }
    }
  }
  
  # Pattern 2: CorCor and MisCor should be similar for PG-based methods
  pg_methods <- c("pg_unweighted", "dsm_unweighted")  # DSM uses PG
  for (method in pg_methods) {
    corcor_val <- final_table %>% filter(scenario == "CorCor", method == !!method) %>% pull(relative_bias)
    miscor_val <- final_table %>% filter(scenario == "MisCor", method == !!method) %>% pull(relative_bias)
    if (length(corcor_val) > 0 && length(miscor_val) > 0) {
      diff <- abs(corcor_val - miscor_val)
      if (diff < 1) {
        cat(sprintf("✅ %s: CorCor (%.2f%%) ≈ MisCor (%.2f%%) - Pattern confirmed!\n", 
                   method, corcor_val, miscor_val))
      } else {
        cat(sprintf("⚠️ %s: CorCor (%.2f%%) vs MisCor (%.2f%%) - Difference %.2f%%\n", 
                   method, corcor_val, miscor_val, diff))
      }
    }
  }
  
  # Pattern 3: MisMis should be worst for all methods
  cat("\nMisMis Performance (Should be worst):\n")
  mismis_data <- final_table %>% filter(scenario == "MisMis")
  for (method in unique(mismis_data$method)) {
    bias <- mismis_data %>% filter(method == !!method) %>% pull(relative_bias)
    cat(sprintf("  %s: %.2f%% bias\n", method, bias))
  }
  
  # WDSM specific analysis
  cat("\n\nWDSM Performance Analysis:\n")
  cat("-------------------------\n")
  wdsm_data <- final_table %>% filter(method == "wdsm_multinomial")
  if (nrow(wdsm_data) > 0) {
    print(as.data.frame(wdsm_data %>%
                       mutate(relative_bias = round(relative_bias, 2),
                             coverage = round(coverage, 1),
                             se_ratio = round(se_ratio, 3),
                             rmse = round(rmse, 3))),
          row.names = FALSE)
    
    # Check CorCor performance
    corcor_wdsm <- wdsm_data %>% filter(scenario == "CorCor")
    if (nrow(corcor_wdsm) > 0) {
      cat("\nWDSM in CorCor:\n")
      if (abs(corcor_wdsm$relative_bias) < 1) {
        cat(sprintf("✅ Bias: %.2f%% (< 1%% achieved!)\n", corcor_wdsm$relative_bias))
      } else {
        cat(sprintf("⚠️ Bias: %.2f%% (target < 1%%)\n", corcor_wdsm$relative_bias))
      }
      
      if (corcor_wdsm$coverage >= 90 && corcor_wdsm$coverage <= 98) {
        cat(sprintf("✅ Coverage: %.1f%% (nominal range)\n", corcor_wdsm$coverage))
      } else {
        cat(sprintf("⚠️ Coverage: %.1f%% (outside nominal)\n", corcor_wdsm$coverage))
      }
    }
  }
  
  # Save combined results
  save(all_summaries, file = "allfixed_all_summaries.RData")
  cat("\n\nResults saved to allfixed_all_summaries.RData\n")
}
