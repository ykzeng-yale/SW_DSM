# Debug script for WDSM with glmnet

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

# Draw one sample
set.seed(2025)
sample_data <- retrospective_sample(population, n_sample = 5000)

cat("Testing WDSM with glmnet...\n")

# Test point estimation
tryCatch({
  point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
  cat("Point estimate successful:", point_results$tau, "\n")
  cat("  Propensity score range:", range(point_results$e_score), "\n")
  cat("  SD of propensity scores:", sd(point_results$e_score), "\n")
}, error = function(e) {
  cat("ERROR in point estimation:", e$message, "\n")
  print(traceback())
})

# Test Method 1 bootstrap with detailed debugging
cat("\nTesting Method 1 bootstrap with detailed debugging...\n")
point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)

# Manually run the first few steps of method1_bootstrap_ci
n <- nrow(sample_data)
w <- sample_data$survey_weight
tau_hat <- point_results$tau

cat("tau_hat:", tau_hat, "\n")
cat("n:", n, "\n")
cat("w length:", length(w), "\n")

# Pre-compute reuse counts
K0_w <- calculate_weighted_reuse_counts(point_results$matches_0, w, sample_data$A)
K1_w <- calculate_weighted_reuse_counts(point_results$matches_1, w, sample_data$A)
cat("K0_w length:", length(K0_w), "\n")
cat("K1_w length:", length(K1_w), "\n")

# Test one bootstrap iteration
set.seed(123)
xi_star <- rexp(n, rate = 1)
omega_star <- xi_star / mean(xi_star)
w_star <- omega_star * w

cat("\nBootstrap weights:\n")
cat("  xi_star length:", length(xi_star), "\n")
cat("  omega_star length:", length(omega_star), "\n")
cat("  w_star length:", length(w_star), "\n")
cat("  w_star range:", range(w_star), "\n")

# Try to re-estimate propensity score
cat("\nTrying glmnet...\n")
X <- model.matrix(~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 - 1, data = sample_data)
y <- sample_data$A

cat("X dimensions:", dim(X), "\n")
cat("y length:", length(y), "\n")

tryCatch({
  cv_ps_star <- cv.glmnet(X, y, family = "binomial", 
                         weights = w_star, 
                         alpha = 0,  # Ridge
                         nfolds = 10)
  e_star <- predict(cv_ps_star, newx = X, s = "lambda.min", type = "response")[,1]
  cat("glmnet successful, e_star length:", length(e_star), "\n")
  cat("e_star range:", range(e_star), "\n")
}, error = function(e) {
  cat("ERROR in glmnet:", e$message, "\n")
})

# Try prognostic score for controls
cat("\nTrying prognostic score for controls...\n")
control_idx <- which(sample_data$A == 0)
cat("Number of controls:", length(control_idx), "\n")

tryCatch({
  prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                   data = sample_data[sample_data$A == 0,],
                   weights = w_star[sample_data$A == 0])
  psi0_star <- predict(prog0_star, newdata = sample_data)
  cat("prog0 successful, psi0_star length:", length(psi0_star), "\n")
}, error = function(e) {
  cat("ERROR in prog0:", e$message, "\n")
}) 