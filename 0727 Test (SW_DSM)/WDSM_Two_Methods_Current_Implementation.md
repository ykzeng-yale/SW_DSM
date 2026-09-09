# Current Implementation of Two WDSM Bootstrap CI Methods

## Common Components

### 1. Point Estimator with Bias Correction
```r
wdsm_point_estimate <- function(data, M = 1, use_bias_correction = TRUE) {
  n <- nrow(data)
  w <- data$survey_weight
  
  # Step 1: Estimate propensity score
  ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = data, family = binomial, weights = w)
  e_score <- predict(ps_model, type = "response")
  
  # Step 2: Estimate prognostic scores
  prog0_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                    data = data[data$A == 0,], weights = w[data$A == 0])
  psi0 <- predict(prog0_model, newdata = data)
  
  prog1_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                    data = data[data$A == 1,], weights = w[data$A == 1])
  psi1 <- predict(prog1_model, newdata = data)
  
  # Step 3: Construct double scores (standardized)
  S0 <- cbind(scale(e_score), scale(psi0))
  S1 <- cbind(scale(e_score), scale(psi1))
  
  # Step 4: Matching and imputation
  # ... matching logic ...
  
  # Step 5: Apply bias correction if requested
  if (use_bias_correction) {
    mu_hat_0 <- psi0
    mu_hat_1 <- psi1
    
    for (i in 1:n) {
      if (data$A[i] == 1 && !is.null(matches_0[[i]])) {
        # Bias correction for Y(0) imputation
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        weighted_neighbor_mu <- sum(neighbor_weights * mu_hat_0[neighbors]) / sum(neighbor_weights)
        B_hat_0[i] <- mu_hat_0[i] - weighted_neighbor_mu
        Y_hat_0[i] <- Y_hat_0[i] - B_hat_0[i]
      } else if (data$A[i] == 0 && !is.null(matches_1[[i]])) {
        # Similar for Y(1) imputation
        # ...
      }
    }
  }
  
  # Step 6: Calculate PATE estimate
  tau_wdsm <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
}
```

### 2. Weighted Reuse Counts (K_w)
```r
calculate_weighted_reuse_counts <- function(matches, weights, treatment_vec) {
  n <- length(matches)
  K_w <- rep(0, n)
  
  for (j in 1:n) {
    neighbors <- matches[[j]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      neighbor_weights <- weights[neighbors]
      total_weight <- sum(neighbor_weights)
      
      for (i in neighbors) {
        K_w[i] <- K_w[i] + weights[j] / total_weight
      }
    }
  }
  
  return(K_w)
}
```

## Method 1: Exponential Bootstrap

### Key Features:
- Uses Exponential(1) weights
- Pre-computes weighted matching frequencies (K₀ʷ and K₁ʷ)
- Re-estimates scores with bootstrap weights
- Linear representation with dimension 2 simplification

```r
method1_bootstrap_ci <- function(data, M = 1, B = 100, alpha = 0.05, verbose = TRUE, use_bias_correction = TRUE) {
  n <- nrow(data)
  
  # Get point estimate and pre-computed quantities
  point_results <- wdsm_point_estimate(data, M, use_bias_correction = use_bias_correction)
  tau_hat <- point_results$tau
  
  # Pre-compute weighted matching frequencies K_a^w
  K0_w <- calculate_weighted_reuse_counts(point_results$matches_0, 
                                         data$survey_weight, data$A)
  K1_w <- calculate_weighted_reuse_counts(point_results$matches_1, 
                                         data$survey_weight, data$A)
  
  # Bootstrap replicates
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Step B1: Generate bootstrap weights
    xi_star <- rexp(n, rate = 1)
    omega_star <- xi_star / mean(xi_star)
    w_boot <- omega_star * data$survey_weight
    
    # Step B2: Re-estimate scores with bootstrap weights
    ps_boot <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                   data = data, family = binomial, weights = w_boot)
    e_star <- predict(ps_boot, type = "response")
    
    prog0_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 0,], weights = w_boot[data$A == 0])
    psi0_star <- predict(prog0_boot, newdata = data)
    
    prog1_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 1,], weights = w_boot[data$A == 1])
    psi1_star <- predict(prog1_boot, newdata = data)
    
    # Step B4: Calculate bootstrap replicate using linear representation
    psi_star <- numeric(n)
    for (i in 1:n) {
      K_i_w <- ifelse(data$A[i] == 0, K0_w[i], K1_w[i])
      psi_a_star <- ifelse(data$A[i] == 0, psi0_star[i], psi1_star[i])
      
      psi_star[i] <- psi1_star[i] - psi0_star[i] + 
        (2*data$A[i] - 1) * (1 + K_i_w) * (data$Y[i] - psi_a_star)
    }
    
    tau_boot[b] <- sum(w_boot * psi_star) / sum(w_boot)
  }
  
  # Calculate variance and CI
  var_tau <- var(tau_boot)
  se_tau <- sqrt(var_tau)
  
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_tau
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_tau
}
```

