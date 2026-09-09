# Analyze Tong Account M5 100-rep Results
# Load and present detailed results for all 4 scenarios

library(dplyr)
library(tidyr)

# Function to load and extract results
extract_results <- function(file_path, scenario_name) {
  # Load the RData file
  env <- new.env()
  load(file_path, envir = env)
  
  # Get the results object
  if ("all_results" %in% names(env)) {
    results <- env$all_results
  } else if ("results_list" %in% names(env)) {
    results <- env$results_list
  } else {
    # Try to find the results object
    obj_names <- ls(env)
    results_obj <- obj_names[grepl("result", obj_names, ignore.case = TRUE)][1]
    if (!is.na(results_obj)) {
      results <- get(results_obj, envir = env)
    } else {
      stop("Could not find results object in ", file_path)
    }
  }
  
  # Extract summary statistics if they exist
  if ("summary_stats" %in% names(results)) {
    return(list(scenario = scenario_name, summary = results$summary_stats))
  }
  
  # Otherwise compute summary statistics
  if ("results" %in% names(results)) {
    # Calculate metrics for each method
    method_results <- list()
    
    for (method_name in names(results$results)) {
      if (method_name == "Unweighted DSM") method_label <- "Method 1: Unweighted DSM"
      else if (method_name == "Unweighted PG") method_label <- "Method 2: Unweighted PG"
      else if (method_name == "Unweighted PS") method_label <- "Method 3: Unweighted PS"
      else if (method_name == "Survey-weighted PS") method_label <- "Method 4: SW PS"
      else if (method_name == "WDSM") method_label <- "Method 5: WDSM"
      else method_label <- method_name
      
      method_data <- results$results[[method_name]]
      
      # Extract estimates and CIs for M=5
      if ("M_5" %in% names(method_data)) {
        m5_data <- method_data$M_5
        
        # Get estimates
        estimates <- m5_data$estimates
        lower_ci <- m5_data$lower_ci
        upper_ci <- m5_data$upper_ci
        
        # Remove NAs
        valid_idx <- !is.na(estimates) & !is.na(lower_ci) & !is.na(upper_ci)
        estimates <- estimates[valid_idx]
        lower_ci <- lower_ci[valid_idx]
        upper_ci <- upper_ci[valid_idx]
        
        n_valid <- length(estimates)
        
        if (n_valid > 0) {
          # Calculate metrics
          true_pate <- results$true_pate
          
          # Relative bias
          bias <- mean(estimates) - true_pate
          relative_bias <- bias / true_pate
          
          # Relative efficiency (SE ratio)
          empirical_se <- sd(estimates)
          avg_se <- mean(upper_ci - lower_ci) / (2 * qnorm(0.975))
          se_ratio <- avg_se / empirical_se
          
          # Coverage
          coverage <- mean(lower_ci <= true_pate & upper_ci >= true_pate)
          
          method_results[[method_label]] <- data.frame(
            Scenario = scenario_name,
            Method = method_label,
            M = 5,
            N_Valid = n_valid,
            Relative_Bias = round(relative_bias, 3),
            SE_Ratio = round(se_ratio, 3),
            Coverage = round(coverage, 3)
          )
        }
      }
    }
    
    return(do.call(rbind, method_results))
  }
  
  return(NULL)
}

# Load results for all scenarios
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
all_results <- list()

cat("=============================================================\n")
cat("TONG ACCOUNT M5 100-REP RESULTS - DETAILED ANALYSIS\n")
cat("=============================================================\n\n")

for (scenario in scenarios) {
  file_name <- tolower(scenario)
  file_path <- paste0("Tong_M5_100rep_Results/", file_name, "_results.RData")
  
  if (file.exists(file_path)) {
    cat("Loading", scenario, "results from:", file_path, "\n")
    tryCatch({
      result <- extract_results(file_path, scenario)
      if (!is.null(result)) {
        all_results[[scenario]] <- result
      }
    }, error = function(e) {
      cat("Error loading", scenario, ":", e$message, "\n")
      # Try alternate extraction method
      env <- new.env()
      load(file_path, envir = env)
      cat("Objects in file:", paste(ls(env), collapse = ", "), "\n")
    })
  } else {
    cat("File not found:", file_path, "\n")
  }
}

# Combine all results
if (length(all_results) > 0) {
  combined_results <- do.call(rbind, all_results)
  rownames(combined_results) <- NULL
  
  cat("\n=============================================================\n")
  cat("COMBINED RESULTS TABLE\n")
  cat("=============================================================\n\n")
  
  # Sort by Scenario and Method
  combined_results <- combined_results %>%
    arrange(Scenario, Method)
  
  print(combined_results, row.names = FALSE)
  
  # Create formatted tables for each metric
  cat("\n=============================================================\n")
  cat("RELATIVE BIAS (Target: Close to 0)\n")
  cat("=============================================================\n\n")
  
  bias_table <- combined_results %>%
    select(Scenario, Method, Relative_Bias) %>%
    pivot_wider(names_from = Scenario, values_from = Relative_Bias)
  
  print(as.data.frame(bias_table), row.names = FALSE)
  
  cat("\n=============================================================\n")
  cat("RELATIVE EFFICIENCY / SE RATIO (Target: Close to 1)\n")
  cat("=============================================================\n\n")
  
  se_table <- combined_results %>%
    select(Scenario, Method, SE_Ratio) %>%
    pivot_wider(names_from = Scenario, values_from = SE_Ratio)
  
  print(as.data.frame(se_table), row.names = FALSE)
  
  cat("\n=============================================================\n")
  cat("COVERAGE (Target: 0.95)\n") 
  cat("=============================================================\n\n")
  
  coverage_table <- combined_results %>%
    select(Scenario, Method, Coverage) %>%
    pivot_wider(names_from = Scenario, values_from = Coverage)
  
  print(as.data.frame(coverage_table), row.names = FALSE)
  
  # Save combined results
  write.csv(combined_results, "Tong_M5_100rep_Results/combined_results.csv", row.names = FALSE)
  cat("\n\nResults saved to: Tong_M5_100rep_Results/combined_results.csv\n")
  
} else {
  cat("\nNo results could be extracted. Checking file structure...\n\n")
  
  # Check what's in each file
  for (scenario in scenarios) {
    file_name <- tolower(scenario)
    file_path <- paste0("Tong_M5_100rep_Results/", file_name, "_results.RData")
    
    if (file.exists(file_path)) {
      env <- new.env()
      load(file_path, envir = env)
      cat("\n", scenario, "file contains:\n")
      for (obj in ls(env)) {
        obj_val <- get(obj, envir = env)
        cat("  -", obj, ":", class(obj_val), "\n")
        if (is.list(obj_val)) {
          cat("    Names:", paste(names(obj_val), collapse = ", "), "\n")
        }
      }
    }
  }
}
