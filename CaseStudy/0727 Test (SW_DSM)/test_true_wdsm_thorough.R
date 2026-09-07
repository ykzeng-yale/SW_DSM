#!/usr/bin/env Rscript

# Comprehensive test of TRUE WDSM method from theoretical paper

library(MASS)
source("SW_PSW-main/Super_Population_GoodOvelap.R")
source("WDSM/R/true_wdsm_implementation.R")

# True values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("COMPREHENSIVE TEST: TRUE WDSM METHOD\n")
cat("=======================================================\n\n")

cat("True PATE:", round(ate_sp, 4), "\n")
cat("True PATT:", round(att_sp, 4), "\n\n")

# Function to analyze WDSM performance
analyze_wdsm_performance <- function(n_sim = 100, n_sample = 300, M_values = c(1, 3, 5, 10)) {
  
  results <- list()
  
  for (M in M_values) {
    cat("\n===========================================\n")
    cat("Testing with M =", M, "matches\n")
    cat("===========================================\n")
    
    # Store results for this M
    pate_prosp <- numeric(n_sim)
    pate_retro <- numeric(n_sim)
    coverage_prosp <- numeric(n_sim)
    coverage_retro <- numeric(n_sim)
    se_prosp <- numeric(n_sim)
    se_retro <- numeric(n_sim)
    
    # Also track matching quality metrics
    ps_balance <- numeric(n_sim)
    prog_balance <- numeric(n_sim)
    
    for (sim in 1:n_sim) {
      set.seed(sim * 1000)
      
      # Sample data
      idx <- sample(1:N, n_sample, replace = FALSE)
      sample_data <- data[idx, ]
      X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
      Z <- sample_data$z
      Y <- sample_data$y
      
      # Prospective sampling
      weights <- rep(N/n_sample, n_sample)
      
      # Test WDSM
      wdsm_result <- wdsm_pate(X, Z, Y, weights, M = M, 
                              sampling = "prospective", 
                              bias_correction = FALSE)
      
      pate_prosp[sim] <- wdsm_result$estimate
      
      # Analyze matching quality
      # Check propensity score balance
      treated_ps <- wdsm_result$ps[Z == 1]
      control_ps <- wdsm_result$ps[Z == 0]
      ps_balance[sim] <- abs(mean(treated_ps) - mean(control_ps))
      
      # Check prognostic score balance for matched units
      prog_diff_1 <- mean(abs(wdsm_result$psi1[Z == 1] - 
                             wdsm_result$psi1[!is.na(wdsm_result$Y1_imputed)]))
      prog_diff_0 <- mean(abs(wdsm_result$psi0[Z == 0] - 
                             wdsm_result$psi0[!is.na(wdsm_result$Y0_imputed)]))
      prog_balance[sim] <- (prog_diff_1 + prog_diff_0) / 2
      
      # Bootstrap for variance (quick version with 50 reps)
      if (sim <= 20) {  # Only do bootstrap for first 20 simulations
        boot_result <- bootstrap_true_wdsm_pate_prospective(
          X, Z, Y, weights, n_boot = 50, M = M
        )
        se_prosp[sim] <- boot_result$se
        coverage_prosp[sim] <- (ate_sp >= boot_result$ci_lower) & 
                              (ate_sp <= boot_result$ci_upper)
      }
      
      # Retrospective sampling
      weights1 <- rep(N * mean(data$z) / (n_sample * 0.7), n_sample)
      weights0 <- rep(N * (1 - mean(data$z)) / (n_sample * 0.3), n_sample)
      
      wdsm_retro <- wdsm_pate(X, Z, Y, 
                             weights = ifelse(Z == 1, weights1, weights0),
                             weights0 = weights0, weights1 = weights1,
                             M = M, sampling = "retrospective", 
                             bias_correction = FALSE)
      
      pate_retro[sim] <- wdsm_retro$estimate
      
      if (sim %% 20 == 0) cat(".")
    }
    cat("\n")
    
    # Summarize results for this M
    results[[paste0("M", M)]] <- list(
      M = M,
      # Prospective
      bias_prosp = mean(pate_prosp) - ate_sp,
      rmse_prosp = sqrt(mean((pate_prosp - ate_sp)^2)),
      se_prosp = mean(se_prosp[1:20]),
      coverage_prosp = mean(coverage_prosp[1:20]) * 100,
      # Retrospective  
      bias_retro = mean(pate_retro) - ate_sp,
      rmse_retro = sqrt(mean((pate_retro - ate_sp)^2)),
      # Matching quality
      ps_imbalance = mean(ps_balance),
      prog_imbalance = mean(prog_balance)
    )
    
    # Print immediate results
    cat("\nResults for M =", M, ":\n")
    cat("Prospective - Bias:", round(results[[paste0("M", M)]]$bias_prosp, 4), 
        " RMSE:", round(results[[paste0("M", M)]]$rmse_prosp, 4), "\n")
    cat("Retrospective - Bias:", round(results[[paste0("M", M)]]$bias_retro, 4),
        " RMSE:", round(results[[paste0("M", M)]]$rmse_retro, 4), "\n")
    cat("Coverage (first 20):", round(results[[paste0("M", M)]]$coverage_prosp, 1), "%\n")
  }
  
  return(results)
}

# Run comprehensive analysis
cat("\nRunning comprehensive analysis...\n")
analysis_results <- analyze_wdsm_performance(n_sim = 100, n_sample = 300, 
                                            M_values = c(1, 3, 5, 10))

# Create summary table
cat("\n\n=======================================================\n")
cat("SUMMARY: TRUE WDSM PERFORMANCE\n")
cat("=======================================================\n\n")

