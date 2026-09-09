#!/usr/bin/env Rscript

# Automated debugging and theoretical development for WDSM
# Goal: Achieve nominal 95% coverage for all scenarios

library(MASS)
library(nloptr)

# Source functions
source("SW_PSW-main/Super_Population_GoodOvelap.R")
source("WDSM/R/bootstrap_wdsm_corrected.R")

# True values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("WDSM Theoretical Analysis and Debugging\n")
cat("=======================================================\n\n")

# Function to analyze bias sources
analyze_bias_sources <- function(n_sim = 50, n_sample = 300) {
  
  cat("1. ANALYZING BIAS SOURCES\n")
  cat("------------------------\n")
  
  results <- list()
  
  for (sim in 1:n_sim) {
    set.seed(sim * 1000)
    
    # Sample data
    idx <- sample(1:N, n_sample, replace = FALSE)
    sample_data <- data[idx, ]
    X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
    Z <- sample_data$z
    Y <- sample_data$y
    Y1_true <- sample_data$y1
    Y0_true <- sample_data$y0
    
    # Equal weights for simplicity
    weights <- rep(N/n_sample, n_sample)
    
    # True values in sample
    true_pate_sample <- mean(Y1_true) - mean(Y0_true)
    true_patt_sample <- mean(Y1_true[Z==1]) - mean(Y0_true[Z==1])
    
    # Estimate parameters
    theta <- estimate_double_score_params_stable(X, Z, Y, weights, "ps")
    scores <- compute_double_scores_corrected(X, Z, Y, theta)
    
    # Component analysis
    results[[sim]] <- list(
      # True values
      true_pate = true_pate_sample,
      true_patt = true_patt_sample,
      
      # Propensity score quality
      ps_mean = mean(scores$ps),
      ps_sd = sd(scores$ps),
      ps_min = min(scores$ps),
      ps_max = max(scores$ps),
      
      # Outcome model quality
      or1_mse = mean((scores$mu1[Z==1] - Y1_true[Z==1])^2),
      or0_mse = mean((scores$mu0[Z==0] - Y0_true[Z==0])^2),
      
      # Double score quality
      s1_bias = mean(scores$S1 - Y1_true),
      s0_bias = mean(scores$S0 - Y0_true),
      
      # Direct estimates
      ipw_pate = sum(weights * Z * Y / scores$ps) / sum(weights * Z / scores$ps) -
                 sum(weights * (1-Z) * Y / (1-scores$ps)) / sum(weights * (1-Z) / (1-scores$ps)),
      
      or_pate = sum(weights * scores$mu1) / sum(weights) - 
                sum(weights * scores$mu0) / sum(weights),
      
      # Doubly robust estimate
      dr_pate = sum(weights * (scores$mu1 + Z * (Y - scores$mu1) / scores$ps)) / sum(weights) -
                sum(weights * (scores$mu0 + (1-Z) * (Y - scores$mu0) / (1-scores$ps))) / sum(weights)
    )
  }
  
  # Summarize findings
  df <- do.call(rbind, lapply(results, as.data.frame))
  
  cat("\nPropensity Score Summary:\n")
  cat("- Mean PS:", round(mean(df$ps_mean), 3), "\n")
  cat("- PS Range: [", round(mean(df$ps_min), 3), ",", round(mean(df$ps_max), 3), "]\n")
  cat("- PS SD:", round(mean(df$ps_sd), 3), "\n")
  
  cat("\nOutcome Model Performance:\n")
  cat("- OR1 RMSE:", round(sqrt(mean(df$or1_mse)), 3), "\n")
  cat("- OR0 RMSE:", round(sqrt(mean(df$or0_mse)), 3), "\n")
  
  cat("\nDouble Score Bias:\n")
  cat("- S1 bias:", round(mean(df$s1_bias), 3), "\n")
  cat("- S0 bias:", round(mean(df$s0_bias), 3), "\n")
  
  cat("\nEstimator Comparison (PATE):\n")
  cat("- IPW bias:", round(mean(df$ipw_pate - df$true_pate), 3), "\n")
  cat("- OR bias:", round(mean(df$or_pate - df$true_pate), 3), "\n")
  cat("- DR bias:", round(mean(df$dr_pate - df$true_pate), 3), "\n")
  
  return(df)
}

