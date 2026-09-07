##############################################################################
# Compare Two WDSM CI Methods for PATE under Retrospective Sampling
# With Bias Correction
##############################################################################

# Load required libraries and functions
library(glmnet)  # Add glmnet
library(parallel)  # Add parallel
library(doParallel)  # Add doParallel
source("wdsm_ci_functions.R")

# Set simulation parameters
n_sim <- 1000        # Number of simulations
n_sample <- 5000   # Sample size
B_boot <- 200      # Bootstrap iterations
M_neighbors <- 3   # Number of neighbors for matching

# Set seed for reproducibility
set.seed(2024)

# Load population data
cat("Loading population data...\n")
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
population <- data_sets[[1]]

# Rename columns to match our convention
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# True PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("True population PATE:", true_pate, "\n\n")

# Set up parallel computing
n_cores <- 5
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Export required functions and libraries to workers
clusterEvalQ(cl, {
  library(MASS)
  library(mvtnorm)
  library(nnet)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(matrixStats)
  library(survey)
  library(sampling)
  library(Hmisc)
  library(glmnet)  # Add glmnet
})

# Export functions and data to cluster
clusterExport(cl, c("expit", "show_progress", "retrospective_sample", 
                    "weighted_distance", "find_weighted_neighbors",
                    "calculate_weighted_reuse_counts", "wdsm_point_estimate",
                    "method1_bootstrap_ci", "method2_bootstrap_ci", "population"))

# Run simulation with parallel processing
cat("Starting simulation with", n_sim, "replications\n")
cat("Sample size:", n_sample, ", Bootstrap iterations:", B_boot, ", Neighbors:", M_neighbors, "\n")
cat("Using", n_cores, "cores for parallel processing\n")
cat("Bias correction: ENABLED\n\n")

# Run simulations in parallel
results <- foreach(sim = 1:n_sim, .combine = rbind,
                   .packages = c("MASS", "mvtnorm", "nnet", "dplyr", "tidyr", 
                                 "purrr", "matrixStats", "survey", "sampling", "Hmisc", "glmnet")) %dopar% {
                                   
                                   # Set seed for reproducibility
                                   set.seed(2024 + sim)
                                   
                                   # Sample from population
                                   sample_data <- retrospective_sample(population, n_sample = n_sample)
                                   
                                   # Point estimate with bias correction
                                   point_estimate <- wdsm_point_estimate(sample_data, M = M_neighbors, use_bias_correction = TRUE)
                                   
                                   # Method 1: Exponential Bootstrap
                                   ci_results1 <- method1_bootstrap_ci(sample_data, 
                                                                       point_estimate = point_estimate,
                                                                       M = M_neighbors, 
                                                                       B = B_boot, 
                                                                       alpha = 0.05,
                                                                       use_bias_correction = TRUE)
                                   
                                   # Method 2: Survey Bootstrap
                                   ci_results2 <- method2_bootstrap_ci(sample_data, 
                                                                       point_estimate = point_estimate,
                                                                       M = M_neighbors, 
                                                                       B = B_boot, 
                                                                       alpha = 0.05,
                                                                       use_bias_correction = TRUE)
                                   
                                   # Return results
                                   data.frame(
                                     sim = sim,
                                     method = c("Method 1: Exponential", "Method 2: Survey"),
                                     tau_hat = c(ci_results1$tau_hat, ci_results2$tau_hat),
                                     se = c(ci_results1$se, ci_results2$se),
                                     ci_lower = c(ci_results1$ci_lower, ci_results2$ci_lower),
                                     ci_upper = c(ci_results1$ci_upper, ci_results2$ci_upper),
                                     covers_truth = c(true_pate >= ci_results1$ci_lower & true_pate <= ci_results1$ci_upper,
                                                      true_pate >= ci_results2$ci_lower & true_pate <= ci_results2$ci_upper)
                                   )
                                 }

# Stop cluster
stopCluster(cl)

##############################################################################
# Summary Results
##############################################################################

cat("\n\n=== SUMMARY RESULTS ===\n")

# Add CI width to results
results$ci_width <- results$ci_upper - results$ci_lower

# By method summaries
summary_by_method <- results %>%
  group_by(method) %>%
  summarise(
    mean_tau_hat = mean(tau_hat),
    bias = mean(tau_hat - true_pate),
    sd_tau_hat = sd(tau_hat),
    mean_se = mean(se),
    coverage = mean(covers_truth),
    mean_ci_width = mean(ci_width),
    .groups = 'drop'
  )

print(summary_by_method)

# Detailed comparison
cat("\n=== Detailed Results by Simulation ===\n")
results_wide <- results %>%
  select(sim, method, tau_hat, ci_lower, ci_upper, covers_truth) %>%
  pivot_wider(names_from = method, 
              values_from = c(tau_hat, ci_lower, ci_upper, covers_truth))

print(results_wide)

# Save results
save(results, summary_by_method, true_pate, file = "wdsm_ci_methods_comparison_results.RData")

cat("\n=== Comparison Complete ===\n")
cat("Results saved to: wdsm_ci_methods_comparison_results.RData\n") 