## Method 2: Survey Bootstrap

### Key Features:
- Two-stage survey bootstrap approach
- Pre-computes fixed survey-weighted reuse counts
- Bootstrap weights from resampling with replacement
- Re-estimates nuisance parameters
- Uses linearized form with local regression

```r
method2_bootstrap_ci <- function(data, M = 1, B = 100, alpha = 0.05, verbose = TRUE, use_bias_correction = TRUE) {
  n <- nrow(data)
  
  # Get point estimate and pre-computed quantities
  point_results <- wdsm_point_estimate(data, M, use_bias_correction = use_bias_correction)
  tau_hat <- point_results$tau
  
  # Pre-compute weighted matching frequencies K_a^w
  K0_w <- calculate_weighted_reuse_counts(point_results$matches_0, 
                                         data$survey_weight, data$A)
  K1_w <- calculate_weighted_reuse_counts(point_results$matches_1, 
                                         data$survey_weight, data$A)
  
  # Bootstrap replicates
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Step 1: Generate bootstrap weights
    boot_indices <- sample(1:n, n, replace = TRUE)
    m_i <- tabulate(boot_indices, nbins = n)
    w_boot <- data$survey_weight * m_i
    
    selected <- m_i > 0
    
    # Step 2: Re-estimate nuisance parameters
    data_boot <- data[selected,]
    w_boot_selected <- w_boot[selected]
    
    ps_boot <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                   data = data_boot, family = binomial, weights = w_boot_selected)
    e_star <- predict(ps_boot, newdata = data, type = "response")
    
    if (sum(data_boot$A == 0) > 5) {
      prog0_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                       data = data_boot[data_boot$A == 0,],
                       weights = w_boot_selected[data_boot$A == 0])
      psi0_star <- predict(prog0_boot, newdata = data)
    } else {
      psi0_star <- point_results$psi0
    }
    
    if (sum(data_boot$A == 1) > 5) {
      prog1_boot <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                       data = data_boot[data_boot$A == 1,],
                       weights = w_boot_selected[data_boot$A == 1])
      psi1_star <- predict(prog1_boot, newdata = data)
    } else {
      psi1_star <- point_results$psi1
    }
    
    # Step 3: Calculate bootstrap replicate using linearized form
    mu_hat_0 <- psi0_star
    mu_hat_1 <- psi1_star
    
    delta_i <- numeric(n)
    for (i in 1:n) {
      if (data$A[i] == 0) {
        delta_i[i] <- 1 + K0_w[i]
      } else {
        delta_i[i] <- 1 + K1_w[i]
      }
    }
    
    # The linearized form incorporates the bias-corrected structure
    mu_1_boot_components <- mu_hat_1 + 
      data$A * delta_i * (data$Y - mu_hat_1)
    mu_0_boot_components <- mu_hat_0 + 
      (1 - data$A) * delta_i * (data$Y - mu_hat_0)
    
    if (sum(w_boot) > 0) {
      mu_1_boot <- sum(w_boot * mu_1_boot_components) / sum(w_boot)
      mu_0_boot <- sum(w_boot * mu_0_boot_components) / sum(w_boot)
      tau_boot[b] <- mu_1_boot - mu_0_boot
    } else {
      tau_boot[b] <- tau_hat
    }
  }
  
  # Calculate variance and CI
  var_tau <- var(tau_boot)
  se_tau <- sqrt(var_tau)
  
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_tau
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_tau
}
```

## Key Differences Between Methods

1. **Bootstrap Weight Generation**:
   - Method 1: `xi_star ~ Exponential(1)`, then `omega_star = xi_star / mean(xi_star)`
   - Method 2: Resample indices with replacement, then `m_i = count of selections`

2. **Combined Weights**:
   - Method 1: `w_boot = omega_star * survey_weight`
   - Method 2: `w_boot = survey_weight * m_i`

3. **Linearization**:
   - Method 1: Uses `psi_star[i] = psi1_star[i] - psi0_star[i] + (2*A[i] - 1) * (1 + K_i_w) * (Y[i] - psi_a_star)`
   - Method 2: Separates into `mu_1_boot_components` and `mu_0_boot_components`

4. **Data Selection**:
   - Method 1: Uses all data with exponential weights
   - Method 2: Only uses selected units (where `m_i > 0`) for re-estimation

Both methods:
- Pre-compute K_w values (weighted reuse counts) from the original sample
- Re-estimate nuisance parameters in each bootstrap iteration
- Use normal approximation for 95% CI construction
- Support bias correction in the point estimator 