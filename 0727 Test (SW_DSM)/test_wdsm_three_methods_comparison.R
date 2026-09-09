# Comparison of Three WDSM CI Methods (Version 3, 4, 5)
# 20 resampling iterations, 20 bootstrap samples per method
# Each method has its own complete WDSM implementation

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(nnet)

# Set seed for reproducibility
set.seed(20250127)

# Source required functions
source("SW_PSW-main/EstSOD_Function.R")
source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")

# Helper function to standardize covariates
standardize <- function(X) {
  X <- as.matrix(X)
  X.std <- scale(X)
  const.cols <- which(attr(X.std, "scaled:scale") == 0)
  if (length(const.cols) > 0) {
    X.std[, const.cols] <- X[, const.cols]
  }
  return(X.std)
}

# ==============================================================================
# VERSION 3: Bootstrap with Design Effect Adjustment
# ==============================================================================

wdsm_version3 <- function(Y, X, A, w, M = 3, B = 20, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 3: Bootstrap with Design Effect\n")
  
  # ---------- Point Estimation ----------
  # Step 1: Estimate propensity score
  ps_data <- data.frame(A = A, X = X)
  ps_model <- glm(A ~ ., data = ps_data, weights = w, family = binomial(link = "logit"))
  e_hat <- fitted(ps_model)
  
  # Step 2: Estimate prognostic scores
  data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
  data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
  
  pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
  pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
  
  newdata <- data.frame(X = X)
  mu_hat_0 <- predict(pg_model_0, newdata = newdata)
  mu_hat_1 <- predict(pg_model_1, newdata = newdata)
  
  # Step 3: Form double scores
  S_0 <- cbind(e_hat, mu_hat_0)
  S_1 <- cbind(e_hat, mu_hat_1)
  
  S_0 <- standardize(S_0)
  S_1 <- standardize(S_1)
  
  # Step 4: Matching
  dist_S0 <- as.matrix(dist(S_0))
  dist_S1 <- as.matrix(dist(S_1))
  
  # Find matches for each unit
  J_M <- list()
  for (i in 1:n) {
    if (A[i] == 1) {
      # Find M nearest controls
      control_indices <- which(A == 0)
      dists <- dist_S0[i, control_indices]
      J_M[[i]] <- control_indices[order(dists)[1:min(M, length(control_indices))]]
    } else {
      # Find M nearest treated
      treated_indices <- which(A == 1)
      dists <- dist_S1[i, treated_indices]
      J_M[[i]] <- treated_indices[order(dists)[1:min(M, length(treated_indices))]]
    }
  }
  
  # Step 5: Impute potential outcomes
  Y_hat_1 <- Y_hat_0 <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      Y_hat_1[i] <- Y[i]
      matches <- J_M[[i]]
      if (length(matches) > 0) {
        Y_hat_0[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_0[i] <- Y[i]
      }
    } else {
      Y_hat_0[i] <- Y[i]
      matches <- J_M[[i]]
      if (length(matches) > 0) {
        Y_hat_1[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_1[i] <- Y[i]
      }
    }
  }
  
  # Step 6: Calculate point estimate
  tau_hat <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  # ---------- Bootstrap Variance Estimation ----------
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    
    # Generate bootstrap weights
    w_normalized <- w / sum(w)
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = w_normalized)
    
    # Calculate bootstrap weights
    m_star <- tabulate(boot_idx, nbins = n)
    w_b <- w * m_star
    
    # Only proceed if we have enough units
    selected <- w_b > 0
    if (sum(selected) < 10 || sum(A[selected] == 1) < 2 || sum(A[selected] == 0) < 2) {
      tau_boot[b] <- NA
      next
    }
    
    # Re-estimate scores with bootstrap weights
    ps_data_b <- data.frame(A = A[selected], X = X[selected, , drop = FALSE])
    ps_model_b <- glm(A ~ ., data = ps_data_b, weights = w_b[selected], 
                       family = binomial(link = "logit"))
    e_hat_b <- fitted(ps_model_b)
    
    # Predict for all selected units
    newdata_b <- data.frame(X = X[selected, , drop = FALSE])
    e_hat_b_full <- predict(ps_model_b, newdata = newdata_b, type = "response")
    
    # Re-estimate prognostic scores
    data_0_b <- data.frame(Y = Y[selected & A == 0], 
                           X = X[selected & A == 0, , drop = FALSE])
    data_1_b <- data.frame(Y = Y[selected & A == 1], 
                           X = X[selected & A == 1, , drop = FALSE])
    
    pg_model_0_b <- lm(Y ~ ., data = data_0_b, weights = w_b[selected & A == 0])
    pg_model_1_b <- lm(Y ~ ., data = data_1_b, weights = w_b[selected & A == 1])
    
    mu_hat_0_b <- predict(pg_model_0_b, newdata = newdata_b)
    mu_hat_1_b <- predict(pg_model_1_b, newdata = newdata_b)
    
    # Form bootstrap double scores
    S_0_b <- cbind(e_hat_b_full, mu_hat_0_b)
    S_1_b <- cbind(e_hat_b_full, mu_hat_1_b)
    
    S_0_b <- standardize(S_0_b)
    S_1_b <- standardize(S_1_b)
    
    # Re-match with bootstrap scores
    dist_S0_b <- as.matrix(dist(S_0_b))
    dist_S1_b <- as.matrix(dist(S_1_b))
    
    # Find matches for bootstrap sample
    J_M_b <- list()
    idx_map <- which(selected)  # Map from bootstrap indices to original indices
    
    for (i_b in 1:length(idx_map)) {
      i <- idx_map[i_b]
      if (A[i] == 1) {
        control_indices_b <- which(A[selected] == 0)
        dists <- dist_S0_b[i_b, control_indices_b]
        J_M_b[[i_b]] <- control_indices_b[order(dists)[1:min(M, length(control_indices_b))]]
      } else {
        treated_indices_b <- which(A[selected] == 1)
        dists <- dist_S1_b[i_b, treated_indices_b]
        J_M_b[[i_b]] <- treated_indices_b[order(dists)[1:min(M, length(treated_indices_b))]]
      }
    }
    
    # Impute potential outcomes for bootstrap sample
    Y_b <- Y[selected]
    A_b <- A[selected]
    w_b_selected <- w_b[selected]
    
    Y_hat_1_b <- Y_hat_0_b <- numeric(length(Y_b))
    
    for (i_b in 1:length(Y_b)) {
      if (A_b[i_b] == 1) {
        Y_hat_1_b[i_b] <- Y_b[i_b]
        matches <- J_M_b[[i_b]]
        if (length(matches) > 0) {
          Y_hat_0_b[i_b] <- sum(w_b_selected[matches] * Y_b[matches]) / 
                            sum(w_b_selected[matches])
        } else {
          Y_hat_0_b[i_b] <- Y_b[i_b]
        }
      } else {
        Y_hat_0_b[i_b] <- Y_b[i_b]
        matches <- J_M_b[[i_b]]
        if (length(matches) > 0) {
          Y_hat_1_b[i_b] <- sum(w_b_selected[matches] * Y_b[matches]) / 
                            sum(w_b_selected[matches])
        } else {
          Y_hat_1_b[i_b] <- Y_b[i_b]
        }
      }
    }
    
    # Calculate bootstrap estimate
    tau_boot[b] <- sum(w_b_selected * (Y_hat_1_b - Y_hat_0_b)) / sum(w_b_selected)
  }
  cat("\n")
  
  # Calculate variance with design effect adjustment
  V_boot <- var(tau_boot[is.finite(tau_boot)])
  n_eff <- sum(w)^2 / sum(w^2)
  design_effect <- n / n_eff
  V_adj <- V_boot * design_effect
  
  se <- sqrt(V_adj)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  
  cat("  Design effect:", round(design_effect, 3), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    method = "Version 3: Design Effect"
  ))
}

