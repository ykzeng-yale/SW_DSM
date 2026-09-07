# Test script for Yang & Zhang transformations

source("wdsm_ci_functions.R")

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
population <- data_sets[[1]]

# Rename columns
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# True PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("True PATE:", true_pate, "\n\n")

# Test on one of the problematic seeds
cat("Testing on previously problematic seed (2027):\n")
set.seed(2027)
sample_data <- retrospective_sample(population, n_sample = 5000)

# Get point estimate with Yang & Zhang transformations
cat("\nRunning WDSM with Yang & Zhang transformations...\n")
tryCatch({
  point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
  
  cat("Point estimate:", point_results$tau, "\n")
  cat("Error from truth:", point_results$tau - true_pate, "\n")
  
  # Check the propensity scores
  cat("\nPropensity score summary:\n")
  cat("  Mean:", mean(point_results$e_score), "\n")
  cat("  SD:", sd(point_results$e_score), "\n")
  cat("  Range:", range(point_results$e_score), "\n")
  
  # Check matching counts
  n_matched_0 <- sum(!sapply(point_results$matches_0, is.null))
  n_matched_1 <- sum(!sapply(point_results$matches_1, is.null))
  cat("\nMatching summary:\n")
  cat("  Treated units with matches to controls:", n_matched_0, "\n")
  cat("  Control units with matches to treated:", n_matched_1, "\n")
  
}, error = function(e) {
  cat("\nERROR:", e$message, "\n")
})

# Test on a normal seed for comparison
cat("\n\nTesting on previously normal seed (2025):\n")
set.seed(2025)
sample_data <- retrospective_sample(population, n_sample = 5000)

tryCatch({
  point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
  
  cat("Point estimate:", point_results$tau, "\n")
  cat("Error from truth:", point_results$tau - true_pate, "\n")
  
  # Check the propensity scores
  cat("\nPropensity score summary:\n")
  cat("  Mean:", mean(point_results$e_score), "\n")
  cat("  SD:", sd(point_results$e_score), "\n")
  cat("  Range:", range(point_results$e_score), "\n")
  
}, error = function(e) {
  cat("\nERROR:", e$message, "\n")
})

# Run a small simulation to check stability
cat("\n\nRunning small simulation (n=10) to check stability:\n")
results <- numeric(10)
ps_failures <- 0

for (i in 1:10) {
  set.seed(2024 + i)
  sample_data <- retrospective_sample(population, n_sample = 5000)
  
  tryCatch({
    point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
    results[i] <- point_results$tau
    
    # Check for PS failure
    if (sd(point_results$e_score) < 1e-10) {
      ps_failures <- ps_failures + 1
    }
  }, error = function(e) {
    results[i] <- NA
    ps_failures <- ps_failures + 1
  })
}

cat("\nSimulation results:\n")
cat("  Successful estimates:", sum(!is.na(results)), "/10\n")
cat("  PS failures:", ps_failures, "/10\n")
cat("  Mean estimate:", mean(results, na.rm = TRUE), "\n")
cat("  SD of estimates:", sd(results, na.rm = TRUE), "\n")
cat("  Range:", range(results, na.rm = TRUE), "\n") 