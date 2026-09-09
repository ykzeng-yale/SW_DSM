#!/usr/bin/env Rscript

# Load the results
load("temp_check_results.RData")

cat("===============================================\n")
cat("Checking CorCor FULLY FIXED Results\n")
cat("===============================================\n\n")

# Check the structure
cat("Number of results:", length(all_results), "\n")
cat("Type of all_results:", class(all_results), "\n\n")

# Check first few results
for (i in 1:min(3, length(all_results))) {
  cat("Result", i, ":\n")
  
  if (is.null(all_results[[i]])) {
    cat("  NULL result\n")
  } else if (inherits(all_results[[i]], "error")) {
    cat("  ERROR:", all_results[[i]]$message, "\n")
  } else if ("error" %in% names(all_results[[i]])) {
    cat("  ERROR:", all_results[[i]]$error, "\n")
  } else {
    cat("  Keys:", names(all_results[[i]]), "\n")
    
    # Check if there's a CorCor_M5 result
    if ("CorCor_M5" %in% names(all_results[[i]])) {
      scenario_result <- all_results[[i]][["CorCor_M5"]]
      cat("  Methods in CorCor_M5:", names(scenario_result), "\n")
      
      # Check each method
      for (method in names(scenario_result)) {
        method_result <- scenario_result[[method]]
        if (!is.null(method_result$estimate)) {
          cat("    ", method, ": estimate =", method_result$estimate, "\n")
        } else {
          cat("    ", method, ": estimate is NULL or NA\n")
        }
      }
    }
  }
  cat("\n")
}

# Count successful vs failed runs
successful <- 0
failed <- 0
errors <- character()

for (i in 1:length(all_results)) {
  if (is.null(all_results[[i]]) || 
      inherits(all_results[[i]], "error") || 
      "error" %in% names(all_results[[i]])) {
    failed <- failed + 1
    if (!is.null(all_results[[i]])) {
      if (inherits(all_results[[i]], "error")) {
        errors <- c(errors, all_results[[i]]$message)
      } else if ("error" %in% names(all_results[[i]])) {
        errors <- c(errors, all_results[[i]]$error)
      }
    }
  } else {
    successful <- successful + 1
  }
}

cat("===============================================\n")
cat("Summary:\n")
cat("  Successful runs:", successful, "\n")
cat("  Failed runs:", failed, "\n")

if (length(unique(errors)) > 0) {
  cat("\nUnique errors:\n")
  for (err in unique(errors)) {
    cat("  -", substr(err, 1, 100), "\n")
  }
}

cat("===============================================\n")
