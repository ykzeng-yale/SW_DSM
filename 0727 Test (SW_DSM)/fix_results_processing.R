#!/usr/bin/env Rscript

# Script to process the completed simulation results from the server
# Fixes the issue with sapply returning non-atomic values

library(dplyr)
library(tidyr)

# Configuration
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
M_values <- 5
true_pate <- 0.8664
alpha <- 0.05

# Function to safely extract numeric values
safe_extract <- function(results_list, field) {
  values <- unlist(lapply(results_list, function(x) {
    val <- x[[field]]
    if (is.null(val) || length(val) == 0) return(NA)
    if (is.list(val)) return(val[[1]])  # If it's a list, get first element
    return(val)
  }))
  return(as.numeric(values))
}

# Process each scenario
all_results_summary <- list()

for (scenario in scenarios) {
  scenario_lower <- tolower(scenario)
  base_dir <- sprintf("/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_%s_1000rep_final", scenario_lower)
  
  cat("\n============================================================\n")
  cat("Processing", scenario, "scenario\n")
  cat("============================================================\n")
  
  # Check if RData file exists in the directory
  rdata_files <- list.files(base_dir, pattern = ".*\\.RData$", full.names = TRUE)
  
  # Find the results file (excluding SuperPopGen file)
  results_file <- rdata_files[!grepl("SuperPopGen", rdata_files)]
  
  if (length(results_file) == 0) {
    # Try to load from workspace if saved there
    workspace_file <- file.path(base_dir, ".RData")
    if (file.exists(workspace_file)) {
      cat("Loading workspace from:", workspace_file, "\n")
      
      # Load into a new environment to avoid conflicts
      env <- new.env()
      load(workspace_file, envir = env)
      
      # Find the results object
      if (exists("all_results", envir = env)) {
        all_results <- env$all_results
      } else if (exists("valid_results", envir = env)) {
        all_results <- env$valid_results
      } else {
        cat("Warning: No results object found for", scenario, "\n")
        next
      }
    } else {
      cat("Warning: No results file found for", scenario, "\n")
      next
    }
  } else {
    cat("Loading results from:", results_file[1], "\n")
    load(results_file[1])
  }
  
  # Process results
  if (exists("all_results")) {
    # Filter valid results
    valid_results <- all_results[sapply(all_results, function(x) !is.null(x) && !inherits(x, "error") && !"error" %in% names(x))]
    
    cat("Valid results:", length(valid_results), "\n")
    
    # Extract results for this scenario and M=5
    key <- paste0(scenario, "_M", M_values)
    scenario_m_results <- lapply(valid_results, function(x) x[[key]])
    scenario_m_results <- scenario_m_results[!sapply(scenario_m_results, is.null)]
    
    cat("Results for M=5:", length(scenario_m_results), "\n")
    
    # Calculate metrics for each method
    methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial")
    
    method_stats <- list()
    for (method in methods) {
      cat("\nProcessing", method, "...\n")
      
      # Safely extract values
      estimates <- safe_extract(lapply(scenario_m_results, function(x) x[[method]]), "estimate")
      ses <- safe_extract(lapply(scenario_m_results, function(x) x[[method]]), "se")
      ci_lowers <- safe_extract(lapply(scenario_m_results, function(x) x[[method]]), "ci_lower")
      ci_uppers <- safe_extract(lapply(scenario_m_results, function(x) x[[method]]), "ci_upper")
      
      # Remove NAs
      valid_idx <- !is.na(estimates)
      estimates <- estimates[valid_idx]
      ses <- ses[valid_idx]
      ci_lowers <- ci_lowers[valid_idx]
      ci_uppers <- ci_uppers[valid_idx]
      
      cat("Valid estimates:", length(estimates), "\n")
      
      if (length(estimates) > 0) {
        method_stats[[method]] <- data.frame(
          Scenario = scenario,
          Method = method,
          M = M_values,
          N_Valid = length(estimates),
          Mean_Estimate = mean(estimates),
          Bias = mean(estimates) - true_pate,
          Rel_Bias = (mean(estimates) - true_pate) / abs(true_pate),
          Empirical_SE = sd(estimates),
          Mean_SE = mean(ses),
          SE_Ratio = mean(ses) / sd(estimates),
          Coverage = mean(ci_lowers <= true_pate & ci_uppers >= true_pate),
          RMSE = sqrt(mean((estimates - true_pate)^2))
        )
      }
    }
    
    # Combine results
    scenario_df <- do.call(rbind, method_stats)
    all_results_summary[[scenario]] <- scenario_df
  }
}

# Combine all scenarios
final_results <- do.call(rbind, all_results_summary)

# Format output
cat("\n============================================================\n")
cat("FINAL RESULTS SUMMARY\n")
cat("============================================================\n")

# Create nice display table
display_results <- final_results %>%
  mutate(
    Method = case_when(
      Method == "dsm_unweighted" ~ "DSM Unweighted",
      Method == "pg_unweighted" ~ "PG Unweighted",
      Method == "ps_unweighted" ~ "PS Unweighted",
      Method == "ps_weighted" ~ "PS Full (MatchIt)",
      Method == "wdsm_multinomial" ~ "WDSM Multinomial",
      TRUE ~ Method
    ),
    Rel_Bias = round(Rel_Bias * 100, 3),
    SE_Ratio = round(SE_Ratio, 3),
    Coverage = round(Coverage * 100, 1)
  ) %>%
  select(Scenario, Method, N_Valid, Rel_Bias, SE_Ratio, Coverage)

print(display_results, row.names = FALSE)

# Save results
output_file <- "combined_results_M5_1000rep_final.RData"
save(final_results, display_results, file = output_file)
cat("\nResults saved to:", output_file, "\n")


