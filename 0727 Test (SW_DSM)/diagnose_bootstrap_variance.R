# Diagnostic script to check bootstrap variance issue

# Load libraries and functions
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
set.seed(123)
sample_data <- retrospective_sample(population, n_sample = 5000)

# Get point estimate
cat("=== Point Estimate ===\n")
point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
cat("Point estimate:", point_results$tau, "\n")
cat("Effective sample size:", sum(sample_data$survey_weight)^2 / sum(sample_data$survey_weight^2), "\n\n")

# Run a small bootstrap to check variance
cat("=== Bootstrap Diagnostic (B=20) ===\n")
B_test <- 20
n <- nrow(sample_data)

# Pre-compute reuse counts
K0_w <- calculate_weighted_reuse_counts(point_results$matches_0, 
                                       sample_data$survey_weight, 
                                       sample_data$A)
K1_w <- calculate_weighted_reuse_counts(point_results$matches_1, 
                                       sample_data$survey_weight, 
                                       sample_data$A)

# Method 1: Exponential Bootstrap
tau_boot_exp <- numeric(B_test)
cat("\nMethod 1: Exponential Bootstrap\n")
for (b in 1:B_test) {
  # Generate bootstrap weights
  xi_star <- rexp(n, rate = 1)
  omega_star <- xi_star / mean(xi_star)
  w_boot <- omega_star * sample_data$survey_weight
  
  # Re-estimate scores
  ps_boot <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                 data = sample_data,
                 family = binomial,
                 weights = w_boot)
  e_star <- predict(ps_boot, type = "response")
  
  prog0_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                   data = sample_data[sample_data$A == 0,],
                   weights = w_boot[sample_data$A == 0])
  psi0_star <- predict(prog0_boot, newdata = sample_data)
  
  prog1_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                   data = sample_data[sample_data$A == 1,],
                   weights = w_boot[sample_data$A == 1])
  psi1_star <- predict(prog1_boot, newdata = sample_data)
  
  # Calculate bootstrap replicate
  psi_star <- numeric(n)
  for (i in 1:n) {
    K_i_w <- ifelse(sample_data$A[i] == 0, K0_w[i], K1_w[i])
    psi_a_star <- ifelse(sample_data$A[i] == 0, psi0_star[i], psi1_star[i])
    
    psi_star[i] <- psi1_star[i] - psi0_star[i] + 
      (2*sample_data$A[i] - 1) * (1 + K_i_w) * (sample_data$Y[i] - psi_a_star)
  }
  
  tau_boot_exp[b] <- sum(w_boot * psi_star) / sum(w_boot)
  cat("  Bootstrap", b, ": tau =", round(tau_boot_exp[b], 4), 
      ", mean(omega*)=", round(mean(omega_star), 4), 
      ", sd(omega*)=", round(sd(omega_star), 4), "\n")
}

cat("\nBootstrap statistics:\n")
cat("  Mean:", mean(tau_boot_exp), "\n")
cat("  SD:", sd(tau_boot_exp), "\n")
cat("  Range:", range(tau_boot_exp), "\n")

# Check individual components
cat("\n=== Component Analysis ===\n")
cat("Original weights:\n")
cat("  Mean:", mean(sample_data$survey_weight), "\n")
cat("  SD:", sd(sample_data$survey_weight), "\n")
cat("  Range:", range(sample_data$survey_weight), "\n")

cat("\nReuse counts (K_w):\n")
cat("  K0_w - Mean:", mean(K0_w), ", SD:", sd(K0_w), ", Range:", range(K0_w), "\n")
cat("  K1_w - Mean:", mean(K1_w), ", SD:", sd(K1_w), ", Range:", range(K1_w), "\n")

# Check psi_star values
cat("\nLinearization values (psi_star) from last bootstrap:\n")
cat("  Mean:", mean(psi_star), "\n")
cat("  SD:", sd(psi_star), "\n")
cat("  Range:", range(psi_star), "\n") 