# ==============================================================================
# VERSION 4: Linearized Bootstrap with Multinomial Weights
# ==============================================================================

wdsm_version4 <- function(Y, X, A, w, M = 3, B = 20, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 4: Linearized Bootstrap\n")
  
  # ---------- Point Estimation ----------
  # Step 1: Estimate propensity score
  ps_data <- data.frame(A = A, X = X)
  ps_model <- glm(A ~ ., data = ps_data, weights = w, family = binomial(link = "logit"))
  e_hat <- fitted(ps_model)
  
  # Step 2: Estimate prognostic scores
  data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
  data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
  
  pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
  pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
  
  newdata <- data.frame(X = X)
  mu_hat_0 <- predict(pg_model_0, newdata = newdata)
  mu_hat_1 <- predict(pg_model_1, newdata = newdata)
  
  # Step 3: Form double scores
  S_0 <- cbind(e_hat, mu_hat_0)
  S_1 <- cbind(e_hat, mu_hat_1)
  
  S_0 <- standardize(S_0)
  S_1 <- standardize(S_1)
  
  # Step 4: Matching
  dist_S0 <- as.matrix(dist(S_0))
  dist_S1 <- as.matrix(dist(S_1))
  
  # Find matches and calculate matching frequencies
  J_M <- list()
  K_S0 <- K_S1 <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      # Find M nearest controls
      control_indices <- which(A == 0)
      dists <- dist_S0[i, control_indices]
      J_M[[i]] <- control_indices[order(dists)[1:min(M, length(control_indices))]]
    } else {
      # Find M nearest treated
      treated_indices <- which(A == 1)
      dists <- dist_S1[i, treated_indices]
      J_M[[i]] <- treated_indices[order(dists)[1:min(M, length(treated_indices))]]
    }
  }
  
  # Calculate matching frequencies K
  for (i in 1:n) {
    if (A[i] == 0) {
      # How often is unit i used as a match by treated units?
      for (j in which(A == 1)) {
        if (i %in% J_M[[j]]) {
          match_weights <- w[J_M[[j]]]
          K_S0[i] <- K_S0[i] + w[j] / sum(match_weights)
        }
      }
    } else {
      # How often is unit i used as a match by control units?
      for (j in which(A == 0)) {
        if (i %in% J_M[[j]]) {
          match_weights <- w[J_M[[j]]]
          K_S1[i] <- K_S1[i] + w[j] / sum(match_weights)
        }
      }
    }
  }
  
  # Step 5: Calculate point estimate using the explicit formula
  tau_hat <- sum(w * A * (1 + K_S1) * Y) / sum(w) - 
             sum(w * (1 - A) * (1 + K_S0) * Y) / sum(w)
  
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  # ---------- Bootstrap Variance Estimation ----------
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    
    # Generate multinomial weights
    p <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p))
    omega_star <- m_star / n
    w_b <- omega_star * w
    
    # Re-estimate scores with bootstrap weights
    ps_data <- data.frame(A = A, X = X)
    ps_model_b <- glm(A ~ ., data = ps_data, weights = w_b, family = binomial(link = "logit"))
    e_hat_b <- fitted(ps_model_b)
    
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0_b <- lm(Y ~ ., data = data_0, weights = w_b[A == 0])
    pg_model_1_b <- lm(Y ~ ., data = data_1, weights = w_b[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0_b <- predict(pg_model_0_b, newdata = newdata)
    mu_hat_1_b <- predict(pg_model_1_b, newdata = newdata)
    
    # Calculate bootstrap replicate using linearized form
    # First term: outcome regression
    term1 <- sum(w_b * (mu_hat_1_b - mu_hat_0_b)) / sum(w_b)
    
    # Second term: augmentation using original matching structure
    term2 <- 0
    for (i in 1:n) {
      if (A[i] == 1) {
        # Contribution from treated units
        residual <- Y[i] - mu_hat_1_b[i]
        
        # Add imputation contribution for Y(0)
        matches <- J_M[[i]]
        if (length(matches) > 0) {
          match_residuals <- Y[matches] - mu_hat_0_b[matches]
          impute_contrib <- sum(w[matches] * match_residuals) / sum(w[matches])
          residual <- residual + impute_contrib
        }
        
        term2 <- term2 + w_b[i] * residual / sum(w_b)
        
      } else {
        # Contribution from control units
        residual <- -(Y[i] - mu_hat_0_b[i])
        
        # Add imputation contribution for Y(1)
        matches <- J_M[[i]]
        if (length(matches) > 0) {
          match_residuals <- Y[matches] - mu_hat_1_b[matches]
          impute_contrib <- sum(w[matches] * match_residuals) / sum(w[matches])
          residual <- residual - impute_contrib
        }
        
        term2 <- term2 + w_b[i] * residual / sum(w_b)
      }
    }
    
    tau_boot[b] <- term1 + term2
  }
  cat("\n")
  
  # Calculate variance and CI
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    method = "Version 4: Linearized"
  ))
}

