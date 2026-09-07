# Check Poor Overlap Results
cat("============================================================\n")
cat("Checking PATE Retrospective Poor Overlap Results\n")
cat("============================================================\n\n")

# Load the results
load("pate_retrospective_pooroverlap_comparison_results_mccleary_M135_rawWDSM.RData")

# Check what objects were loaded
cat("Objects loaded:\n")
print(ls())
cat("\n")

# Print basic info
cat("True PATE:", round(true_pate, 4), "\n")
cat("Sample size:", n_sample, "\n")
cat("Number of replicates:", n_reps, "\n")
cat("M values:", M_values, "\n")
cat("Bootstrap iterations:", B, "\n\n")

# Check the structure of all_results
cat("Checking all_results structure:\n")
cat("Length of all_results:", length(all_results), "\n")

# Count successful runs
successful_reps <- 0
failed_reps <- 0
error_msgs <- list()

for (i in 1:length(all_results)) {
  if (!is.null(all_results[[i]]$error)) {
    failed_reps <- failed_reps + 1
    error_msgs[[length(error_msgs) + 1]] <- all_results[[i]]$error
  } else if (!is.null(all_results[[i]]$M1)) {
    successful_reps <- successful_reps + 1
  }
}

cat("\nSuccessful replicates:", successful_reps, "\n")
cat("Failed replicates:", failed_reps, "\n")

# Check a sample replicate
if (successful_reps > 0) {
  # Find first successful replicate
  for (i in 1:length(all_results)) {
    if (!is.null(all_results[[i]]$M1) && !is.null(all_results[[i]]$M1$dsm_unweighted)) {
      cat("\nSample results from replicate", i, ":\n")
      cat("M=1 results:\n")
      for (method in names(all_results[[i]]$M1)) {
        if (!is.null(all_results[[i]]$M1[[method]]$estimate)) {
          cat("  ", method, ": estimate =", round(all_results[[i]]$M1[[method]]$estimate, 4), "\n")
        }
      }
      break
    }
  }
}

# Display summary statistics
cat("\n============================================================\n")
cat("Summary Statistics from all_summary_stats:\n")
cat("============================================================\n\n")

if (exists("all_summary_stats")) {
  for (M in M_values) {
    M_label <- paste0("M", M)
    if (!is.null(all_summary_stats[[M_label]])) {
      cat("\nResults for M =", M, ":\n")
      print(all_summary_stats[[M_label]][, c("Method", "Mean_Estimate", "Relative_Bias", 
                                             "Relative_Efficiency", "Coverage")])
    }
  }
}

cat("\n============================================================\n")
cat("Analysis Complete\n")
cat("============================================================\n")
