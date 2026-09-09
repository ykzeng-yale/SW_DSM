# Minimal test for bootstrap method

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

# Draw one sample
set.seed(2025)
sample_data <- retrospective_sample(population, n_sample = 5000)

# Get point estimate
point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)

# Run bootstrap with a single iteration
cat("Testing single bootstrap iteration...\n")

n <- nrow(sample_data)
w <- sample_data$survey_weight
tau_hat <- point_results$tau

# Pre-compute reuse counts
K0_w <- calculate_weighted_reuse_counts(point_results$matches_0, w, sample_data$A)
K1_w <- calculate_weighted_reuse_counts(point_results$matches_1, w, sample_data$A)

# Single bootstrap iteration
xi_star <- rexp(n, rate = 1)
omega_star <- xi_star / mean(xi_star)
w_star <- omega_star * w

# Re-estimate scores
X <- model.matrix(~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 - 1, data = sample_data)
y <- sample_data$A

cv_ps_star <- cv.glmnet(X, y, family = "binomial", 
                       weights = w_star, 
                       alpha = 0,
                       nfolds = 10)
e_star <- predict(cv_ps_star, newx = X, s = "lambda.min", type = "response")[,1]

prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                 data = sample_data[sample_data$A == 0,],
                 weights = w_star[sample_data$A == 0])
psi0_star <- predict(prog0_star, newdata = sample_data)

prog1_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                 data = sample_data[sample_data$A == 1,],
                 weights = w_star[sample_data$A == 1])
psi1_star <- predict(prog1_star, newdata = sample_data)

# Linearization
psi_star <- numeric(n)
for (i in 1:n) {
  K_i_w <- ifelse(sample_data$A[i] == 0, K0_w[i], K1_w[i])
  psi_a_star <- ifelse(sample_data$A[i] == 0, psi0_star[i], psi1_star[i])
  
  psi_star[i] <- psi1_star[i] - psi0_star[i] + 
    (2*sample_data$A[i] - 1) * (1 + K_i_w) * (sample_data$Y[i] - psi_a_star)
}

tau_star_single <- sum(w_star * psi_star) / sum(w_star)
cat("Single bootstrap estimate:", tau_star_single, "\n")

# Now try the actual function with B=2
cat("\nTesting method1_bootstrap_ci with B=2...\n")
tryCatch({
  result <- method1_bootstrap_ci(sample_data, 
                                point_estimate = point_results,
                                M = 3, 
                                B = 2,
                                alpha = 0.05,
                                use_bias_correction = FALSE)
  cat("Success! CI:", result$ci_lower, "-", result$ci_upper, "\n")
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  print(e)
}) 