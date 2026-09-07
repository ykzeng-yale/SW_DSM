#!/usr/bin/env Rscript

# Inspect the detailed structure of results
scenario <- "CorCor"

cat("\n========================================\n")
cat(sprintf("Detailed inspection of %s scenario\n", scenario))
cat("========================================\n")

file_name <- sprintf("pooroverlap_%s_20rep_results.RData", scenario)
load(file_name)

cat(sprintf("all_results is a %s with length %d\n", class(all_results), length(all_results)))

# Check first replication
if (length(all_results) > 0) {
  cat("\n--- First replication ---\n")
  first_rep <- all_results[[1]]
  cat(sprintf("Class: %s\n", paste(class(first_rep), collapse=", ")))
  
  if (is.list(first_rep)) {
    cat(sprintf("Length: %d\n", length(first_rep)))
    cat("Names:", paste(names(first_rep), collapse=", "), "\n")
    
    # Check each element
    for (name in names(first_rep)) {
      elem <- first_rep[[name]]
      cat(sprintf("\n  %s:\n", name))
      cat(sprintf("    Class: %s\n", paste(class(elem), collapse=", ")))
      
      if (is.numeric(elem) || is.logical(elem)) {
        if (length(elem) == 1) {
          cat(sprintf("    Value: %s\n", elem))
        } else {
          cat(sprintf("    Length: %d, Values: %s\n", length(elem), 
                      paste(head(elem, 5), collapse=", ")))
        }
      } else if (is.data.frame(elem)) {
        cat(sprintf("    Dimensions: %d x %d\n", nrow(elem), ncol(elem)))
        cat(sprintf("    Columns: %s\n", paste(colnames(elem), collapse=", ")))
      }
    }
  } else if (is.data.frame(first_rep)) {
    cat(sprintf("Dimensions: %d x %d\n", nrow(first_rep), ncol(first_rep)))
    cat("Column names:", paste(colnames(first_rep), collapse=", "), "\n")
    cat("\nFirst few rows:\n")
    print(head(first_rep, 3))
  }
  
  # Check if all replications have same structure
  cat("\n--- Checking all replications ---\n")
  has_error <- sapply(all_results, function(x) !is.null(x$error))
  cat(sprintf("Replications with errors: %d out of %d\n", sum(has_error), length(all_results)))
  
  # Count successful results by method
  success_count <- list()
  for (i in 1:length(all_results)) {
    rep_data <- all_results[[i]]
    if (!is.null(rep_data$results)) {
      for (method in names(rep_data$results)) {
        if (is.null(success_count[[method]])) {
          success_count[[method]] <- 0
        }
        if (!is.null(rep_data$results[[method]]$estimate)) {
          success_count[[method]] <- success_count[[method]] + 1
        }
      }
    }
  }
  
  cat("\nSuccessful runs by method:\n")
  for (method in names(success_count)) {
    cat(sprintf("  %s: %d/%d\n", method, success_count[[method]], length(all_results)))
  }
}