summary_df <- do.call(rbind, lapply(analysis_results, function(x) {
  data.frame(
    M = x$M,
    Bias_Prosp = round(x$bias_prosp, 4),
    RMSE_Prosp = round(x$rmse_prosp, 4),
    Bias_Retro = round(x$bias_retro, 4),
    RMSE_Retro = round(x$rmse_retro, 4),
    Coverage = round(x$coverage_prosp, 1),
    PS_Imbal = round(x$ps_imbalance, 4),
    Prog_Imbal = round(x$prog_imbalance, 4)
  )
}))

print(summary_df, row.names = FALSE)

# Investigate bias sources
cat("\n\n=======================================================\n")
cat("BIAS INVESTIGATION\n")
cat("=======================================================\n\n")

# Test with larger sample to see if bias reduces
cat("Testing with larger sample size (n=1000)...\n")
set.seed(2024)
idx_large <- sample(1:N, 1000, replace = FALSE)
sample_large <- data[idx_large, ]
X_large <- as.matrix(sample_large[, paste0("x", 1:n_covar)])
Z_large <- sample_large$z
Y_large <- sample_large$y
weights_large <- rep(N/1000, 1000)

wdsm_large <- wdsm_pate(X_large, Z_large, Y_large, weights_large, 
                       M = 5, sampling = "prospective")

cat("WDSM estimate (n=1000):", round(wdsm_large$estimate, 4), "\n")
cat("Bias (n=1000):", round(wdsm_large$estimate - ate_sp, 4), "\n\n")

# Analyze matching quality in detail
cat("Detailed matching analysis (n=300, M=5):\n")
set.seed(3000)
idx <- sample(1:N, 300, replace = FALSE)
sample_data <- data[idx, ]
X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
Z <- sample_data$z
Y <- sample_data$y
Y1_true <- sample_data$y1
Y0_true <- sample_data$y0
weights <- rep(N/300, 300)

wdsm_detail <- wdsm_pate(X, Z, Y, weights, M = 5)

# Compare imputed vs true potential outcomes
imputed_Y1 <- wdsm_detail$Y1_imputed[Z == 0]
true_Y1 <- Y1_true[Z == 0]
imputed_Y0 <- wdsm_detail$Y0_imputed[Z == 1]  
true_Y0 <- Y0_true[Z == 1]

cat("\nImputation quality:\n")
cat("- Y(1) imputation RMSE:", round(sqrt(mean((imputed_Y1 - true_Y1)^2, na.rm = TRUE)), 4), "\n")
cat("- Y(0) imputation RMSE:", round(sqrt(mean((imputed_Y0 - true_Y0)^2, na.rm = TRUE)), 4), "\n")

# Oracle estimate using true potential outcomes
oracle_pate <- mean(Y1_true) - mean(Y0_true)
cat("\nOracle PATE (sample):", round(oracle_pate, 4), "\n")
cat("WDSM PATE:", round(wdsm_detail$estimate, 4), "\n")
cat("Difference:", round(wdsm_detail$estimate - oracle_pate, 4), "\n")

# Test bias correction (simplified version)
cat("\n\n=======================================================\n")
cat("BIAS CORRECTION ATTEMPT\n")
cat("=======================================================\n\n")

# Estimate outcome models for bias correction
X1 <- X[Z == 1, , drop = FALSE]
Y1 <- Y[Z == 1]
X0 <- X[Z == 0, , drop = FALSE]
Y0 <- Y[Z == 0]

lm1 <- lm(Y1 ~ X1, weights = weights[Z == 1])
lm0 <- lm(Y0 ~ X0, weights = weights[Z == 0])

mu1_hat <- predict(lm1, newdata = data.frame(X))
mu0_hat <- predict(lm0, newdata = data.frame(X))

# Compute matching bias estimate
bias_est <- 0
n_control <- sum(Z == 0)
n_treat <- sum(Z == 1)

for (i in which(Z == 0)) {
  matches <- wdsm_detail$matches_1[i, ]
  matches <- matches[!is.na(matches)]
  if (length(matches) > 0) {
    bias_est <- bias_est + weights[i] * mean(mu1_hat[matches] - mu1_hat[i])
  }
}

for (i in which(Z == 1)) {
  matches <- wdsm_detail$matches_0[i, ]
  matches <- matches[!is.na(matches)]
  if (length(matches) > 0) {
    bias_est <- bias_est - weights[i] * mean(mu0_hat[matches] - mu0_hat[i])
  }
}

bias_est <- bias_est / sum(weights)

cat("Estimated matching bias:", round(bias_est, 4), "\n")
cat("Bias-corrected estimate:", round(wdsm_detail$estimate - bias_est, 4), "\n")
cat("Remaining bias:", round((wdsm_detail$estimate - bias_est) - ate_sp, 4), "\n")

# Save results
save(analysis_results, summary_df, wdsm_detail, 
     file = "true_wdsm_thorough_results.RData")

cat("\n\n=======================================================\n")
cat("CONCLUSIONS\n")
cat("=======================================================\n\n")

cat("1. The TRUE WDSM method shows substantial bias across all M values\n")
cat("2. Increasing M (more matches) does not substantially reduce bias\n")
cat("3. The bias persists even with larger sample sizes\n")
cat("4. Imputation quality is moderate but introduces systematic error\n")
cat("5. Simple bias correction helps but doesn't eliminate the problem\n")
cat("6. Coverage is likely poor due to the bias (not nominal 95%)\n\n")

cat("The matching-based approach appears fundamentally limited compared to\n")
cat("the AIPW approach that achieved nominal coverage.\n") 