# ==============================================================================
# VERSION 5: Two-Stage Replication with Fixed Reuse Counts
# ==============================================================================

wdsm_version5 <- function(Y, X, A, w, M = 3, B = 20, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 5: Two-Stage with Fixed Reuse\n")
  
  # ---------- Point Estimation ----------
  # Step 1: Estimate propensity score
  ps_data <- data.frame(A = A, X = X)
  ps_model <- glm(A ~ ., data = ps_data, weights = w, family = binomial(link = "logit"))
  e_hat <- fitted(ps_model)
  
  # Step 2: Estimate prognostic scores
  data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
  data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
  
  pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
  pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
  
  newdata <- data.frame(X = X)
  mu_hat_0 <- predict(pg_model_0, newdata = newdata)
  mu_hat_1 <- predict(pg_model_1, newdata = newdata)
  
  # Step 3: Form double scores
  S_0 <- cbind(e_hat, mu_hat_0)
  S_1 <- cbind(e_hat, mu_hat_1)
  
  S_0 <- standardize(S_0)
  S_1 <- standardize(S_1)
  
  # Step 4: Matching
  dist_S0 <- as.matrix(dist(S_0))
  dist_S1 <- as.matrix(dist(S_1))
  
  # Find matches
  J_M <- list()
  for (i in 1:n) {
    if (A[i] == 1) {
      control_indices <- which(A == 0)
      dists <- dist_S0[i, control_indices]
      J_M[[i]] <- control_indices[order(dists)[1:min(M, length(control_indices))]]
    } else {
      treated_indices <- which(A == 1)
      dists <- dist_S1[i, treated_indices]
      J_M[[i]] <- treated_indices[order(dists)[1:min(M, length(treated_indices))]]
    }
  }
  
  # Step 5: Calculate weighted reuse counts (FIXED throughout bootstrap)
  K_S0 <- K_S1 <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 0) {
      # How often is control unit i used as a match by treated units?
      for (j in which(A == 1)) {
        if (i %in% J_M[[j]]) {
          match_weights <- w[J_M[[j]]]
          K_S0[i] <- K_S0[i] + w[j] / sum(match_weights)
        }
      }
    } else {
      # How often is treated unit i used as a match by control units?
      for (j in which(A == 0)) {
        if (i %in% J_M[[j]]) {
          match_weights <- w[J_M[[j]]]
          K_S1[i] <- K_S1[i] + w[j] / sum(match_weights)
        }
      }
    }
  }
  
  # Step 6: Impute potential outcomes
  Y_hat_1 <- Y_hat_0 <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      Y_hat_1[i] <- Y[i]
      matches <- J_M[[i]]
      if (length(matches) > 0) {
        Y_hat_0[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_0[i] <- Y[i]
      }
    } else {
      Y_hat_0[i] <- Y[i]
      matches <- J_M[[i]]
      if (length(matches) > 0) {
        Y_hat_1[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_1[i] <- Y[i]
      }
    }
  }
  
  # Step 7: Calculate point estimate
  tau_hat <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  # ---------- Bootstrap Variance Estimation ----------
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    
    # Generate bootstrap weights
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = w / sum(w))
    m_star <- tabulate(boot_idx, nbins = n)
    w_star <- w * m_star
    
    # Re-estimate scores only (not matching)
    ps_data <- data.frame(A = A, X = X)
    ps_model_star <- glm(A ~ ., data = ps_data, weights = w_star, 
                         family = binomial(link = "logit"))
    e_hat_star <- fitted(ps_model_star)
    
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0_star <- lm(Y ~ ., data = data_0, weights = w_star[A == 0])
    pg_model_1_star <- lm(Y ~ ., data = data_1, weights = w_star[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0_star <- predict(pg_model_0_star, newdata = newdata)
    mu_hat_1_star <- predict(pg_model_1_star, newdata = newdata)
    
    # Calculate bootstrap replicate using linearized form with FIXED reuse counts
    term1 <- sum(w_star * (mu_hat_1_star - mu_hat_0_star)) / sum(w_star)
    
    term2 <- 0
    for (i in 1:n) {
      if (A[i] == 1) {
        # Treated units contribute with (1 + K_S1)
        term2 <- term2 + w_star[i] * (1 + K_S1[i]) * (Y[i] - mu_hat_1_star[i]) / sum(w_star)
      } else {
        # Control units contribute with -(1 + K_S0)
        term2 <- term2 - w_star[i] * (1 + K_S0[i]) * (Y[i] - mu_hat_0_star[i]) / sum(w_star)
      }
    }
    
    tau_boot[b] <- term1 + term2
  }
  cat("\n")
  
  # Calculate variance and CI
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    method = "Version 5: Fixed Reuse"
  ))
}

