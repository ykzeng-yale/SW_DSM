##############################################################################
# WDSM PATT: Point Estimation and Bootstrap for Retrospective PATT
# Based on paper Section 4 (PATT Extension)
# Key differences from PATE:
#   - One-sided matching: only treated→control on D_0 = (e, Psi_0)
#   - Hájek normalization only over treated units
#   - Only control-side bias correction needed
#   - Bootstrap Eq. 29 uses treated-side normalization
##############################################################################

library(MASS)

expit <- function(x) { exp(x) / (1 + exp(x)) }

standardize_with_weights <- function(S, weights) {
  w_sum <- sum(weights)
  S_mean <- colSums(weights * S) / w_sum
  S_centered <- sweep(S, 2, S_mean, "-")
  S_var <- colSums(weights * S_centered^2) / w_sum
  S_sd <- sqrt(S_var)
  S_sd[S_sd < 1e-10] <- 1
  sweep(S_centered, 2, S_sd, "/")
}

find_weighted_neighbors <- function(distances, candidate_indices, M) {
  sorted_indices <- order(distances)
  if (length(sorted_indices) >= M) {
    return(candidate_indices[sorted_indices[1:M]])
  } else {
    return(candidate_indices[sorted_indices])
  }
}

# PATT point estimation
wdsm_patt_point_estimate <- function(data, M = 5, use_bias_correction = TRUE,
                                      use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  n <- nrow(data)
  w <- data$survey_weight
  
  if (use_interaction_ps) {
    ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  if (use_interaction_pg) {
    pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  # Step 1: PS estimation (SURVEY-WEIGHTED for retrospective)
  ps_model <- glm(ps_formula, data = data, family = quasibinomial(link = "logit"), weights = w)
  e_score <- ps_model$fitted.values
  
  # Step 2: Prognostic scores (UNWEIGHTED per paper Eq. 4)
  # PATT only needs Psi_0 (control-side), but we estimate both for sieve
  prog0_model <- lm(pg_formula, data = data[data$A == 0,])
  psi0 <- predict(prog0_model, newdata = data)
  prog1_model <- lm(pg_formula, data = data[data$A == 1,])
  psi1 <- predict(prog1_model, newdata = data)
  
  # Step 2.5: Polynomial sieve bias correction
  # PATT: 5-term basis on D_0 = (logit(e), Psi_0) space
  # Use logit(e_score) to match the score coordinate used in matching
  e_score_bounded <- pmax(pmin(e_score, 0.999), 0.001)
  ps_logit <- qlogis(e_score_bounded)
  sieve_x <- cbind(psi0, psi0^2, ps_logit, ps_logit^2, ps_logit * psi0)
  colnames(sieve_x) <- c("m0","m0sq","ps","pssq","psm0")
  
  bc0_fit <- lm(Y ~ ., data = data.frame(Y = data$Y[data$A == 0], sieve_x[data$A == 0,]),
                weights = w[data$A == 0])
  mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_x))
  
  # Step 3: Matching - ONLY treated→control on D_0 = (logit(e), Psi_0)
  e_score_bounded <- pmax(pmin(e_score, 0.999), 0.001)
  e_score_logit <- qlogis(e_score_bounded)
  D0_all <- cbind(e_score_logit, psi0)
  D0_std <- standardize_with_weights(D0_all, w)
  
  matches_0 <- vector("list", n)
  control_indices <- which(data$A == 0)
  
  for (i in which(data$A == 1)) {
    if (length(control_indices) >= M) {
      distances <- apply(D0_std[control_indices, , drop = FALSE], 1,
                        function(x) sqrt(sum((D0_std[i,] - x)^2)))
      matches_0[[i]] <- find_weighted_neighbors(distances, control_indices, M)
    }
  }
  
  # Step 4: Impute Y(0) for treated only (Eq. 24)
  Y_hat_0 <- rep(NA, n)
  for (i in which(data$A == 1)) {
    if (!is.null(matches_0[[i]])) {
      neighbors <- matches_0[[i]]
      nw <- w[neighbors]
      Y_hat_0[i] <- sum(nw * data$Y[neighbors]) / sum(nw)
    }
  }
  
  # Step 5: Bias correction (only control-side, Eq. 12 adapted for PATT)
  if (use_bias_correction) {
    for (i in which(data$A == 1)) {
      if (!is.null(matches_0[[i]])) {
        neighbors <- matches_0[[i]]
        nw <- w[neighbors]
        Y_hat_0[i] <- sum(nw * data$Y[neighbors]) / sum(nw) +
                      mu0_bc[i] - sum(nw * mu0_bc[neighbors]) / sum(nw)
      }
    }
  }
  
  # Step 6: PATT estimate with Hájek normalization over TREATED only (Eq. 26)
  treated_idx <- which(data$A == 1)
  tau_patt <- sum(w[treated_idx] * (data$Y[treated_idx] - Y_hat_0[treated_idx])) / sum(w[treated_idx])
  
  # Compute reuse counts K_0^{R,PATT}(j) for controls (Eq. 25)
  K0_patt <- rep(0, n)
  for (i in which(data$A == 1)) {
    neighbors <- matches_0[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      nw <- w[neighbors]
      total_nw <- sum(nw)
      for (j in neighbors) {
        K0_patt[j] <- K0_patt[j] + w[i] * w[j] / total_nw
      }
    }
  }
  
  return(list(
    tau = tau_patt,
    Y_hat_0 = Y_hat_0,
    e_score = e_score,
    psi0 = psi0, psi1 = psi1,
    mu0_bc = mu0_bc,
    matches_0 = matches_0,
    K0_patt = K0_patt
  ))
}

