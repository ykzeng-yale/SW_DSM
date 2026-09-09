##############################################################################
# Example: Using WDSM Method 1 Exponential Bootstrap in Simulations
##############################################################################

# Clear workspace
rm(list = ls())

# Source the Method 1 module
source("wdsm_method1_exponential_bootstrap.R")

# Source the WDSM point estimate function (assuming it's in wdsm_ci_functions.R)
# We need the wdsm_point_estimate and retrospective_sample functions
source("wdsm_ci_functions.R")

# Set simulation parameters
n_sim <- 100         # Number of simulations (reduced for example)
n_sample <- 1000     # Sample size (reduced for example)
B_boot <- 100        # Bootstrap iterations (reduced for example)
M_neighbors <- 3     # Number of neighbors for matching
use_bias_correction <- TRUE  # Whether to use bias correction

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

##############################################################################
# Example 1: Single CI calculation
##############################################################################

cat("=== Example 1: Single CI Calculation ===\n")

# Sample from population
sample_data <- retrospective_sample(population, n_sample = n_sample)

# Compute point estimate
point_estimate <- wdsm_point_estimate(sample_data, 
                                     M = M_neighbors, 
                                     use_bias_correction = use_bias_correction)
cat("Point estimate:", point_estimate$tau, "\n")

# Compute Method 1 CI
ci_results <- method1_exponential_bootstrap_ci(
  data = sample_data,
  point_estimate = point_estimate,
  M = M_neighbors,
  B = B_boot,
  alpha = 0.05,
  use_bias_correction = use_bias_correction,
  show_progress_bar = TRUE
)

cat("\nResults:\n")
cat("  Estimate:", ci_results$tau_hat, "\n")
cat("  Standard Error:", ci_results$se, "\n")
cat("  95% CI: [", ci_results$ci_lower, ",", ci_results$ci_upper, "]\n")
cat("  CI Width:", ci_results$ci_upper - ci_results$ci_lower, "\n")
cat("  Covers truth:", true_pate >= ci_results$ci_lower & true_pate <= ci_results$ci_upper, "\n\n")

##############################################################################
# Example 2: Using the wrapper function
##############################################################################

cat("=== Example 2: Using Wrapper Function ===\n")

# The wrapper handles both point estimation and CI calculation
results <- compute_wdsm_method1_ci(
  data = sample_data,
  wdsm_point_estimate_func = wdsm_point_estimate,
  M = M_neighbors,
  B = B_boot,
  alpha = 0.05,
  use_bias_correction = use_bias_correction
)

cat("\nCombined Results:\n")
cat("  Estimate:", results$combined$tau_hat, "\n")
cat("  Standard Error:", results$combined$se, "\n")
cat("  95% CI: [", results$combined$ci_lower, ",", results$combined$ci_upper, "]\n")
cat("  CI Width:", results$combined$ci_width, "\n\n")

##############################################################################
# Example 3: Small simulation study
##############################################################################

cat("=== Example 3: Small Simulation Study ===\n")
cat("Running", n_sim, "simulations...\n\n")

# Storage for results
sim_results <- data.frame(
  sim = integer(),
  tau_hat = numeric(),
  se = numeric(),
  ci_lower = numeric(),
  ci_upper = numeric(),
  covers_truth = logical()
)

# Run simulations
for (sim in 1:n_sim) {
  set.seed(2024 + sim)
  
  # Sample from population
  sample_data <- retrospective_sample(population, n_sample = n_sample)
  
  # Point estimate
  point_est <- wdsm_point_estimate(sample_data, 
                                  M = M_neighbors, 
                                  use_bias_correction = use_bias_correction)
  
  # Method 1 CI
  ci_results <- method1_exponential_bootstrap_ci(
    data = sample_data,
    point_estimate = point_est,
    M = M_neighbors,
    B = B_boot,
    alpha = 0.05,
    use_bias_correction = use_bias_correction,
    show_progress_bar = FALSE  # Turn off for simulation
  )
  
  # Store results
  sim_results <- rbind(sim_results, data.frame(
    sim = sim,
    tau_hat = ci_results$tau_hat,
    se = ci_results$se,
    ci_lower = ci_results$ci_lower,
    ci_upper = ci_results$ci_upper,
    covers_truth = true_pate >= ci_results$ci_lower & true_pate <= ci_results$ci_upper
  ))
  
  # Progress
  if (sim %% 10 == 0) {
    cat("Completed", sim, "of", n_sim, "simulations\n")
  }
}

# Summary statistics
cat("\n=== Simulation Summary ===\n")
cat("True PATE:", true_pate, "\n")
cat("Mean estimate:", mean(sim_results$tau_hat), "\n")
cat("Bias:", mean(sim_results$tau_hat - true_pate), "\n")
cat("SD of estimates:", sd(sim_results$tau_hat), "\n")
cat("Mean SE:", mean(sim_results$se), "\n")
cat("Coverage rate:", mean(sim_results$covers_truth), "\n")
cat("Mean CI width:", mean(sim_results$ci_upper - sim_results$ci_lower), "\n")

##############################################################################
# Example 4: Parallel processing (if needed for larger simulations)
##############################################################################

cat("\n=== Example 4: Parallel Processing Setup ===\n")
cat("For larger simulations, you can use parallel processing:\n\n")

cat("library(parallel)\n")
cat("library(doParallel)\n")
cat("\n")
cat("# Set up cluster\n")
cat("n_cores <- detectCores() - 1\n")
cat("cl <- makeCluster(n_cores)\n")
cat("registerDoParallel(cl)\n")
cat("\n")
cat("# Export functions and data\n")
cat("clusterExport(cl, c('method1_exponential_bootstrap_ci', 'wdsm_point_estimate', ...)\n")
cat("\n")
cat("# Run parallel simulations with foreach\n")
cat("results <- foreach(sim = 1:n_sim, .combine = rbind) %dopar% { ... }\n")
cat("\n")
cat("# Stop cluster\n")
cat("stopCluster(cl)\n")

cat("\n=== Example Complete ===\n")