# ==============================================================================
# MAIN SIMULATION
# ==============================================================================

cat("=== COMPARISON OF THREE WDSM CI METHODS ===\n")
cat("20 Resamplings, 20 Bootstrap Iterations\n")
cat("Methods: Version 3 (Design Effect), Version 4 (Linearized), Version 5 (Fixed Reuse)\n\n")

# Generate the super population data
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Extract population parameters
data_pop <- data_sets[[1]]
true_pate <- mean(data_pop$y1) - mean(data_pop$y0)
cat("True PATE:", round(true_pate, 4), "\n")

# Define sampling parameters
size1 <- rep(100000, 10)
size2 <- rep(5, 10)
size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
           rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
           rep(250/5, 5), rep(150/5, 5))

# Initialize results storage
results <- data.frame()

# Run simulations
n_sims <- 20
B_boot <- 20

for (sim in 1:n_sims) {
  cat("\n", paste(rep("=", 60), collapse=""), "\n")
  cat("SIMULATION", sim, "of", n_sims, "\n")
  cat(paste(rep("=", 60), collapse=""), "\n")
  
  # Create a sample
  data_pop$ones <- 1
  data_pop$id <- 1:nrow(data_pop)
  
  s <- mstage(data_pop, stage = list("stratified", "cluster", ""), 
              varnames = list("Strata", "Cluster", "ones"), 
              size = list(size1, size2, size3), 
              method = list("", "srswor", "srswor"))
  
  sample <- getdata(data_pop, s)[[3]]
  sample$s.wt <- 1 / sample$Prob
  
  # Extract variables
  Y <- sample$y
  X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
  A <- sample$z
  w <- sample$s.wt
  
  cat("\nSample size:", length(Y), "(Treated:", sum(A), "Control:", sum(1-A), ")\n")
  cat("Effective sample size:", round(sum(w)^2 / sum(w^2), 1), "\n")
  
  # Run all 3 methods
  tryCatch({
    # Version 3: Design Effect
    res3 <- wdsm_version3(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 4: Linearized
    res4 <- wdsm_version4(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 5: Fixed Reuse
    res5 <- wdsm_version5(Y, X, A, w, M = 3, B = B_boot)
    
    # Store results
    sim_results <- data.frame(
      Simulation = sim,
      Method = c("V3", "V4", "V5"),
      Estimate = c(res3$tau_hat, res4$tau_hat, res5$tau_hat),
      Bias = c(res3$tau_hat, res4$tau_hat, res5$tau_hat) - true_pate,
      SE = c(res3$se, res4$se, res5$se),
      CI_Lower = c(res3$ci_normal[1], res4$ci_normal[1], res5$ci_normal[1]),
      CI_Upper = c(res3$ci_normal[2], res4$ci_normal[2], res5$ci_normal[2]),
      Covered = c(
        true_pate >= res3$ci_normal[1] & true_pate <= res3$ci_normal[2],
        true_pate >= res4$ci_normal[1] & true_pate <= res4$ci_normal[2],
        true_pate >= res5$ci_normal[1] & true_pate <= res5$ci_normal[2]
      )
    )
    
    results <- rbind(results, sim_results)
    
  }, error = function(e) {
    cat("\nError in simulation", sim, ":", e$message, "\n")
  })
}

# Calculate summary statistics
cat("\n\n", paste(rep("=", 60), collapse=""), "\n")
cat("SUMMARY RESULTS\n")
cat(paste(rep("=", 60), collapse=""), "\n\n")

summary_by_method <- aggregate(
  cbind(Estimate, Bias, SE, Covered) ~ Method, 
  data = results,
  FUN = function(x) c(mean = mean(x), sd = sd(x))
)

# Calculate additional metrics
ci_widths <- aggregate(
  cbind(CI_Upper - CI_Lower) ~ Method,
  data = results,
  FUN = function(x) c(mean = mean(x), sd = sd(x))
)
names(ci_widths)[2] <- "CI_Width"

# Format output
method_names <- c("V3: Design Effect", 
                  "V4: Linearized", 
                  "V5: Fixed Reuse")

cat("True PATE:", round(true_pate, 4), "\n\n")

for (i in 1:3) {
  method <- paste0("V", i+2)
  method_data <- summary_by_method[summary_by_method$Method == method, ]
  width_data <- ci_widths[ci_widths$Method == method, ]
  
  cat(method_names[i], "\n")
  cat("  Mean Estimate:", round(method_data$Estimate[, "mean"], 4), 
      "(SD:", round(method_data$Estimate[, "sd"], 4), ")\n")
  cat("  Mean Bias:", round(method_data$Bias[, "mean"], 4), 
      "(Relative:", round(method_data$Bias[, "mean"] / true_pate * 100, 2), "%)\n")
  cat("  Mean SE:", round(method_data$SE[, "mean"], 4), 
      "(SD:", round(method_data$SE[, "sd"], 4), ")\n")
  cat("  Coverage:", round(method_data$Covered[, "mean"] * 100, 0), "%\n")
  cat("  Mean CI Width:", round(width_data$CI_Width[, "mean"], 4), "\n\n")
}

# Save results
save(results, true_pate, summary_by_method, file = "wdsm_three_methods_results.RData")
cat("Results saved to wdsm_three_methods_results.RData\n")

# Create comparison plot
pdf("wdsm_three_methods_comparison.pdf", width = 10, height = 8)

# Plot 1: Estimates by simulation
plot(1:n_sims, results$Estimate[results$Method == "V3"], 
     type = "b", col = "blue", pch = 16,
     ylim = range(results$Estimate, true_pate),
     xlab = "Simulation", ylab = "PATE Estimate",
     main = "WDSM Estimates Across Simulations")
lines(1:n_sims, results$Estimate[results$Method == "V4"], 
      type = "b", col = "red", pch = 17)
lines(1:n_sims, results$Estimate[results$Method == "V5"], 
      type = "b", col = "green", pch = 18)
abline(h = true_pate, lty = 2, col = "black", lwd = 2)
legend("topright", 
       c("V3: Design Effect", "V4: Linearized", "V5: Fixed Reuse", "True PATE"),
       col = c("blue", "red", "green", "black"),
       pch = c(16, 17, 18, NA),
       lty = c(1, 1, 1, 2))

# Plot 2: CI Width comparison
boxplot(CI_Upper - CI_Lower ~ Method, data = results,
        names = c("V3: Design", "V4: Linear", "V5: Fixed"),
        ylab = "CI Width",
        main = "95% CI Width Comparison",
        col = c("lightblue", "lightcoral", "lightgreen"))

dev.off()

cat("\nPlots saved to wdsm_three_methods_comparison.pdf\n") 