# PATT Bootstrap (paper Eq. 29)
wdsm_patt_bootstrap_ci <- function(Y, A, X, weights, point_est,
                                    M = 5, n_bootstrap = 200, alpha = 0.05,
                                    use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  n <- length(Y)
  K0_patt <- point_est$K0_patt
  
  if (use_interaction_ps) {
    ps_boot_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    ps_boot_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  if (use_interaction_pg) {
    pg_boot_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    pg_boot_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  boot_estimates <- numeric(n_bootstrap)
  
  for (b in 1:n_bootstrap) {
    # Step 1: multinomial weights
    m_star <- rmultinom(1, n, rep(1/n, n))[,1]
    w_star_b <- m_star * weights  # w_i^{*,b}
    
    # Step 2: Score replication
    df_ps <- data.frame(A = A, X1 = X[,1], X2 = X[,2], X3 = X[,3],
                        X4 = X[,4], X5 = X[,5], X6 = X[,6])
    
    # PS: survey-weighted bootstrap (retro)
    ps_star <- tryCatch({
      fit <- glm(ps_boot_formula, data = df_ps, family = quasibinomial(link = "logit"),
                 weights = w_star_b)
      predict(fit, type = "response")
    }, error = function(e) point_est$e_score)
    
    # PG: only m_star (unweighted, paper Step 2)
    df_all <- data.frame(X1 = X[,1], X2 = X[,2], X3 = X[,3],
                         X4 = X[,4], X5 = X[,5], X6 = X[,6])
    idx0 <- which(A == 0); idx1 <- which(A == 1)
    
    df_0 <- data.frame(Y = Y[idx0], df_all[idx0,])
    psi0_star <- tryCatch({
      fit <- lm(pg_boot_formula, data = df_0, weights = m_star[idx0])
      predict(fit, newdata = df_all)
    }, error = function(e) point_est$psi0)
    
    df_1 <- data.frame(Y = Y[idx1], df_all[idx1,])
    psi1_star <- tryCatch({
      fit <- lm(pg_boot_formula, data = df_1, weights = m_star[idx1])
      predict(fit, newdata = df_all)
    }, error = function(e) point_est$psi1)
    
    # Sieve BC: 5-term on D_0 space with logit(ps) matching score coordinate
    ps_star_bounded <- pmax(pmin(ps_star, 0.999), 0.001)
    ps_logit_star <- qlogis(ps_star_bounded)
    sieve_x_star <- cbind(psi0_star, psi0_star^2, ps_logit_star, ps_logit_star^2, ps_logit_star*psi0_star)
    colnames(sieve_x_star) <- c("m0","m0sq","ps","pssq","psm0")
    
    mu0_bc_star <- tryCatch({
      fit <- lm(Y ~ ., data = data.frame(Y = Y[idx0], sieve_x_star[idx0,]),
                weights = w_star_b[idx0])
      predict(fit, newdata = data.frame(sieve_x_star))
    }, error = function(e) point_est$mu0_bc)
    
    # Step 3: PATT bootstrap estimate (Eq. 29)
    # Numerator part 1: sum over treated
    treated_sum <- sum(w_star_b[idx1] * (Y[idx1] - mu0_bc_star[idx1]))
    
    # Numerator part 2: sum over control donors
    control_sum <- sum(m_star[idx0] * K0_patt[idx0] * (Y[idx0] - mu0_bc_star[idx0]))
    
    # Normalization: only treated weights
    norm_treated <- sum(w_star_b[idx1])
    
    boot_estimates[b] <- (treated_sum - control_sum) / norm_treated
  }
  
  boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  se <- sd(boot_estimates)
  
  list(
    estimate = point_est$tau,
    se = se,
    ci_lower = point_est$tau - qnorm(1 - alpha/2) * se,
    ci_upper = point_est$tau + qnorm(1 - alpha/2) * se
  )
}

# Wrapper function
compute_wdsm_patt_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200,
                                  alpha = 0.05, use_bias_correction = TRUE,
                                  return_samples = FALSE,
                                  use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  X <- as.matrix(X)
  data <- data.frame(Y = Y, A = A, X1 = X[,1], X2 = X[,2], X3 = X[,3],
                     X4 = X[,4], X5 = X[,5], X6 = X[,6], survey_weight = weights)
  
  point_est <- wdsm_patt_point_estimate(data, M = M, use_bias_correction = TRUE,
                                         use_interaction_ps = use_interaction_ps,
                                         use_interaction_pg = use_interaction_pg)
  
  ci_result <- wdsm_patt_bootstrap_ci(Y, A, X, weights, point_est,
                                       M = M, n_bootstrap = n_bootstrap, alpha = alpha,
                                       use_interaction_ps = use_interaction_ps,
                                       use_interaction_pg = use_interaction_pg)
  return(ci_result)
}

cat("WDSM PATT Retrospective: Module loaded.\n")
cat("Functions: wdsm_patt_point_estimate(), wdsm_patt_bootstrap_ci(), compute_wdsm_patt_ci()\n")