# Function to test different theoretical approaches
test_theoretical_approaches <- function(n_sample = 300) {
  
  cat("\n2. TESTING THEORETICAL APPROACHES\n")
  cat("----------------------------------\n")
  
  # Sample data
  set.seed(2024)
  idx <- sample(1:N, n_sample, replace = FALSE)
  sample_data <- data[idx, ]
  X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
  Z <- sample_data$z
  Y <- sample_data$y
  weights <- rep(N/n_sample, n_sample)
  
  # Test different approaches
  approaches <- list()
  
  # 1. Standard Doubly Robust
  cat("\nApproach 1: Standard Doubly Robust\n")
  theta <- estimate_double_score_params_stable(X, Z, Y, weights)
  scores <- compute_double_scores_corrected(X, Z, Y, theta)
  
  dr_est <- sum(weights * (scores$mu1 + Z * (Y - scores$mu1) / scores$ps)) / sum(weights) -
            sum(weights * (scores$mu0 + (1-Z) * (Y - scores$mu0) / (1-scores$ps))) / sum(weights)
  
  approaches$standard_dr <- dr_est
  cat("- Estimate:", round(dr_est, 3), "\n")
  
  # 2. AIPW with stabilized weights
  cat("\nApproach 2: AIPW with Stabilized Weights\n")
  p_treat <- sum(weights * Z) / sum(weights)
  
  sw1 <- Z * p_treat / scores$ps
  sw0 <- (1-Z) * (1-p_treat) / (1-scores$ps)
  
  aipw_est <- sum(weights * sw1 * Y) / sum(weights * sw1) -
              sum(weights * sw0 * Y) / sum(weights * sw0) +
              sum(weights * (scores$mu1 - scores$mu0)) / sum(weights) -
              sum(weights * sw1 * scores$mu1) / sum(weights * sw1) +
              sum(weights * sw0 * scores$mu0) / sum(weights * sw0)
  
  approaches$aipw_stabilized <- aipw_est
  cat("- Estimate:", round(aipw_est, 3), "\n")
  
  # 3. Targeted Maximum Likelihood Estimation (TMLE) - adapted for continuous outcomes
  cat("\nApproach 3: TMLE-inspired adjustment\n")
  
  # Clever covariate
  H1 <- Z / scores$ps
  H0 <- (1-Z) / (1-scores$ps)
  
  # Initial predictions
  Q1_init <- scores$mu1
  Q0_init <- scores$mu0
  
  # Fluctuation parameter using linear regression (for continuous outcomes)
  eps1 <- coef(lm(Y ~ -1 + offset(Q1_init) + H1, weights = weights * Z))[1]
  eps0 <- coef(lm(Y ~ -1 + offset(Q0_init) + H0, weights = weights * (1-Z)))[1]
  
  # Updated predictions
  Q1_star <- Q1_init + eps1 * 1
  Q0_star <- Q0_init + eps0 * 1
  
  tmle_est <- sum(weights * Q1_star) / sum(weights) - sum(weights * Q0_star) / sum(weights)
  
  approaches$tmle <- tmle_est
  cat("- Estimate:", round(tmle_est, 3), "\n")
  
  # 4. Hajek-type estimator
  cat("\nApproach 4: Hajek-type Estimator\n")
  
  w1 <- weights * Z / scores$ps
  w0 <- weights * (1-Z) / (1-scores$ps)
  
  hajek_est <- sum(w1 * Y) / sum(w1) - sum(w0 * Y) / sum(w0)
  
  approaches$hajek <- hajek_est
  cat("- Estimate:", round(hajek_est, 3), "\n")
  
  return(approaches)
}

# Function to develop improved estimator
develop_improved_estimator <- function() {
  
  cat("\n3. DEVELOPING IMPROVED ESTIMATOR\n")
  cat("---------------------------------\n")
  
  # Based on bias analysis, we need to:
  # 1. Improve double score calculation
  # 2. Add bias correction terms
  # 3. Use better variance estimation
  
  improved_wdsm_pate <- function(X, Z, Y, weights, trim = c(0.01, 0.99)) {
    n <- length(Y)
    
    # Step 1: Robust parameter estimation with cross-validation
    theta <- estimate_double_score_params_stable(X, Z, Y, weights)
    
    # Step 2: Compute scores with trimming
    scores <- compute_double_scores_corrected(X, Z, Y, theta, trim)
    
    # Step 3: Bias-aware estimation
    # Use normalized IPW with outcome regression augmentation
    p_treat <- sum(weights * Z) / sum(weights)
    
    # Normalized weights
    w1 <- weights * Z / scores$ps
    w0 <- weights * (1-Z) / (1-scores$ps)
    w1_norm <- w1 / sum(w1)
    w0_norm <- w0 / sum(w0)
    
    # IPW component
    ipw_1 <- sum(w1_norm * Y)
    ipw_0 <- sum(w0_norm * Y)
    
    # Augmentation term for bias reduction
    aug_1 <- sum(weights * (1 - w1_norm * sum(w1)) * scores$mu1) / sum(weights)
    aug_0 <- sum(weights * (1 - w0_norm * sum(w0)) * scores$mu0) / sum(weights)
    
    # Combined estimator
    pate_est <- (ipw_1 + aug_1) - (ipw_0 + aug_0)
    
    # Influence function for variance
    # ψ(O_i) = (μ̂₁ - μ̂₀) + I(Z_i=1)/p̂(X_i) * (Y_i - μ̂₁(X_i)) - I(Z_i=0)/(1-p̂(X_i)) * (Y_i - μ̂₀(X_i))
    infl_fn <- (scores$mu1 - scores$mu0) + 
               Z * (Y - scores$mu1) / scores$ps - 
               (1-Z) * (Y - scores$mu0) / (1-scores$ps)
    
    # Centered influence function
    infl_centered <- infl_fn - sum(weights * infl_fn) / sum(weights)
    
    # Variance estimate
    var_est <- sum(weights * infl_centered^2) / sum(weights)^2
    se_est <- sqrt(var_est)
    
    return(list(
      estimate = pate_est,
      se = se_est,
      influence = infl_centered
    ))
  }
  
  return(improved_wdsm_pate)
}

# Main analysis
cat("Starting automated debugging and theoretical development...\n\n")

# Step 1: Analyze bias sources
bias_analysis <- analyze_bias_sources(n_sim = 30)

# Step 2: Test theoretical approaches
theoretical_results <- test_theoretical_approaches()

# Step 3: Develop improved estimator
improved_estimator <- develop_improved_estimator()

# Save functions for next iteration
save(bias_analysis, theoretical_results, improved_estimator, 
     file = "wdsm_theoretical_analysis.RData")

cat("\n=======================================================\n")
cat("INITIAL ANALYSIS COMPLETE\n")
cat("=======================================================\n")
cat("\nNext steps:\n")
cat("1. Implement improved bootstrap based on findings\n")
cat("2. Test coverage with new approach\n")
cat("3. Iterate until nominal coverage achieved\n") 