##############################################################################
# Compare WDSM Bootstrap Methods: Exponential vs Multinomial
# For PATE under Retrospective Sampling
##############################################################################

# Load required libraries
library(glmnet)
library(MASS)
library(mvtnorm)
library(dplyr)

# Set seed for reproducibility
set.seed(2024)

# Load required functions
source("wdsm_ci_functions.R")  # For retrospective_sample and wdsm_point_estimate
source("wdsm_method1_exponential_bootstrap.R")  # Exponential bootstrap
source("wdsm_method2_multinomial_bootstrap.R")  # Multinomial bootstrap

# Simulation parameters
n_reps <- 10      # Number of simulation replicates
n_sample <- 5000  # Sample size for retrospective sampling
M <- 5            # Number of matches per unit
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level

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

# Initialize results storage
results <- list()

# Main simulation loop
cat("============================================================\n")
cat("Comparing WDSM Bootstrap Methods\n")
cat("============================================================\n")
cat("Replicates:", n_reps, "\n")
cat("Sample size:", n_sample, "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Number of neighbors:", M, "\n")
cat("No parallel processing (single core)\n\n")

# Progress tracking
start_time <- Sys.time()

for (i.rep in 1:n_reps) {
  cat("Running replicate", i.rep, "of", n_reps, "...\n")
  
  # Set seed for reproducibility
  set.seed(2024 + i.rep)
  
  # Draw retrospective sample
  sample <- retrospective_sample(population, n = n_sample)
  
  # Compute point estimate (shared by both methods)
  point_est <- wdsm_point_estimate(sample, M = M)
  
  # Extract variables for bootstrap functions
  Y <- sample$Y
  X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
  A <- sample$A
  w <- sample$survey_weight
  
  # Method 1: Exponential Bootstrap
  cat("  Running exponential bootstrap...")
  time1 <- system.time({
    exp_result <- method1_exponential_bootstrap_ci(
      data = sample,
      point_estimate = point_est,
      M = M,
      B = B, 
      alpha = alpha,
      use_bias_correction = TRUE,
      show_progress_bar = FALSE
    )
  })
  cat(" Done (", round(time1[3], 2), "seconds)\n")
  
  # Method 2: Multinomial Bootstrap
  cat("  Running multinomial bootstrap...")
  time2 <- system.time({
    mult_result <- method2_multinomial_bootstrap_ci(
      Y = Y, X = X, A = A, weights = w,
      point_estimate = point_est,
      B = B, alpha = alpha,
      use_bias_correction = TRUE,
      show_progress = FALSE
    )
  })
  cat(" Done (", round(time2[3], 2), "seconds)\n")
  
  # Store results
  results[[i.rep]] <- list(
    point_estimate = point_est$tau,
    exponential = list(
      ci_lower = exp_result$ci_lower,
      ci_upper = exp_result$ci_upper,
      se = sd(exp_result$bootstrap_estimates),
      time = time1[3]
    ),
    multinomial = list(
      ci_lower = mult_result$ci_lower,
      ci_upper = mult_result$ci_upper,
      se = sd(mult_result$bootstrap_estimates),
      time = time2[3]
    )
  )
  
  # Check coverage
  exp_covers <- (true_pate >= exp_result$ci_lower) & (true_pate <= exp_result$ci_upper)
  mult_covers <- (true_pate >= mult_result$ci_lower) & (true_pate <= mult_result$ci_upper)
  
  cat("  Point estimate:", round(point_est$tau, 4), "\n")
  cat("  Exponential CI: [", round(exp_result$ci_lower, 4), ",", 
      round(exp_result$ci_upper, 4), "] - Covers:", exp_covers, "\n")
  cat("  Multinomial CI: [", round(mult_result$ci_lower, 4), ",", 
      round(mult_result$ci_upper, 4), "] - Covers:", mult_covers, "\n\n")
}

# Calculate summary statistics
cat("============================================================\n")
cat("Summary Results\n")
cat("============================================================\n")

# Extract results for each method
point_estimates <- sapply(results, function(x) x$point_estimate)
exp_lower <- sapply(results, function(x) x$exponential$ci_lower)
exp_upper <- sapply(results, function(x) x$exponential$ci_upper)
exp_se <- sapply(results, function(x) x$exponential$se)
exp_time <- sapply(results, function(x) x$exponential$time)

mult_lower <- sapply(results, function(x) x$multinomial$ci_lower)
mult_upper <- sapply(results, function(x) x$multinomial$ci_upper)
mult_se <- sapply(results, function(x) x$multinomial$se)
mult_time <- sapply(results, function(x) x$multinomial$time)

# Calculate performance metrics
exp_coverage <- mean((true_pate >= exp_lower) & (true_pate <= exp_upper))
mult_coverage <- mean((true_pate >= mult_lower) & (true_pate <= mult_upper))

exp_ci_width <- mean(exp_upper - exp_lower)
mult_ci_width <- mean(mult_upper - mult_lower)

mean_estimate <- mean(point_estimates)
bias <- mean_estimate - true_pate
relative_bias <- bias / true_pate

# Print results
cat("\nTrue PATE:", round(true_pate, 4), "\n")
cat("Mean point estimate:", round(mean_estimate, 4), "\n")
cat("Bias:", round(bias, 4), "(", round(relative_bias * 100, 2), "%)\n\n")

cat("Exponential Bootstrap:\n")
cat("  Coverage:", round(exp_coverage * 100, 1), "%\n")
cat("  Mean CI width:", round(exp_ci_width, 4), "\n")
cat("  Mean SE:", round(mean(exp_se), 4), "\n")
cat("  Mean time per replicate:", round(mean(exp_time), 2), "seconds\n\n")

cat("Multinomial Bootstrap:\n")
cat("  Coverage:", round(mult_coverage * 100, 1), "%\n")
cat("  Mean CI width:", round(mult_ci_width, 4), "\n")
cat("  Mean SE:", round(mean(mult_se), 4), "\n")
cat("  Mean time per replicate:", round(mean(mult_time), 2), "seconds\n\n")

# Create comparison data frame
comparison_df <- data.frame(
  Method = c("Exponential", "Multinomial"),
  Coverage = c(exp_coverage, mult_coverage),
  Mean_CI_Width = c(exp_ci_width, mult_ci_width),
  Mean_SE = c(mean(exp_se), mean(mult_se)),
  Mean_Time_Seconds = c(mean(exp_time), mean(mult_time))
)

print(comparison_df)

# Save results
save(results, comparison_df, file = "wdsm_bootstrap_comparison_results.RData")
write.csv(comparison_df, "wdsm_bootstrap_comparison_table.csv", row.names = FALSE)

# Total time
total_time <- difftime(Sys.time(), start_time, units = "mins")
cat("\nTotal computation time:", round(total_time, 2), "minutes\n")

cat("\n============================================================\n")
cat("Comparison Complete!\n")
cat("============================================================\n")